import Flutter
import XCTest
@testable import Runner

final class QASilentVideoProbeTests: XCTestCase {
  private let assetName = "assets/content/media/ostinato/lesson-01.mp4"

  private func fixture(_ name: String) throws -> URL {
    try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: name,
                                                   withExtension: "mp4",
                                                   subdirectory: "Fixtures"))
  }

  func testOnlyStrictBundledMp4NamesAreAccepted() {
    XCTAssertTrue(QASilentVideoProbeHandler.isAllowedAssetName(assetName))
    XCTAssertTrue(QASilentVideoProbeHandler.isAllowedAssetName(
      "assets/content/media/ostinato/course-a/lesson.v1.mp4"))
    for invalid in [
      "file:///tmp/lesson.mp4", "https://example.com/lesson.mp4",
      "assets/content/media/ostinato/../lesson.mp4",
      "assets/content/media/ostinato/course//lesson.mp4",
      "assets/content/media/ostinato/%2e%2e/lesson.mp4",
      "assets/content/media/ostinato/lesson.mov",
      "assets/content/media/other/lesson.mp4", "assets/content/media/ostinato/.mp4",
    ] {
      XCTAssertFalse(QASilentVideoProbeHandler.isAllowedAssetName(invalid), invalid)
    }
  }

  func testFlutterAssetKeyUsesSameBundleLookupAsVideoPlayer() {
    let existingAsset = "assets/content/guitar_journey.v1.json"
    let key = FlutterDartProject.lookupKey(forAsset: existingAsset)
    XCTAssertTrue(key.hasSuffix("/" + existingAsset))
    XCTAssertNotNil(Bundle.main.path(forResource: key, ofType: nil))
  }

  func testVideoOnlyMp4PassesTrackAndDecoderProbe() async throws {
    let approved = await QASilentVideoAssetInspector.inspect(try fixture("silent-video"))
    XCTAssertTrue(approved)
  }

  func testMp4WithAudioFails() async throws {
    let approved = await QASilentVideoAssetInspector.inspect(try fixture("audio-video"))
    XCTAssertFalse(approved)
  }

  func testAudioOnlyAndMissingFilesFail() async throws {
    let audioOnly = await QASilentVideoAssetInspector.inspect(try fixture("audio-only"))
    let missing = await QASilentVideoAssetInspector.inspect(
      URL(fileURLWithPath: "/nonexistent/ostinato-qa-video.mp4"))
    XCTAssertFalse(audioOnly)
    XCTAssertFalse(missing)
  }

  func testTimeoutAndLateApprovalReplyOnlyOnce() {
    let timedOut = expectation(description: "probe timeout")
    let settled = expectation(description: "late result ignored")
    var completeProbe: ((Bool) -> Void)?
    var replies: [Bool] = []
    let handler = QASilentVideoProbeHandler(
      resolver: { _ in URL(fileURLWithPath: "/unused/silent.mp4") },
      inspector: { _, completion in
        completeProbe = completion
        return {}
      },
      deadline: 0.02
    )
    DispatchQueue.main.async {
      handler.handle(FlutterMethodCall(methodName: "inspectBundledMp4",
                                       arguments: ["asset": self.assetName])) { result in
        replies.append(result as? Bool ?? true)
        timedOut.fulfill()
      }
    }
    wait(for: [timedOut], timeout: 1)
    XCTAssertEqual(replies, [false])
    DispatchQueue.main.async {
      completeProbe?(true)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { settled.fulfill() }
    }
    wait(for: [settled], timeout: 1)
    XCTAssertEqual(replies, [false])
  }

  func testInvalidNameNeverCallsResolverOrInspector() {
    var called = false
    let handler = QASilentVideoProbeHandler(
      resolver: { _ in called = true; return nil },
      inspector: { _, _ in called = true; return {} }
    )
    let replied = expectation(description: "invalid name rejected")
    DispatchQueue.main.async {
      handler.handle(FlutterMethodCall(methodName: "inspectBundledMp4",
                                       arguments: ["asset": "../audio.mp4"])) { result in
        XCTAssertEqual(result as? Bool, false)
        replied.fulfill()
      }
    }
    wait(for: [replied], timeout: 1)
    XCTAssertFalse(called)
  }

  func testEngineReplacementFencesLateResult() {
    let invalidated = expectation(description: "engine replacement reply")
    let settled = expectation(description: "late old reply ignored")
    var completeProbe: ((Bool) -> Void)?
    var replies: [Bool] = []
    let handler = QASilentVideoProbeHandler(
      resolver: { _ in URL(fileURLWithPath: "/unused/silent.mp4") },
      inspector: { _, completion in
        completeProbe = completion
        return {}
      }
    )
    DispatchQueue.main.async {
      handler.handle(FlutterMethodCall(methodName: "inspectBundledMp4",
                                       arguments: ["asset": self.assetName])) { result in
        replies.append(result as? Bool ?? true)
        invalidated.fulfill()
      }
      handler.invalidate()
      completeProbe?(true)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { settled.fulfill() }
    }
    wait(for: [invalidated, settled], timeout: 1)
    XCTAssertEqual(replies, [false])
  }
}
