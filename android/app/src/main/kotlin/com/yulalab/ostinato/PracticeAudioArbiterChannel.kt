package com.yulalab.ostinato

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** A channel handler belongs to one engine; the process arbiter owns all state. */
internal class PracticeAudioArbiterChannel(
  private val arbiter: PracticeAudioArbiter,
  private val binding: PracticeAudioArbiter.Binding,
) : MethodChannel.MethodCallHandler {
  private var channel: MethodChannel? = null
  @Volatile
  private var retired = false

  fun register(engine: FlutterEngine) {
    channel = MethodChannel(engine.dartExecutor.binaryMessenger,
      "com.yulalab.ostinato/practice_audio_v1")
      .apply { setMethodCallHandler(this@PracticeAudioArbiterChannel) }
  }

  /** The binding's exact registry claim decides whether physical clear is safe. */
  fun retire(clearHandler: Boolean) {
    if (retired) return
    retired = true
    if (clearHandler) channel?.setMethodCallHandler(null)
    channel = null
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    if (retired || !arbiter.isCurrent(binding)) {
      result.error("stale_audio_owner", null, null)
      return
    }
    try {
      val args = call.arguments as? Map<*, *>
        ?: throw PracticeAudioArbiter.AudioFault("bad_args")
      when (call.method) {
        "bind" -> {
          exact(args, "schemaVersion")
          if (args["schemaVersion"] != 1) throw PracticeAudioArbiter.AudioFault("bad_args")
          result.success(arbiter.bind(binding))
        }
        "readAllAudioState" -> {
          exact(args, "ownerToken", "engineGeneration")
          result.success(arbiter.readAllAudioState(binding, token(args), number(args, "engineGeneration")))
        }
        "rebindQuiescentOwner" -> {
          exact(args, "retiredOwnerToken", "retiredEngineGeneration", "reason")
          if (string(args, "reason") != "userRetry") {
            throw PracticeAudioArbiter.AudioFault("bad_args")
          }
          val retiredToken = string(args, "retiredOwnerToken")
          val retiredGeneration = number(args, "retiredEngineGeneration")
          val before = arbiter.quiescentOwnerHandoff(binding, retiredToken, retiredGeneration)
          val engine = binding.engine as? FlutterEngine
            ?: throw PracticeAudioArbiter.AudioFault("video_bridge_unavailable")
          val install = VendorVideoPermitBridge.installForEngine(engine, binding, arbiter)
          if (install != VendorVideoPermitBridge.InstallResult.INSTALLED &&
              install != VendorVideoPermitBridge.InstallResult.REBOUND) {
            throw PracticeAudioArbiter.AudioFault("video_bridge_unavailable")
          }
          val after = arbiter.quiescentOwnerHandoff(binding, retiredToken, retiredGeneration)
          val first = before["snapshot"] as? Map<*, *>
            ?: throw PracticeAudioArbiter.AudioFault("quiescent_handoff_changed")
          val second = after["snapshot"] as? Map<*, *>
            ?: throw PracticeAudioArbiter.AudioFault("quiescent_handoff_changed")
          if (before["retiredOwnerToken"] != after["retiredOwnerToken"] ||
              before["retiredEngineGeneration"] != after["retiredEngineGeneration"] ||
              before["retiredContextGeneration"] != after["retiredContextGeneration"] ||
              before["retiredStateRevision"] != after["retiredStateRevision"] ||
              first != second || second["allClear"] != true) {
            throw PracticeAudioArbiter.AudioFault("quiescent_handoff_changed")
          }
          result.success(mapOf(
            "schemaVersion" to 1,
            "bridgeReady" to true,
            "handoff" to after,
          ))
        }
        "reserve" -> {
          exact(args, "ownerToken", "engineGeneration", "contextGeneration", "leaseId", "side")
          result.success(arbiter.reserve(binding, token(args), number(args, "engineGeneration"),
            number(args, "contextGeneration"), string(args, "leaseId"), string(args, "side")))
        }
        "startOutput" -> {
          exact(args, "ownerToken", "engineGeneration", "contextGeneration", "leaseId",
            "leaseGeneration", "assetId")
          arbiter.startOutput(binding, token(args), number(args, "engineGeneration"),
            number(args, "contextGeneration"), string(args, "leaseId"),
            number(args, "leaseGeneration"), string(args, "assetId"),
            object : PracticeAudioArbiter.Reply {
              override fun success(value: Map<String, Any?>) { result.success(value) }
              override fun error(code: String) { result.error(code, null, null) }
            })
        }
        "closeAll" -> {
          exact(args, "ownerToken", "engineGeneration", "contextGeneration", "leaseId",
            "leaseGeneration", "reason")
          result.success(arbiter.closeAll(binding, token(args), number(args, "engineGeneration"),
            number(args, "contextGeneration"), string(args, "leaseId"),
            number(args, "leaseGeneration"), string(args, "reason")))
        }
        "completeVideoDispose" -> {
          exact(args, "ownerToken", "engineGeneration", "contextGeneration", "leaseId",
            "leaseGeneration", "confirmed")
          result.success(arbiter.completeVideoDispose(binding, token(args),
            number(args, "engineGeneration"), number(args, "contextGeneration"),
            string(args, "leaseId"), number(args, "leaseGeneration"),
            args["confirmed"] as? Boolean ?: throw PracticeAudioArbiter.AudioFault("bad_args")))
        }
        "completeRetiredVideoDispose" -> {
          exact(args, "ownerToken", "engineGeneration", "contextGeneration", "leaseId",
            "leaseGeneration", "confirmed")
          result.success(arbiter.completeRetiredVideoDispose(binding, token(args),
            number(args, "engineGeneration"), number(args, "contextGeneration"),
            string(args, "leaseId"), number(args, "leaseGeneration"),
            args["confirmed"] as? Boolean ?: throw PracticeAudioArbiter.AudioFault("bad_args")))
        }
        "readVideoDisposeReceipt" -> {
          exact(args, "ownerToken", "engineGeneration", "contextGeneration", "leaseId",
            "leaseGeneration")
          result.success(arbiter.readVideoDisposeReceipt(binding, token(args),
            number(args, "engineGeneration"), number(args, "contextGeneration"),
            string(args, "leaseId"), number(args, "leaseGeneration")))
        }
        "rebindVideoPermitBridge" -> {
          exact(args, "ownerToken", "engineGeneration", "contextGeneration", "leaseId",
            "leaseGeneration")
          val originalToken = token(args)
          val originalEngine = number(args, "engineGeneration")
          val originalContext = number(args, "contextGeneration")
          val originalId = string(args, "leaseId")
          val originalLease = number(args, "leaseGeneration")
          val before = arbiter.readVideoDisposeReceipt(binding, originalToken,
            originalEngine, originalContext, originalId, originalLease)
          if (before["ackStatus"] != "RECORDED" ||
              before["nativeReleaseRecorded"] != true ||
              before["leaseSettled"] != true ||
              (before["snapshot"] as? Map<*, *>)?.get("allClear") != true) {
            throw PracticeAudioArbiter.AudioFault("video_handoff_pending")
          }
          val engine = binding.engine as? FlutterEngine
            ?: throw PracticeAudioArbiter.AudioFault("video_bridge_unavailable")
          val install = VendorVideoPermitBridge.installForEngine(engine, binding, arbiter)
          if (install != VendorVideoPermitBridge.InstallResult.INSTALLED &&
              install != VendorVideoPermitBridge.InstallResult.REBOUND) {
            throw PracticeAudioArbiter.AudioFault("video_bridge_unavailable")
          }
          val after = arbiter.readVideoDisposeReceipt(binding, originalToken,
            originalEngine, originalContext, originalId, originalLease)
          if (after["ackStatus"] != "RECORDED" ||
              after["nativeReleaseRecorded"] != true ||
              after["leaseSettled"] != true ||
              (after["snapshot"] as? Map<*, *>)?.get("allClear") != true) {
            throw PracticeAudioArbiter.AudioFault("video_handoff_changed")
          }
          result.success(mapOf("schemaVersion" to 1,
            "bridgeReady" to true, "ack" to after))
        }
        "cancelVideoReservation" -> {
          exact(args, "ownerToken", "engineGeneration", "contextGeneration", "leaseId",
            "leaseGeneration")
          result.success(arbiter.cancelVideoReservation(binding, token(args),
            number(args, "engineGeneration"), number(args, "contextGeneration"),
            string(args, "leaseId"), number(args, "leaseGeneration")))
        }
        "cancelUnclaimedVideoReservation" -> {
          exact(args, "ownerToken", "engineGeneration", "attemptOwnerToken",
            "attemptEngineGeneration", "attemptContextGeneration", "leaseId",
            "leaseGeneration", "expectedStateRevision")
          result.success(arbiter.cancelUnclaimedVideoReservation(binding, token(args),
            number(args, "engineGeneration"), string(args, "attemptOwnerToken"),
            number(args, "attemptEngineGeneration"), number(args, "attemptContextGeneration"),
            string(args, "leaseId"), nullableNumber(args, "leaseGeneration"),
            number(args, "expectedStateRevision")))
        }
        "recoverAll" -> {
          exact(args, "ownerToken", "engineGeneration", "expectedStateRevision", "reason")
          result.success(arbiter.recoverAll(binding, token(args), number(args, "engineGeneration"),
            number(args, "expectedStateRevision"), string(args, "reason")))
        }
        "fenceContext" -> {
          exact(args, "ownerToken", "engineGeneration", "contextGeneration", "reason")
          result.success(arbiter.fenceContext(binding, token(args), number(args, "engineGeneration"),
            number(args, "contextGeneration"), string(args, "reason")))
        }
        else -> result.notImplemented()
      }
    } catch (fault: PracticeAudioArbiter.AudioFault) {
      result.error(fault.code, null, null)
    }
  }

  private fun exact(args: Map<*, *>, vararg fields: String) {
    if (args.keys != fields.toSet()) throw PracticeAudioArbiter.AudioFault("bad_args")
  }
  private fun string(args: Map<*, *>, field: String): String =
    args[field] as? String ?: throw PracticeAudioArbiter.AudioFault("bad_args")
  private fun token(args: Map<*, *>): String = string(args, "ownerToken")
  private fun number(args: Map<*, *>, field: String): Long = when (val value = args[field]) {
    is Int -> value.toLong()
    is Long -> value
    else -> throw PracticeAudioArbiter.AudioFault("bad_args")
  }
  private fun nullableNumber(args: Map<*, *>, field: String): Long? =
    if (args[field] == null) null else number(args, field)
}
