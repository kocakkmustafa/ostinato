package com.yulalab.ostinato

/** A binding fences its own attempt before a replacement may publish channels. */
internal interface AudioCaptureBinding {
  fun retire()
  fun closeBoundAttempt()
}

/** An explicit cancel may only affect the attempt owned by this handler. */
internal fun boundCancelId(boundId: String?, suppliedId: String?): String? =
  if (suppliedId == null || suppliedId == boundId) boundId else null

/** Per-engine channel claims. A process-wide closeState ID is never a claim. */
internal class AudioCaptureBoundIds {
  private val accepted = mutableSetOf<String>()
  var current: String? = null
    private set

  fun bind(id: String) {
    current = id
    accepted.add(id)
  }

  fun owns(id: String): Boolean = id in accepted

  fun cancel(suppliedId: String?): String? {
    val id = boundCancelId(current, suppliedId) ?: return null
    current = null
    return id
  }

  fun closeBound(): String? {
    val id = current
    current = null
    return id
  }

  fun retire(): Set<String> {
    val ids = accepted.toSet()
    current = null
    accepted.clear()
    return ids
  }
}

/** The same synchronous replacement boundary is used by MainActivity and JVM fakes. */
internal class AudioCaptureHandlerSlot {
  private class Entry(val engine: Any, val binding: AudioCaptureBinding)
  private var current: Entry? = null

  fun replace(engine: Any, binding: AudioCaptureBinding, register: () -> Unit) {
    retireCurrent()
    try {
      register()
      current = Entry(engine, binding)
    } catch (error: Throwable) {
      binding.retire()
      throw error
    }
  }

  fun closeCurrent() { current?.binding?.closeBoundAttempt() }

  fun retireCurrent() {
    val old = current ?: return
    old.binding.retire()
    if (current === old) current = null
  }

  fun retireIfEngine(engine: Any) {
    if (current?.engine === engine) retireCurrent()
  }
}
