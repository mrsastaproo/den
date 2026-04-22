package com.mrsastaproo.den

import android.media.audiofx.Equalizer
import android.media.audiofx.LoudnessEnhancer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import java.io.File
import android.os.Build
import android.os.Bundle
import android.view.WindowManager

class MainActivity : AudioServiceActivity() {

    private val CHANNEL = "den/equalizer"
    private var equalizer: Equalizer? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null
    private var currentSessionId: Int = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableHighRefreshRate()
    }

    /**
     * Request the highest available display refresh rate (120Hz / 90Hz / 60Hz).
     * On Android 6+ we iterate supported display modes and pick the one with
     * the highest refresh rate matching the current resolution.
     */
    private fun enableHighRefreshRate() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val display = windowManager.defaultDisplay
            val supportedModes = display.supportedModes
            // Pick the mode with the highest refresh rate
            val bestMode = supportedModes.maxByOrNull { it.refreshRate }
            if (bestMode != null) {
                val params: WindowManager.LayoutParams = window.attributes
                params.preferredDisplayModeId = bestMode.modeId
                window.attributes = params
            }
        }
    }


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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.mrsastaproo.den/updater")
            .setMethodCallHandler { call, result ->
                if (call.method == "installApk") {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        try {
                            installApk(path)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("INSTALL_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "Path is null", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun installApk(path: String) {
        val file = File(path)
        if (!file.exists()) throw Exception("File not found at $path")

        val uri: Uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file
        )

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
    }

    override fun onDestroy() {
        equalizer?.release()
        loudnessEnhancer?.release()
        super.onDestroy()
    }
}