package com.example.anthem_player

import android.Manifest
import android.app.NotificationManager
import android.bluetooth.BluetoothManager
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var audio: AnthemAudio? = null
    private var setupChannel: MethodChannel? = null
    private var permissionResult: MethodChannel.Result? = null
    private val permissionCode = 4021
    private val preferences by lazy { getSharedPreferences("manual_player_setup", MODE_PRIVATE) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        volumeControlStream = android.media.AudioManager.STREAM_MUSIC
        audio = AnthemAudio(this, flutterEngine)
        setupChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "anthem/setup")
        setupChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "read" -> result.success(readSetup())
                "complete" -> {
                    if (preferences.edit().putBoolean("completed_v2", true).commit()) result.success(null)
                    else result.error("SAVE", "无法保存首次设置，请重试", null)
                }
                "requestBluetooth" -> requestBluetooth(result)
                "openDndAccess" -> openSettings(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS, result)
                "openDndSettings" -> openSettings("android.settings.ZEN_MODE_SETTINGS", result)
                "openSoundSettings" -> openSettings(Settings.ACTION_SOUND_SETTINGS, result)
                "openBluetoothSettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
                        result.success(null)
                    } catch (_: Exception) {
                        result.error("SETTINGS", "无法打开蓝牙设置，请在系统设置中手动打开", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun readSetup(): Map<String, Any?> {
        val notifications = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        val adapter = (getSystemService(BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
        val needsPermission = Build.VERSION.SDK_INT >= 31
        val granted = !needsPermission ||
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        val asked = preferences.getBoolean("asked_bluetooth", false)
        val permission = when {
            !needsPermission -> "notRequired"
            granted -> "granted"
            !asked -> "notRequested"
            shouldShowRequestPermissionRationale(Manifest.permission.BLUETOOTH_CONNECT) -> "denied"
            else -> "blocked"
        }
        val enabled = if (granted) {
            try { adapter?.isEnabled } catch (_: SecurityException) { null }
        } else null
        return mapOf(
            "platform" to "android",
            "firstRun" to !preferences.getBoolean("completed_v2", false),
            "bluetoothSupported" to (adapter != null),
            "bluetoothPermission" to permission,
            "bluetoothEnabled" to enabled,
            "dndAccess" to notifications.isNotificationPolicyAccessGranted,
            "dndActive" to (notifications.currentInterruptionFilter != NotificationManager.INTERRUPTION_FILTER_ALL &&
                notifications.currentInterruptionFilter != NotificationManager.INTERRUPTION_FILTER_UNKNOWN),
            "canTemporarilyDisableDnd" to (Build.VERSION.SDK_INT < 35),
            "fixedVolume" to audioManager.isVolumeFixed
        )
    }

    private fun openSettings(action: String, result: MethodChannel.Result) {
        try {
            startActivity(Intent(action))
            result.success(null)
        } catch (_: Exception) {
            try { startActivity(Intent(Settings.ACTION_SETTINGS)); result.success(null) }
            catch (_: Exception) { result.error("SETTINGS", "无法打开系统设置，请手动打开", null) }
        }
    }

    private fun requestBluetooth(result: MethodChannel.Result) {
        if (permissionResult != null) { result.error("BUSY", "正在等待权限选择", null); return }
        if (Build.VERSION.SDK_INT < 31 || readSetup()["bluetoothSupported"] != true ||
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED) {
            result.success(readSetup())
            return
        }
        permissionResult = result
        preferences.edit().putBoolean("asked_bluetooth", true).apply()
        try {
            requestPermissions(arrayOf(Manifest.permission.BLUETOOTH_CONNECT), permissionCode)
        } catch (_: Exception) {
            permissionResult = null
            result.error("PERMISSION", "无法申请蓝牙状态查询权限，仍可继续使用播放器", null)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == permissionCode) {
            permissionResult?.success(readSetup())
            permissionResult = null
        }
    }

    override fun onStop() {
        audio?.stop()
        super.onStop()
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        audio?.dispose()
        audio = null
        permissionResult?.error("CANCELLED", "权限流程已关闭，下次可重试", null)
        permissionResult = null
        setupChannel?.setMethodCallHandler(null)
        setupChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
