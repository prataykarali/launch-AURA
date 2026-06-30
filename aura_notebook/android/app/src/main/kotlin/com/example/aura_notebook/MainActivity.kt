package com.example.aura_notebook

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.speech.tts.Voice
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.InetAddress
import java.net.URL
import java.util.Locale
import java.util.UUID
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val CHANNEL = "aura/main_app"
    private val TTS_CHANNEL = "aura/tts"
    private val DL_CHANNEL = "aura/download"
    private val VISION_CHANNEL = "aura/vision_context"

    // Android system TextToSpeech. Initialized lazily on the first "speak" so
    // we don't pay the engine warm-up cost at app launch. The Dart side probes
    // "available" first; we only `init()` when a voice is actually requested.
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    // Shared progress sink for the download EventChannel. Registered once in
    // configureFlutterEngine so the Dart listener always finds it (avoids the
    // MissingPluginException race where Dart listens before the handler exists).
    @Volatile private var downloadProgressSink: EventChannel.EventSink? = null
    // One pending result per "speak" call, keyed by the utterance id TTS reports
    // back via UtteranceProgressListener. Lets us complete the Dart Future only
    // after the utterance finishes (or errors), matching the Linux pipeline's
    // awaitable contract so the proactive flow's onComplete fires correctly.
    private val pendingSpeak = mutableMapOf<String, MethodChannel.Result>()
    private val initPendingSpeaks = mutableListOf<Triple<String, Float, MethodChannel.Result>>()
    // Cached voice selected during init — re-applied before every utterance to
    // prevent Samsung's TTS engine from silently overriding it between short clips.
    private var selectedVoice: Voice? = null

    private fun completeResult(result: MethodChannel.Result?, value: Any?) {
        if (result == null) return
        runOnUiThread {
            result.success(value)
        }
    }

    private fun ensureTtsInit() {
        if (tts != null) return
        android.util.Log.d("AuraTTS", "Initializing default TTS engine...")
        initTtsWithEngine(null)
    }

    private fun primeTts() {
        // Kick the synth engine with a near-silent utterance and stop it immediately
        // so it fully initializes the voice DB + audio output path without audible sound.
        // This is the key to eliminating first-speak latency.
        val engine = tts ?: return
        val primeId = "aura-prime-${System.currentTimeMillis()}"
        val params = android.os.Bundle()
        params.putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, 0.0f)
        engine.speak(" ", TextToSpeech.QUEUE_ADD, params, primeId)
        engine.stop()
    }

    private fun selectBestVoice() {
        val engine = tts ?: return
        try {
            val allVoices = engine.voices
            if (allVoices == null) {
                android.util.Log.w("AuraTTS", "No voices returned from TTS engine")
                engine.language = Locale.US
                return
            }
            android.util.Log.d("AuraTTS", "Available voices count: ${allVoices.size}")
            
            // Filter to English voices that are installed
            val englishVoices = allVoices.filter { voice ->
                voice.locale.language == "en" && 
                !voice.features.contains(TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED)
            }
            
            if (englishVoices.isEmpty()) {
                android.util.Log.w("AuraTTS", "No installed English voices found, using default US locale")
                engine.language = Locale.US
                return
            }
            
            // Look for female voices by name
            var chosen = englishVoices.firstOrNull { voice ->
                val name = voice.name.lowercase(Locale.US)
                name.contains("female") || name.contains("fem") || name.contains("jenny") || name.contains("ana")
            }
            
            // If not found, look for known Google female voices
            if (chosen == null) {
                val googleFemaleVoiceNames = listOf(
                    "en-us-x-sfg", "en-us-x-tpf", "en-us-x-iol", "en-us-x-lpf", 
                    "en-us-x-rtg", "en-us-x-low", "en-us-x-gpf", "en-us-x-cbf"
                )
                chosen = englishVoices.firstOrNull { voice ->
                    val name = voice.name.lowercase(Locale.US)
                    googleFemaleVoiceNames.any { prefix -> name.contains(prefix) }
                }
            }
            
            // Fallback: any en-US voice that contains "local" (offline-ready)
            if (chosen == null) {
                chosen = englishVoices.firstOrNull { voice ->
                    voice.locale.country == "US" && voice.name.lowercase(Locale.US).contains("local")
                }
            }
            
            // Fallback 2: any en-US voice
            if (chosen == null) {
                chosen = englishVoices.firstOrNull { voice -> voice.locale.country == "US" }
            }
            
            // Fallback 3: first English voice
            if (chosen == null) {
                chosen = englishVoices.first()
            }
            
            if (chosen != null) {
                android.util.Log.i("AuraTTS", "Selected voice: ${chosen.name} (locale: ${chosen.locale})")
                val res = engine.setVoice(chosen)
                if (res == TextToSpeech.ERROR) {
                    android.util.Log.w("AuraTTS", "Failed to set voice explicitly, falling back to language locale")
                    engine.language = Locale.US
                    // Don't cache a voice that failed to apply.
                } else {
                    // Cache the voice so dispatchUtterance() can re-apply it
                    // before every utterance, preventing Samsung TTS from
                    // silently overriding it between short consecutive clips.
                    selectedVoice = chosen
                }
            } else {
                engine.language = Locale.US
            }
        } catch (e: Exception) {
            android.util.Log.e("AuraTTS", "Error selecting voice: ${e.message}")
            engine.language = Locale.US
        }
    }

    private fun initTtsWithEngine(enginePackage: String?) {
        val listener = object : TextToSpeech.OnInitListener {
            override fun onInit(status: Int) {
                if (status == TextToSpeech.SUCCESS) {
                    android.util.Log.d("AuraTTS", "TTS engine (${enginePackage ?: "default"}) initialized successfully")
                    selectBestVoice()
                    tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                        override fun onStart(utteranceId: String?) {}
                        override fun onDone(utteranceId: String?) {
                            // Resolve the matching pending speak() Future.
                            utteranceId?.let { id ->
                                completeResult(pendingSpeak.remove(id), true)
                            }
                        }
                        override fun onError(utteranceId: String?) {
                            utteranceId?.let { id ->
                                completeResult(pendingSpeak.remove(id), false)
                            }
                        }
                    })
                    ttsReady = true
                    // PRIME: synthesize one short utterance to completion now so
                    // the first REAL speak() (a chat reply) doesn't pay the cold
                    // engine's first-synthesis cost (~300-800ms on Samsung). We
                    // route it through QUEUE_ADD and immediately stop() so it
                    // makes no audible sound but fully initializes the synth
                    // path, voice database, and audio output sink. This is the
                    // difference between "TTS starts a bit slow" and instant.
                    try {
                        val primeId = "aura-prime-${System.currentTimeMillis()}"
                        engine_prime(primeId)
                    } catch (e: Exception) {
                        android.util.Log.d("AuraTTS", "prime skipped: ${e.message}")
                    }
                    // Process any pending speaks queued during warm-up
                    val pending = ArrayList(initPendingSpeaks)
                    initPendingSpeaks.clear()
                    for (item in pending) {
                        dispatchUtterance(item.first, item.second, item.third)
                    }
                } else {
                    android.util.Log.e("AuraTTS", "TTS engine (${enginePackage ?: "default"}) initialization failed: $status")
                    ttsReady = false
                    if (enginePackage == null) {
                        fallbackToOtherEngine()
                    } else {
                        // Complete pending speaks with failure
                        val pending = ArrayList(initPendingSpeaks)
                        initPendingSpeaks.clear()
                        for (item in pending) {
                            completeResult(item.third, false)
                        }
                    }
                }
            }
        }

        try {
            if (enginePackage != null) {
                tts = TextToSpeech(this, listener, enginePackage)
            } else {
                tts = TextToSpeech(this, listener)
            }
        } catch (e: Exception) {
            android.util.Log.e("AuraTTS", "Failed to create TextToSpeech instance: ${e.message}")
            if (enginePackage == null) {
                fallbackToOtherEngine()
            } else {
                val pending = ArrayList(initPendingSpeaks)
                initPendingSpeaks.clear()
                for (item in pending) {
                    completeResult(item.third, false)
                }
            }
        }
    }

    private fun fallbackToOtherEngine() {
        val currentTts = tts
        if (currentTts != null) {
            try {
                val engines = currentTts.engines
                android.util.Log.d("AuraTTS", "Available TTS engines: ${engines.map { it.name }}")
                var fallbackEngine: String? = null
                val engineNames = engines.map { it.name }
                if (engineNames.contains("com.google.android.tts")) {
                    fallbackEngine = "com.google.android.tts"
                } else {
                    fallbackEngine = engines.firstOrNull {
                        !it.name.contains("samsung", ignoreCase = true)
                    }?.name
                }

                currentTts.shutdown()
                tts = null

                if (fallbackEngine != null) {
                    android.util.Log.i("AuraTTS", "Attempting fallback to engine: $fallbackEngine")
                    initTtsWithEngine(fallbackEngine)
                } else {
                    android.util.Log.e("AuraTTS", "No suitable fallback TTS engine found")
                    val pending = ArrayList(initPendingSpeaks)
                    initPendingSpeaks.clear()
                    for (item in pending) {
                        completeResult(item.third, false)
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("AuraTTS", "Error during TTS fallback: ${e.message}")
                currentTts.shutdown()
                tts = null
                val pending = ArrayList(initPendingSpeaks)
                initPendingSpeaks.clear()
                for (item in pending) {
                    completeResult(item.third, false)
                }
            }
        } else {
            android.util.Log.e("AuraTTS", "fallbackToOtherEngine: currentTts is null")
            val pending = ArrayList(initPendingSpeaks)
            initPendingSpeaks.clear()
            for (item in pending) {
                completeResult(item.third, false)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "open_app" -> {
                    val intent = Intent(this, MainActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    }
                    startActivity(intent)
                    result.success(true)
                }
                "request_battery_optimization" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent().apply {
                                action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("BATTERY_OPT_ERROR", e.message, null)
                    }
                }
                "check_battery_optimization" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    } else {
                        result.success(true)
                    }
                }
                "open_app_settings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                "has_usage_access" -> {
                    result.success(hasUsageAccess())
                }
                "request_usage_access" -> {
                    try {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("USAGE_ACCESS_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VISION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "foreground_app" -> result.success(getForegroundAppPackage())
                "has_usage_access" -> result.success(hasUsageAccess())
                "request_usage_access" -> {
                    try {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("USAGE_ACCESS_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ── TTS channel (aura/tts) ────────────────────────────────────────────
        // Backs the Dart-side AuraTTSService on Android. The voice feature is
        // disabled in the Rust build for Android (sherpa-onnx has no prebuilts),
        // so without this the app was completely silent. Uses the platform
        // TextToSpeech engine (offline-capable, ships on every Android device).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TTS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "available" -> {
                    // Don't force-init: report the engine as available (Android
                    // always has a TTS service); actual init happens on speak.
                    result.success(true)
                }
                "speak" -> {
                    handleSpeak(call, result)
                }
                "warmup" -> {
                    // Eager pre-warm. TextToSpeech(context, listener) + the async
                    // onInit callback take ~1–2s on a cold engine. If this only
                    // runs on the first real speak() (the old behaviour), that
                    // first chat reply's TTS starts ~1–2s late. Calling warmup at
                    // engine-ready time constructs + inits the engine NOW and
                    // primes it with a near-silent utterance, so the first real
                    // speak() dispatches immediately. Safe to call repeatedly
                    // (ensureTtsInit is idempotent).
                    ensureTtsInit()
                    if (ttsReady) {
                        primeTts()
                    }
                    result.success(ttsReady)
                }
                "stop" -> {
                    tts?.stop()
                    // Drain any pending speak futures — onDone never fires for
                    // a stopped utterance, so without this they would hang.
                    val draining = ArrayList(pendingSpeak.values)
                    pendingSpeak.clear()
                    for (r in draining) completeResult(r, false)

                    val pendingDraining = ArrayList(initPendingSpeaks)
                    initPendingSpeaks.clear()
                    for (item in pendingDraining) {
                        completeResult(item.third, false)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // ── Download channel (aura/download) ────────────────────────────────
        // Dart's HttpClient DNS resolution fails on some Android cellular
        // networks (RIL DNS stuck / IPv6-only DNS where the app sandbox can't
        // reach it). This channel uses Java's InetAddress + HttpURLConnection
        // which always goes through the Android system resolver that works
        // (proven by `ping` from adb shell resolving fine).
        //   "downloadFile" — downloads url→destPath on a background thread with
        //                    resume support, emitting progress via EventChannel.
        // Register the EventChannel FIRST so Dart listeners always find it.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "$DL_CHANNEL/progress")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                    downloadProgressSink = sink
                }
                override fun onCancel(args: Any?) {
                    downloadProgressSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "downloadFile" -> {
                    val url = call.argument<String>("url") ?: ""
                    val dest = call.argument<String>("destPath") ?: ""
                    if (url.isBlank() || dest.isBlank()) {
                        result.error("INVALID_ARGS", "url and destPath required", null)
                        return@setMethodCallHandler
                    }
                    thread(name = "aura-download") {
                        try {
                            nativeDownload(url, dest)
                            // result callbacks must be on the main thread
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("DL_FAIL", e.message, null) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // Helper: send a progress value to the EventSink safely from ANY thread.
    // EventSink.success() is @UiThread — calling it from a background thread
    // (like "aura-download") throws a "Methods marked with @UiThread must be
    // executed on the main thread" exception which aborts the download.
    private fun emitProgress(value: Double) {
        runOnUiThread {
            downloadProgressSink?.success(value)
        }
    }

    private fun hasUsageAccess(): Boolean {
        return try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    packageName
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    packageName
                )
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            false
        }
    }

    private fun getForegroundAppPackage(): String? {
        if (!hasUsageAccess()) return null
        return try {
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val end = System.currentTimeMillis()
            val begin = end - 60_000L
            val events = usageStatsManager.queryEvents(begin, end)
            val event = android.app.usage.UsageEvents.Event()
            var latestPackage: String? = null
            var latestTime = 0L
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == android.app.usage.UsageEvents.Event.MOVE_TO_FOREGROUND &&
                    event.timeStamp >= latestTime
                ) {
                    latestPackage = event.packageName
                    latestTime = event.timeStamp
                }
            }
            latestPackage
        } catch (e: Exception) {
            android.util.Log.w("AuraVision", "foreground app query failed: ${e.message}")
            null
        }
    }

    private fun nativeDownload(urlStr: String, destPath: String) {
        val partFile = File("$destPath.part")
        val destFile = File(destPath)
        partFile.parentFile?.mkdirs()

        var conn: HttpURLConnection? = null
        val maxAttempts = 5
        for (attempt in 1..maxAttempts) {
            try {
                val url = URL(urlStr)
                conn = url.openConnection() as HttpURLConnection
                conn.connectTimeout = 30_000
                conn.readTimeout = 60_000
                conn.instanceFollowRedirects = false
                conn.setRequestProperty("User-Agent", "Mozilla/5.0")

                // Resume from existing partial
                if (partFile.exists()) {
                    val start = partFile.length()
                    conn.setRequestProperty("Range", "bytes=$start-")
                }

                conn.connect()
                val code = conn.responseCode

                // Handle redirects manually.
                // HuggingFace CDN sometimes returns a *relative* Location header
                // (e.g. "/api/resolve-cache/..."). URL(relative) throws
                // "no protocol", so resolve it against the original request URL.
                if (code in 300..399) {
                    val raw = conn.getHeaderField("Location")
                        ?: throw Exception("Redirect with no Location header")
                    val resolved = when {
                        raw.startsWith("http://") || raw.startsWith("https://") -> raw
                        raw.startsWith("//") -> "${url.protocol}:$raw"
                        raw.startsWith("/") -> {
                            val port = url.port
                            val portStr = if (port > 0 && port != 80 && port != 443) ":$port" else ""
                            "${url.protocol}://${url.host}$portStr$raw"
                        }
                        else -> "${urlStr.substringBeforeLast('/')}/$raw"
                    }
                    android.util.Log.d("AuraDl", "redirect $code → $resolved")
                    nativeDownload(resolved, destPath)
                    return
                }

                if (code != 200 && code != 206) {
                    if (code == 416) {
                        partFile.delete()
                        continue // retry from scratch
                    }
                    throw Exception("HTTP $code")
                }

                val isResume = code == 206
                val bodyStream = conn.inputStream
                val contentLength = if (isResume) {
                    val range = conn.getHeaderField("Content-Range") ?: ""
                    range.substringAfter("/").toLongOrNull() ?: conn.contentLength + partFile.length()
                } else {
                    conn.contentLength.toLong()
                }
                val startOffset = if (isResume) partFile.length() else 0L

                FileOutputStream(partFile, isResume).use { out ->
                    val buf = ByteArray(16384)
                    var totalRead = startOffset
                    while (true) {
                        val n = bodyStream.read(buf)
                        if (n < 0) break
                        out.write(buf, 0, n)
                        totalRead += n
                        // Emit progress via UI thread — EventSink is @UiThread
                        if (contentLength > 0) {
                            emitProgress(totalRead.toDouble() / contentLength)
                        }
                    }
                }
                bodyStream.close()

                // Atomic rename
                if (destFile.exists()) destFile.delete()
                partFile.renameTo(destFile)
                emitProgress(1.0) // signal 100%
                return
            } catch (e: Exception) {
                android.util.Log.w("AuraDl", "download attempt $attempt failed: ${e.message}")
                if (attempt == maxAttempts) throw e
                Thread.sleep(3000L * attempt)
            } finally {
                conn?.disconnect()
            }
        }
    }

    private fun handleSpeak(call: MethodCall, result: MethodChannel.Result) {
        ensureTtsInit()
        val text = call.argument<String>("text") ?: ""
        if (text.isBlank()) {
            result.success(true)
            return
        }
        val volume = call.argument<Double>("volume")?.toFloat() ?: 1.0f
        if (!ttsReady) {
            android.util.Log.d("AuraTTS", "TTS is warming up; queuing speak request: \"$text\" with volume $volume")
            initPendingSpeaks.add(Triple(text, volume, result))
            return
        }
        dispatchUtterance(text, volume, result)
    }

    private fun dispatchUtterance(text: String, volume: Float, result: MethodChannel.Result) {
        val engine = tts
        if (engine == null || !ttsReady) {
            result.success(false)
            return
        }
        val id = UUID.randomUUID().toString()
        pendingSpeak[id] = result
        // Re-apply the cached voice before every utterance to prevent Samsung's
        // TTS engine from silently overriding it between consecutive short clips
        // (a known Samsung behaviour that causes audible voice switching).
        val voice = selectedVoice
        if (voice != null) {
            try {
                engine.setVoice(voice)
            } catch (e: Exception) {
                android.util.Log.w("AuraTTS", "Re-apply voice failed (non-fatal): ${e.message}")
            }
        }
        // QUEUE_ADD (not QUEUE_FLUSH): each utterance is appended to the queue
        // and plays in order. The Dart layer now serializes speak() calls via
        // a single-writer chain (tts_service.dart), so only one utterance is
        // ever in-flight — but ADD (vs FLUSH) guarantees we never cut off an
        // utterance that's still playing if two arrive close together. FLUSH
        // was the root cause of the "repeats / stuttering / cut-off" symptom.
        val params = android.os.Bundle()
        params.putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, volume)
        val spoken = engine.speak(text, TextToSpeech.QUEUE_ADD, params, id)
        if (spoken != TextToSpeech.SUCCESS) {
            pendingSpeak.remove(id)
            result.success(false)
            return
        }

        val pauseMs = punctuationPauseMs(text)
        if (pauseMs > 0) {
            val pauseId = "pause-$id"
            engine.playSilentUtterance(
                pauseMs.toLong(),
                TextToSpeech.QUEUE_ADD,
                pauseId
            )
        }
    }

    private fun punctuationPauseMs(text: String): Int {
        val trimmed = text.trimEnd()
        if (trimmed.isBlank()) return 0
        return when {
            trimmed.endsWith("\n\n") -> 900
            trimmed.endsWith("...") || trimmed.endsWith("…") || trimmed.endsWith("—") -> 650
            trimmed.endsWith(".") || trimmed.endsWith("!") || trimmed.endsWith("?") -> 400
            trimmed.endsWith(",") -> 180
            else -> 0
        }
    }

    /// Warm-up helper: kick the synth engine with a near-silent utterance and
    /// stop it immediately so it produces NO audible sound but fully
    /// initializes the voice DB + audio output path. Called once after onInit
    /// so the first real chat-reply speak() dispatches instantly. The "prime"
    /// runs at zero volume via a dedicated utteranceParams map; we then stop()
    /// to guarantee no late audio leaks out.
    private fun engine_prime(utteranceId: String) {
        val engine = tts ?: return
        val params = android.os.Bundle()
        // MIN_VOLUME = 0 → the prime is inaudible even if stop() races.
        params.putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, 0.0f)
        engine.speak(" ", TextToSpeech.QUEUE_ADD, params, utteranceId)
        // Stop right away: we only wanted to trigger synth init, not play.
        engine.stop()
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        tts = null
        // Fail any pending speak futures so Dart side doesn't hang.
        val draining = ArrayList(pendingSpeak.values)
        pendingSpeak.clear()
        for (r in draining) r.success(false)
        super.onDestroy()
    }
}
