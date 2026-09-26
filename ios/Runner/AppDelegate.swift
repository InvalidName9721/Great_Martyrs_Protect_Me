import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private var anthemAudio: AnthemAudio?
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        anthemAudio = AnthemAudio(messenger: engineBridge.applicationRegistrar.messenger())
    }
}

final class AnthemAudio: NSObject, AVAudioPlayerDelegate {
    private let session = AVAudioSession.sharedInstance()
    private let channel: FlutterMethodChannel
    private let setupChannel: FlutterMethodChannel
    private var player: AVAudioPlayer?
    private var state = "idle"
    private var lastError: String?
    private var sessionActive = false

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "anthem/audio", binaryMessenger: messenger)
        setupChannel = FlutterMethodChannel(name: "anthem/setup", binaryMessenger: messenger)
        super.init()
        setupChannel.setMethodCallHandler { call, result in
            switch call.method {
            case "read", "requestBluetooth":
                result([
                    "platform": "ios",
                    "firstRun": !UserDefaults.standard.bool(forKey: "manualPlayerSetupV1"),
                    "bluetoothSupported": false,
                    "bluetoothPermission": "notRequired"
                ])
            case "complete":
                UserDefaults.standard.set(true, forKey: "manualPlayerSetupV1")
                result(nil)
            case "openBluetoothSettings":
                // There is no public URL for the iOS Bluetooth settings pane.
                result(FlutterError(code: "UNSUPPORTED", message: "请打开 iPhone 设置 → 蓝牙", details: nil))
            default: result(FlutterMethodNotImplemented)
            }
        }
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { result(FlutterError(code: "DISPOSED", message: "播放器已关闭", details: nil)); return }
            switch call.method {
            case "play":
                let args = call.arguments as? [String: Any]
                do { try self.play(restart: args?["restart"] as? Bool ?? false); result(nil) }
                catch {
                    self.stop()
                    self.state = "error"
                    self.lastError = error.localizedDescription
                    result(FlutterError(code: "AUDIO", message: error.localizedDescription, details: nil))
                }
            case "stop": self.stop(); result(nil)
            case "status":
                let notice: Any = self.state == "playing" && self.session.outputVolume == 0
                    ? "当前系统音量为零，请按音量键调高" as Any : NSNull()
                result([
                    "state": self.state,
                    "position": self.player?.currentTime ?? 0,
                    "duration": self.player?.duration ?? 0,
                    "notice": notice,
                    "error": self.lastError as Any? ?? NSNull()
                ])
            default: result(FlutterMethodNotImplemented)
            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted),
            name: AVAudioSession.interruptionNotification, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(routeChanged),
            name: AVAudioSession.routeChangeNotification, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(backgrounded),
            name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(mediaReset),
            name: AVAudioSession.mediaServicesWereResetNotification, object: session)
    }

    private func play(restart: Bool) throws {
        lastError = nil
        if player == nil {
            let key = FlutterDartProject.lookupKey(forAsset: "assets/audio/anthem.wav")
            guard let path = Bundle.main.path(forResource: key, ofType: nil) else {
                throw NSError(domain: "Anthem", code: 1, userInfo: [NSLocalizedDescriptionKey: "未找到本地录音"])
            }
            player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            player?.delegate = self
            player?.numberOfLoops = -1
            player?.prepareToPlay()
        }
        // playAndRecord ignores the Ring/Silent switch and supports the speaker override.
        // No recording is performed. The system output volume remains user-controlled.
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
        sessionActive = true
        try session.overrideOutputAudioPort(.speaker)
        guard session.currentRoute.outputs.contains(where: { $0.portType == .builtInSpeaker }) else {
            throw NSError(domain: "Anthem", code: 2, userInfo: [NSLocalizedDescriptionKey: "系统未允许切换到手机扬声器"])
        }
        player?.volume = 1.0
        if restart || state == "completed" { player?.currentTime = 0 }
        guard player?.play() == true else {
            throw NSError(domain: "Anthem", code: 3, userInfo: [NSLocalizedDescriptionKey: "无法开始播放，请重试"])
        }
        state = "playing"
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
        player = nil
        state = "stopped"
        lastError = nil
        deactivate()
    }

    private func deactivate() {
        UIApplication.shared.isIdleTimerDisabled = false
        guard sessionActive else { return }
        try? session.overrideOutputAudioPort(.none)
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        sessionActive = false
    }

    @objc private func interrupted(_ notification: Notification) {
        if let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
           type == AVAudioSession.InterruptionType.began.rawValue { stop() }
    }
    @objc private func backgrounded() { stop() }
    @objc private func mediaReset() { stop() }
    @objc private func routeChanged() {
        guard state == "playing" else { return }
        if !session.currentRoute.outputs.contains(where: { $0.portType == .builtInSpeaker }) {
            stop()
            lastError = "音频输出已改变，播放已停止。点击播放可重新使用扬声器。"
        }
    }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        state = flag ? "completed" : "error"
        if !flag { lastError = "播放未能完成，请重试" }
        deactivate()
    }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        stop(); state = "error"; lastError = error?.localizedDescription ?? "录音解码失败"
    }
    deinit { NotificationCenter.default.removeObserver(self); channel.setMethodCallHandler(nil); setupChannel.setMethodCallHandler(nil) }
}
