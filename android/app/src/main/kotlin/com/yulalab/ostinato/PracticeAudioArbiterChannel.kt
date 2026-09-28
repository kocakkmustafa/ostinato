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
  private var retired = false

  fun register(engine: FlutterEngine) {
    channel = MethodChannel(engine.dartExecutor.binaryMessenger,
      "com.yulalab.ostinato/practice_audio_v1")
      .apply { setMethodCallHandler(this@PracticeAudioArbiterChannel) }
  }

  fun retire() {
    if (retired) return
    retired = true
    channel?.setMethodCallHandler(null)
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
}
