# 伟大先烈保护我 · 富强民主文明和谐，自由平等公正法治，爱国敬业诚信友善版

当有人怼脸拍摄、断章取义，想把录像上传到平台引导网暴时，打开软件，按下按钮。

耳边立刻响起100%音量的《义勇军进行曲》，无限循环。小红书，微博，微信，抖音，哔哩哔哩，全都留不下关于你的视频。

借这首歌所承载的先烈精神，给遭遇网暴的人一个避风港。

<img width="780" height="1688" alt="anthem_player_preview" src="https://github.com/user-attachments/assets/d2a2ef15-018f-4b3f-8787-7c7057b7e64d" />
## 安装包

**[下载 ARM64 APK · v1.2.0](https://github.com/InvalidName9721/Great_Martyrs_Protect_Me/raw/refs/heads/main/downloads/Great_Martyrs_Protect_Me-arm64-v8a.apk)**（约 24 MiB）

<img src="docs/preview.png" alt="伟大先烈保护我：红金主题与巨大播放按钮" width="360">

仓库文件 `downloads/Great_Martyrs_Protect_Me-arm64-v8a.apk`：1.2.0（版本代码 3），Android 8.0 及以上、ARM64 手机。仅包含 arm64-v8a，不支持 32 位系统或 x86。将 APK 传到手机后打开安装；如系统提示，允许当前文件管理器安装此来源的应用。

这是已编译的 release 包，使用本地测试证书签名，适合安装试用。签名、架构、内置录音与对齐检查通过；尚未在真机安装运行。详细记录见 `VERIFICATION.md`。iOS 仅交付源码，需要 Mac + Xcode 构建。

## 行为

- 打开应用不播放、不调音量。首次使用显示设置说明，完成后记住选择，以后打开直接进入大按钮界面。
- 屏幕中间是巨大的圆形按钮：按下开始，再按一次停止。准备播放期间也能按下取消。
- 每次从关闭切换到播放，均从录音开头开始，原生播放器持续循环。停止会释放播放器、回到起点，而不是暂停后继续。
- 播放中保持屏幕常亮，停止后恢复正常息屏；手动锁屏、切后台或音频被通话等占用时仍会停止。
- Android：请求内置扬声器；先静音检查实际路由，再回到播放起点发声。每次按下播放时将媒体音量设为系统允许的最大值一次。播放中用户按音量键调整，不会被程序拉回最大。
- Android：使用媒体音频，不改变来电铃声模式。媒体音量为零时尝试调大；勿扰、系统固定音量、厂商限制或音量保护仍可能阻止发声或最大响度，应用不会绕过这些限制。
- iOS：使用 `AVAudioSession.playAndRecord`、`.defaultToSpeaker`、`.overrideOutputAudioPort(.speaker)`，绕过响铃/静音开关。仅播放，不录音。`AVAudioPlayer.volume = 1.0`，系统音量为零时显示提示。
- 扬声器切换被拒绝时显示错误。播放过程中输出切换到耳机等设备时停止；由于路由变更通知是异步的，不能承诺在所有设备上绝无瞬间切换。
- 返回后台、锁屏或音频被其他应用/通话中断时停止，不自动恢复；重新进入界面后等待用户再次按播放。
- 本版本不会恢复启动前的系统媒体音量；退出后保留用户最后设置。

## 勿扰与固定音量

- 首次设置提供“授予勿扰访问权限”，打开 Android 系统特殊访问授权页面，必须由用户授权；不伪造普通运行时权限弹窗。
- Android 8–14：已授权且勿扰开启时，在开始播放时尝试临时设置为允许打扰。停止或播放失败时，如果用户没有切换到其他勿扰模式，则恢复此前设置。
- Android 15 及以上：本应用针对现代 Android 版本构建，不能关闭全局勿扰。设置页显示当前状态，并提供系统勿扰设置入口，让用户关闭勿扰或允许媒体声音。
- 系统固定音量、耳机音量保护、企业设备策略、厂商限制不能通过普通应用权限解除。使用播放器满幅输出，显示限制状态，并提供声音设置入口。
- 不申请 root、设备管理员或无障碍权限，不锁定音量，也不通过计时器反复修改系统设置。

## 首次设置与权限

- Android 的 `MODIFY_AUDIO_SETTINGS` 是普通安装权限，不会出现运行时授权弹窗。
- Android 12 及以上，可点击“授权查询蓝牙状态（可选）”，实际申请 `BLUETOOTH_CONNECT` 权限，仅用于显示蓝牙是否开启；不扫描设备、不收集设备列表。Android 8–11 使用安装时声明的旧版 `BLUETOOTH` 权限读取状态。
- 拒绝蓝牙查询权限也可以完成设置并使用播放器，播放本身不依赖该权限。无蓝牙硬件时隐藏蓝牙查询入口。
- 提供 Android 系统蓝牙设置入口，用户自行关闭蓝牙。普通应用在新版 Android 上不能直接关闭蓝牙，申请连接权限也不能改变这个限制。
- iOS 显示首次使用说明，无需为本播放器申请蓝牙、麦克风等权限；如需关闭蓝牙，说明中引导用户进入“设置 → 蓝牙”。不使用私有设置链接。
- 首次设置只在点击“完成设置”后保存；拒绝权限、进入系统设置、完成设置都不会触发播放。底部“权限与声音设置”可重新打开说明。

参考：[Android 蓝牙权限](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions)、[Android 13 蓝牙开关限制](https://developer.android.com/about/versions/13/behavior-changes-13#bluetooth-adapter)、[Android 15 勿扰限制](https://developer.android.com/about/versions/15/behavior-changes-15)、[固定音量 API 说明](https://developer.android.com/reference/android/media/AudioManager)、[Apple 蓝牙权限说明](https://support.apple.com/en-us/102267)。

## 开发运行

安装 Flutter 3.41 或更新的 stable 版本、Android SDK 和 JDK 后（本次使用 Flutter 3.47.5 / Dart 3.13.4）：

```sh
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --release --target-platform android-arm64
```

Android 最低 API 26，只打包 arm64-v8a，不包含 32 位 ARM 或 x86。iOS 源码保留，使用 Mac + Xcode 构建，通过 Xcode 设置自己的开发团队与 Bundle ID：

```sh
flutter pub get
flutter build ios --no-codesign
open ios/Runner.xcworkspace
```

发布前替换示例应用标识 `com.example.anthem_player`，并配置自己的签名；不要将默认调试签名用于发布。

## 代码

- `lib/main.dart`：大按钮界面、首次设置对话框与应用生命周期。
- `lib/playback_controller.dart`：手动播放/停止、首次设置、状态同步、取消竞争处理。
- `android/app/src/main/kotlin/com/example/anthem_player/MainActivity.kt`：蓝牙状态权限、系统设置入口及首次设置持久化。
- `android/app/src/main/kotlin/com/example/anthem_player/AnthemAudio.kt`：Android 循环、音量、路由、音频焦点、屏幕常亮和授权后的勿扰处理。
- `ios/Runner/AppDelegate.swift`：iOS 音频实现及 Flutter 通道。
- `test/playback_controller_test.dart`：启动静默、权限拒绝与设置持久化、每次开启的最大音量请求、准备中取消、旧状态回复隔离、后台停止、错误重试。
- `test/player_page_test.dart`：小屏幕大字体下首次设置、拒绝权限、大按钮操作和重新打开。

## 音频来源

2024 年发布的《中华人民共和国国歌》官方录音，管弦乐合唱版。为兼容 Android 的 WAV 解码，原始 48 kHz / 24-bit 双声道 PCM 转为 48 kHz / 16-bit 双声道 PCM；不裁剪、不调速、不放大，时长 49.706875 秒。

发布页面：https://english.www.gov.cn/archive/chinaabc/202409/01/content_WS66d3ced4c6d0868f4e8ea6bb.html

下载文件：https://english.www.gov.cn/AssetsZi/National_Anthem_of_the_People%27s_Republic_of_China%28Orchestra_Chorus_Version%29.zip

## 真机验收

1. 全新安装打开：显示首次设置，全程不播放、不调音量；完成后重开不重复显示首次设置。
2. Android 12+ 授权、拒绝、永久拒绝蓝牙查询，Android 8–11 及无蓝牙设备：设置页面状态准确，拒绝不阻塞播放。
3. 从首次设置进入蓝牙设置并返回：不播放；关闭蓝牙后状态刷新正确。
4. 按大按钮：从头通过扬声器循环播放，Android 尝试调高媒体音量一次；播放中调低不反弹；播放超过两遍仍连续工作。
5. 再按一次：立即停止、回到起点；再次开启：重新请求最大音量、从头播放。准备中再次按下应取消，不能稍后突然发声。
6. 插入有线耳机、连接蓝牙、切换输出设备：确认扬声器路由或明确的失败/停止状态。
7. iPhone 静音开关开启但系统音量非零：按按钮后扬声器播放；系统音量为零时显示提示。
8. 来电、其他音频应用抢占、锁屏/切后台：停止，返回后不自动播放或调音量。
9. 循环交界、快速连续点击、音频加载失败后重试：界面与原生状态一致。
10. Android 8–14 授权勿扰访问后，在勿扰开启时播放并停止，检查旧设置恢复；Android 15+ 检查状态提示和设置入口。
11. 固定音量设备：显示限制，不崩溃、不假报最大音量成功。检查红色启动画面与图标。

系统路由、最大音量与静音行为需要 Android / iPhone 真机验证，Flutter 单元测试不能验证硬件行为。
