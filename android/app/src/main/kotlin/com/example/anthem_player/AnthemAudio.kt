package com.example.anthem_player

import android.content.Context
import android.app.Activity
import android.app.NotificationManager
import android.media.*
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** API 26+. Changes STREAM_MUSIC once per explicit start, never while playing. */
class AnthemAudio(context: Context, engine: FlutterEngine) {
    private val manager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val notifications = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val window = (context as? Activity)?.window
    private var priorInterruptionFilter: Int? = null
    private val assets = context.assets
    private val handler = Handler(Looper.getMainLooper())
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "anthem/audio")
    private var player: MediaPlayer? = null
    private var pending: MethodChannel.Result? = null
    private var generation = 0
    private var prepared = false
    private var state = "idle"
    private var error: String? = null
    private var notice: String? = null
    private var hasFocus = false
    private val attributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()
    private val focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
        .setAudioAttributes(attributes)
        .setOnAudioFocusChangeListener({ change ->
            if (change != AudioManager.AUDIOFOCUS_GAIN) stop()
        }, handler).build()

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> play(call.argument<Boolean>("maximize") == true,
                    call.argument<Boolean>("restart") == true, result)
                "stop" -> { stop(); result.success(null) }
                "status" -> result.success(mapOf(
                    "state" to state,
                    "position" to if (prepared) (player?.currentPosition ?: 0) / 1000.0 else 0.0,
                    "duration" to if (prepared) (player?.duration ?: 0) / 1000.0 else 0.0,
                    "notice" to notice, "error" to error))
                else -> result.notImplemented()
            }
        }
    }

    private fun play(maximize: Boolean, restart: Boolean, result: MethodChannel.Result) {
        if (pending != null) { result.error("BUSY", "正在准备播放", null); return }
        error = null
        notice = null
        if (state == "playing" && !restart) { result.success(null); return }
        pending = result
        val ticket = ++generation
        handler.postDelayed({
            if (ticket == generation && pending != null) fail("准备播放超时，请重试")
        }, 10000)
        if (prepared && player != null) {
            if (restart) {
                player!!.setOnSeekCompleteListener { p ->
                    p.setOnSeekCompleteListener(null)
                    if (ticket == generation) begin(p, maximize, ticket)
                }
                player!!.pause()
                player!!.seekTo(0)
            } else begin(player!!, maximize, ticket)
            return
        }
        try {
            player?.release()
            val p = MediaPlayer()
            player = p
            state = "preparing"
            p.setAudioAttributes(attributes)
            p.isLooping = true
            p.setVolume(0f, 0f)
            val key = io.flutter.FlutterInjector.instance().flutterLoader()
                .getLookupKeyForAsset("assets/audio/anthem.wav")
            // Read via a descriptor, without requiring network or storage permissions.
            assets.openFd(key).use { p.setDataSource(it.fileDescriptor, it.startOffset, it.length) }
            p.setOnErrorListener { _, _, _ -> fail("音频播放失败，请重试"); true }
            p.setOnCompletionListener {
                state = "completed"
                window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                abandonFocus()
                restoreSoundPolicy()
            }
            p.addOnRoutingChangedListener(AudioRouting.OnRoutingChangedListener {
                if (prepared && state == "playing" &&
                    p.routedDevice?.type != AudioDeviceInfo.TYPE_BUILTIN_SPEAKER) {
                    p.setVolume(0f, 0f)
                    fail("音频输出已改变，播放已停止。请重新播放以使用扬声器。")
                }
            }, handler)
            p.setOnPreparedListener {
                if (ticket != generation) return@setOnPreparedListener
                prepared = true
                begin(p, maximize, ticket)
            }
            p.prepareAsync()
        } catch (e: Exception) { fail("无法加载本地录音：${e.localizedMessage}") }
    }

    private fun begin(p: MediaPlayer, maximize: Boolean, ticket: Int) {
        try {
            startPosition = p.currentPosition
            val speaker = manager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                .firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
                ?: throw IllegalStateException("未找到内置扬声器")
            if (!p.setPreferredDevice(speaker)) throw IllegalStateException("系统拒绝切换扬声器")
            if (!hasFocus) {
                hasFocus = manager.requestAudioFocus(focus) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
            }
            if (!hasFocus) throw IllegalStateException("其他应用或通话正在占用音频")
            prepareSoundPolicy()
            state = "routing"
            p.setVolume(0f, 0f)
            p.start()
            checkRoute(p, maximize, ticket, 0)
        } catch (e: Exception) { fail(e.localizedMessage ?: "无法开始播放") }
    }

    private fun checkRoute(p: MediaPlayer, maximize: Boolean, ticket: Int, attempt: Int) {
        handler.postDelayed({
            if (ticket != generation) return@postDelayed
            try {
                if (p.routedDevice?.type != AudioDeviceInfo.TYPE_BUILTIN_SPEAKER) {
                    if (attempt < 15) checkRoute(p, maximize, ticket, attempt + 1)
                    else fail("系统未将音频切换到扬声器，请断开耳机或蓝牙设备后重试")
                    return@postDelayed
                }
                if (maximize) {
                    // Once per button start, never a volume-change listener or timer.
                    try {
                        val maximum = manager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                        manager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_UNMUTE, 0)
                        manager.setStreamVolume(AudioManager.STREAM_MUSIC, maximum, 0)
                        if (manager.isVolumeFixed ||
                            manager.isStreamMute(AudioManager.STREAM_MUSIC) ||
                            manager.getStreamVolume(AudioManager.STREAM_MUSIC) < maximum) {
                            addNotice("系统限制了音量，请在系统声音设置中调整")
                        }
                    } catch (_: SecurityException) {
                        addNotice("系统未允许自动调节音量，请使用音量键调整")
                    }
                }
                // Route negotiation was silent. Rewind before making the actual song audible.
                p.setOnSeekCompleteListener {
                    it.setOnSeekCompleteListener(null)
                    if (ticket == generation) {
                        try {
                            if (it.routedDevice?.type != AudioDeviceInfo.TYPE_BUILTIN_SPEAKER) {
                                fail("无法确认扬声器输出，请重试")
                            } else { it.setVolume(1f, 1f); completeStart() }
                        } catch (e: Exception) { fail(e.localizedMessage ?: "播放失败") }
                    }
                }
                p.seekTo(startPosition)
            } catch (e: Exception) { fail(e.localizedMessage ?: "无法切换扬声器") }
        }, 60)
    }

    private var startPosition = 0

    private fun addNotice(message: String) {
        notice = listOfNotNull(notice, message).distinct().joinToString("\n")
    }

    private fun prepareSoundPolicy() {
        if (manager.isVolumeFixed) addNotice("本设备使用固定音量策略，应用无法更改系统音量")
        val current = notifications.currentInterruptionFilter
        if (current == NotificationManager.INTERRUPTION_FILTER_ALL ||
            current == NotificationManager.INTERRUPTION_FILTER_UNKNOWN) return
        if (!notifications.isNotificationPolicyAccessGranted) {
            addNotice("勿扰模式已开启，可在权限设置中授权或允许媒体声音")
            return
        }
        if (Build.VERSION.SDK_INT >= 35) {
            // Apps targeting 35+ cannot clear another mode's global DND state.
            addNotice("当前 Android 需在系统勿扰设置中允许媒体声音或关闭勿扰")
            return
        }
        try {
            priorInterruptionFilter = current
            notifications.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
        } catch (_: SecurityException) {
            priorInterruptionFilter = null
            addNotice("系统未允许解除勿扰，请在系统设置中调整")
        }
    }

    private fun restoreSoundPolicy() {
        val prior = priorInterruptionFilter ?: return
        priorInterruptionFilter = null
        try {
            if (Build.VERSION.SDK_INT < 35 && notifications.isNotificationPolicyAccessGranted &&
                notifications.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_ALL) {
                notifications.setInterruptionFilter(prior)
            }
        } catch (_: SecurityException) { /* Permission may have been revoked while playing. */ }
    }

    private fun completeStart() {
        window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        state = "playing"; pending?.success(null); pending = null
    }

    fun stop() {
        window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        ++generation
        pending?.error("CANCELLED", "播放已停止", null)
        pending = null
        player?.release()
        player = null
        prepared = false
        startPosition = 0
        state = "stopped"
        error = null
        notice = null
        abandonFocus()
        restoreSoundPolicy()
    }

    private fun abandonFocus() {
        if (hasFocus) manager.abandonAudioFocusRequest(focus)
        hasFocus = false
    }

    private fun fail(message: String) {
        window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        ++generation
        error = message
        state = "error"
        pending?.error("AUDIO", message, null)
        pending = null
        player?.release(); player = null; prepared = false; startPosition = 0
        abandonFocus()
        restoreSoundPolicy()
    }

    fun dispose() { stop(); channel.setMethodCallHandler(null) }
}
