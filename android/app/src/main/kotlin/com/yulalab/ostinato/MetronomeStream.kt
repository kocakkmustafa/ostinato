package com.yulalab.ostinato

/** F2.2: one endless click stream. Beat `n` starts at stream frame `n * framesPerBeat`
 * (Dart reference: lib/app/practice/loop/metronome.dart, ClickTrackRenderer). The click is a
 * 6 kHz burst, above the <=4 kHz onset band (E50 M1), so it never marks playbackActive. */
internal class MetronomeStreamSpec(
  val sampleRate: Int,
  val framesPerBeat: Int,
  val beatsPerBar: Int,
  val accent: FloatArray,
  val beat: FloatArray,
  val leadInMs: Int,
) {
  val isValid: Boolean get() {
    fun click(c: FloatArray) = c.isNotEmpty() && c.size < framesPerBeat &&
      c.all { it.isFinite() && kotlin.math.abs(it) <= 1f }
    return (sampleRate == 44100 || sampleRate == 48000) &&
      framesPerBeat >= sampleRate * 60 / 300 && framesPerBeat <= sampleRate * 60 / 20 &&
      beatsPerBar in 1..12 && leadInMs in 0..2000 && click(accent) && click(beat)
  }
}

/** Hardware-free renderer, the Kotlin port of the Dart reference. */
internal class MetronomeStreamRenderer(private val spec: MetronomeStreamSpec) {
  /** Adds stream frames [startFrame, startFrame + out.size) into [out]. */
  fun render(startFrame: Long, out: FloatArray) {
    val fpb = spec.framesPerBeat.toLong()
    val end = startFrame + out.size
    var beat = maxOf(0L, startFrame / fpb - 1)
    while (beat * fpb < end) {
      val click = if (beat % spec.beatsPerBar == 0L) spec.accent else spec.beat
      val at = beat * fpb
      val from = maxOf(at, startFrame)
      val to = minOf(at + click.size, end)
      var f = from
      while (f < to) {
        out[(f - startFrame).toInt()] += click[(f - at).toInt()]
        f++
      }
      beat++
    }
  }
}
