# 验证记录

日期：2026-09-26。版本：1.2.0+3「伟大先烈保护我」。

环境：Windows，Flutter 3.47.5 stable，Dart 3.13.4，JDK 21，Android SDK 36，NDK 28.2.13676358。

## 已验证

- Dart 静态分析：通过，无问题。
- Flutter 测试：10 项全部通过。覆盖打开不播放、首次设置与拒绝权限、设置保存、勿扰设置入口不触发播放、每次开启的最大音量请求、准备期间取消、旧回复隔离、后台停止、错误重试，以及 360 × 640 / 1.8 倍字体布局。
- 实际 Flutter 界面代码生成红金主屏预览，已人工检查；使用模拟原生通道，非手机真机截图。
- Android Kotlin / Java 原生代码编译成功；ARM64 release APK 构建成功。
- APK 元数据：应用名「伟大先烈保护我」，包名 com.example.anthem_player，versionName 1.2.0，versionCode 3，最低 API 26，目标 API 36。
- APK 原生库仅 lib/arm64-v8a/libapp.so 与 lib/arm64-v8a/libflutter.so，无 32 位或 x86 库。
- APK 签名验证通过：v2，RSA 2048，本地 Android Debug 测试证书。构建模式为 release；测试证书不等于启用调试。
- zipalign -c -P 16 4 验证通过。
- 包内录音存在，PCM 16-bit / 48 kHz / 双声道，49.706875 秒，9,543,764 字节。
- release APK 未声明 Internet 或麦克风权限。
- APK 大小：25,186,511 字节。

APK SHA-256：

F9C1386D43BB92081E45AEFC9C2989A36A81E306CC59E25353B5A049CFA6895F

## 仍需真机验证

- Android 扬声器路由、耳机/蓝牙连接切换、实际音量与长时间循环。
- Android 蓝牙权限弹窗、授权拒绝、勿扰权限、系统设置往返、厂商固定音量策略。
- Android 8–14 授权后的勿扰临时调整与恢复；Android 15+ 的状态提示和手动设置入口。
- 真机安装与运行；本次完成构建及离线包检查，未连接手机或运行 Android 模拟器。
- iOS Swift 代码未编译；Windows 无 Xcode。iPhone 静音开关、扬声器、音频中断仍待 Mac 构建后测试。

普通权限无法解除所有勿扰、固定音量或厂商限制。Flutter 通道测试不能证明硬件音频行为；本包使用测试签名，正式发布前需更换应用标识和生产签名。
