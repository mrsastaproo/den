package com.mrsastaproo.den

import android.media.audiofx.Equalizer
import android.media.audiofx.LoudnessEnhancer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {

    private val CHANNEL = "den/equalizer"
    private var equalizer: Equalizer? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null
    private var currentSessionId: Int = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setEqualizer" -> {
                        try {
                            val sessionId  = call.argument<Int>("sessionId") ?: 0
                            val enabled    = call.argument<Boolean>("enabled") ?: true
                            val bands      = call.argument<List<Double>>("bands") ?: emptyList()
                            val masterGain = call.argument<Double>("masterGain") ?: 0.0

                            // Re-create effects if session changed
                            if (sessionId != currentSessionId) {
                                equalizer?.release()
                                loudnessEnhancer?.release()
                                equalizer = null
                                loudnessEnhancer = null
                                currentSessionId = sessionId
                            }

                            if (sessionId != 0) {
                                if (equalizer == null) {
                                    equalizer = Equalizer(0, sessionId)
                                    loudnessEnhancer = LoudnessEnhancer(sessionId)
                                }

                                val eq = equalizer!!
                                eq.enabled = enabled

                                if (enabled) {
                                    val numBands = eq.numberOfBands.toInt()
                                    val range    = eq.getBandLevelRange()

                                    for (i in 0 until minOf(numBands, bands.size)) {
                                        val gainMb  = (bands[i] * 100).toInt()
                                        val clamped = gainMb.coerceIn(range[0].toInt(), range[1].toInt())
                                        eq.setBandLevel(i.toShort(), clamped.toShort())
                                    }

                                    // Master gain via LoudnessEnhancer
                                    val gainMb = (masterGain * 100).toInt()
                                    loudnessEnhancer?.let { le ->
                                        if (gainMb > 0) {
                                            le.setTargetGain(gainMb)
                                            le.enabled = true
                                        } else {
                                            le.enabled = false
                                        }
                                    }
                                }
                            }

                            result.success(null)
                        } catch (e: Exception) {
                            result.error("EQ_ERROR", e.message, null)
                        }
                    }
                    "releaseEqualizer" -> {
                        equalizer?.release()
                        loudnessEnhancer?.release()
                        equalizer = null
                        loudnessEnhancer = null
                        currentSessionId = 0
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        equalizer?.release()
        loudnessEnhancer?.release()
        super.onDestroy()
    }
}