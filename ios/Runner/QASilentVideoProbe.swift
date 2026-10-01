import AVFoundation
import Flutter
import Foundation

/// QA metadata only. It neither constructs a player nor touches AVAudioSession.
enum QASilentVideoAssetInspector {
  static func inspect(_ url: URL) async -> Bool {
    guard url.isFileURL else { return false }
    let asset = AVURLAsset(
      url: url,
      options: [
        AVURLAssetReferenceRestrictionsKey: AVAssetReferenceRestrictions.forbidAll.rawValue
      ]
    )
    do {
      let audioTracks = try await asset.loadTracks(withMediaType: .audio)
      guard !Task.isCancelled, audioTracks.isEmpty else { return false }
      let videoTracks = try await asset.loadTracks(withMediaType: .video)
      guard !Task.isCancelled, !videoTracks.isEmpty,
            try await asset.load(.isPlayable) else { return false }
      for track in videoTracks {
        guard !Task.isCancelled, try await track.load(.isDecodable) else { return false }
      }
      return !Task.isCancelled
    } catch {
      return false
    }
  }
}

/// The caller gets one reply within the deadline, even if AVFoundation returns late.
/// Engine replacement invalidates outstanding replies. The production video
/// factory remains closed on iOS regardless of this QA probe's result.
final class QASilentVideoProbeHandler {
  typealias AssetResolver = (String) -> URL?
  typealias Inspector = (URL, @escaping (Bool) -> Void) -> (() -> Void)

  static let channelName = "com.yulalab.ostinato/qa_silent_video_probe"
  static let methodName = "inspectBundledMp4"
  private static let assetPrefix = "assets/content/media/ostinato/"

  private final class Request {
    let result: FlutterResult
    var cancel: (() -> Void)?
    init(result: @escaping FlutterResult) { self.result = result }
  }

  private let resolver: AssetResolver
  private let inspector: Inspector
  private let deadline: TimeInterval
  private var requests: [UUID: Request] = [:]
  private var invalidated = false

  init(
    resolver: @escaping AssetResolver = QASilentVideoProbeHandler.resolveBundledAsset,
    inspector: @escaping Inspector = QASilentVideoProbeHandler.startInspection,
    deadline: TimeInterval = 2
  ) {
    self.resolver = resolver
    self.inspector = inspector
    self.deadline = deadline
  }

  static func isAllowedAssetName(_ name: String) -> Bool {
    guard name.utf8.count <= 240, name.hasPrefix(assetPrefix), name.hasSuffix(".mp4") else {
      return false
    }
    let relative = String(name.dropFirst(assetPrefix.count))
    let components = relative.split(separator: "/", omittingEmptySubsequences: false)
    guard let last = components.last, last.count > 4 else { return false }
    return components.allSatisfy { component in
      !component.isEmpty && component != "." && component != ".." &&
        !component.hasPrefix(".") && !component.hasSuffix(".") &&
        component.utf8.allSatisfy { byte in
          (48...57).contains(byte) || (65...90).contains(byte) ||
            (97...122).contains(byte) || byte == 45 || byte == 95 || byte == 46
        }
    }
  }

  private static func resolveBundledAsset(_ name: String) -> URL? {
    guard isAllowedAssetName(name) else { return nil }
    // video_player_avfoundation uses the same Flutter key and Bundle.main lookup.
    let key = FlutterDartProject.lookupKey(forAsset: name)
    guard key.hasSuffix("/" + name),
          !key.split(separator: "/").contains(".."),
          let path = Bundle.main.path(forResource: key, ofType: nil) else { return nil }
    let file = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL
    let bundle = Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL
    guard file.path.hasPrefix(bundle.path + "/"),
          FileManager.default.isReadableFile(atPath: file.path) else { return nil }
    return file
  }

  private static func startInspection(
    _ url: URL, completion: @escaping (Bool) -> Void
  ) -> (() -> Void) {
    let task = Task {
      let approved = await QASilentVideoAssetInspector.inspect(url)
      DispatchQueue.main.async { completion(approved) }
    }
    return { task.cancel() }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    assert(Thread.isMainThread)
    guard call.method == Self.methodName else { result(FlutterMethodNotImplemented); return }
    guard !invalidated,
          let args = call.arguments as? [String: Any], args.count == 1,
          let name = args["asset"] as? String, Self.isAllowedAssetName(name),
          let url = resolver(name) else { result(false); return }
    let id = UUID()
    let request = Request(result: result)
    requests[id] = request
    request.cancel = inspector(url) { [weak self] approved in
      DispatchQueue.main.async { self?.finish(id, approved: approved) }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + deadline) { [weak self] in
      guard let self = self, let pending = self.requests[id] else { return }
      pending.cancel?()
      self.finish(id, approved: false)
    }
  }

  func invalidate() {
    assert(Thread.isMainThread)
    invalidated = true
    let pending = requests
    requests.removeAll()
    for request in pending.values {
      request.cancel?()
      request.result(false)
    }
  }

  private func finish(_ id: UUID, approved: Bool) {
    assert(Thread.isMainThread)
    guard let request = requests.removeValue(forKey: id) else { return }
    request.result(approved)
  }
}
