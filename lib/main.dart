import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'playback_controller.dart';

const scarlet = Color(0xFFE60019);
const deepRed = Color(0xFF99000D);
const gold = Color(0xFFFFDF83);
const appName = '伟大先烈保护我';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: deepRed,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const AnthemApp());
}

class AnthemApp extends StatelessWidget {
  const AnthemApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: appName,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: scarlet,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        onPrimary: deepRed,
        secondary: gold,
        surface: Color(0xFFAE0010),
        onSurface: Color(0xFFFFEDBB),
        error: Color(0xFFFFEB83),
        onError: deepRed,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFFB50013),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: gold),
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: gold),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: deepRed,
        ),
      ),
      useMaterial3: true,
    ),
    home: const PlayerPage(),
  );
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  final player = PlaybackController();
  bool _showingSetup = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await player.initializeOnce();
      if (mounted && player.firstRun) await showSetup();
    });
  }

  Future<void> showSetup() async {
    if (_showingSetup || !player.ready) return;
    _showingSetup = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SetupDialog(player: player),
      );
    } finally {
      _showingSetup = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      player.stopForBackground();
    } else if (state == AppLifecycleState.resumed && player.ready) {
      player.refreshSetup().catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFF20B21),
                  Color(0xFFD90015),
                  Color(0xFFA0000C),
                ],
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: RedRadiancePainter()),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final diameter = math.min(
                330.0,
                math.max(180.0, constraints.maxWidth - 56),
              );
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(0, constraints.maxHeight - 44),
                  ),
                  child: ListenableBuilder(
                    listenable: player,
                    builder: (context, _) {
                      final active = player.active;
                      final label = switch (player.state) {
                        'playing' => '循环播放中 · 再按一次停止',
                        'preparing' || 'routing' => '正在开启 · 再按一次取消',
                        'stopping' => '正在关闭…',
                        'error' => '暂时无法播放 · 可重试',
                        _ => '准备就绪 · 按下开启',
                      };
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Row(
                            children: [
                              Expanded(
                                child: Divider(color: gold, thickness: 1),
                              ),
                              Expanded(
                                flex: 8,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '红 色 精 神  ·  随 身 守 护',
                                      style: TextStyle(
                                        color: gold,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(color: gold, thickness: 1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Icon(Icons.star_rounded, size: 42, color: gold),
                          const SizedBox(height: 8),
                          const Text(
                            appName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: gold,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              height: 1.3,
                              letterSpacing: 1.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: deepRed.withValues(alpha: 0.65),
                              border: Border.all(
                                color: gold.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Text(
                              '传承红色精神   凝聚奋进力量',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: gold,
                                fontSize: 12,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: gold.withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                            child: SizedBox(
                              width: diameter - 18,
                              height: diameter - 18,
                              child: FilledButton(
                                key: const Key('power-button'),
                                onPressed: player.canToggle && !player.firstRun
                                    ? player.toggle
                                    : null,
                                style: FilledButton.styleFrom(
                                  shape: const CircleBorder(
                                    side: BorderSide(color: gold, width: 3),
                                  ),
                                  padding: const EdgeInsets.all(25),
                                  elevation: 14,
                                  shadowColor: const Color(0xFF650007),
                                  backgroundColor: active
                                      ? const Color(0xFFB80013)
                                      : const Color(0xFFFA142A),
                                  foregroundColor: gold,
                                  disabledBackgroundColor: deepRed,
                                  disabledForegroundColor: gold.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        active
                                            ? Icons.stop_rounded
                                            : Icons.power_settings_new_rounded,
                                        size: 86,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        active ? '关闭守护' : '开启守护',
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        active ? '再次按下 · 停止播放' : '按下即播 · 持续循环',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            player.ready ? label : '正在读取设置…',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: gold,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FeatureBadge(
                                icon: Icons.volume_up_rounded,
                                label: '手机扬声器',
                              ),
                              FeatureBadge(
                                icon: Icons.repeat_rounded,
                                label: '循环播放',
                              ),
                              FeatureBadge(
                                icon: Icons.offline_bolt_rounded,
                                label: '离线可用',
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            '《义勇军进行曲》· 管弦乐合唱版\n开启时调高音量，播放中可用音量键调整',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFFFD8A0),
                              fontSize: 11,
                              height: 1.8,
                            ),
                          ),
                          if (player.notice != null)
                            StatusMessage(text: player.notice!),
                          if (player.error != null)
                            StatusMessage(text: player.error!),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: player.ready && !active && !player.busy
                                ? showSetup
                                : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: gold,
                              side: BorderSide(
                                color: gold.withValues(alpha: 0.5),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            icon: const Icon(Icons.tune_rounded, size: 18),
                            label: const Text('权限与声音设置'),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            '★  信 念 长 存   精 神 不 灭  ★',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: gold,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '个人作品 · 红色主题播放器',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFFFBCA0),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class FeatureBadge extends StatelessWidget {
  const FeatureBadge({super.key, required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: deepRed.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: gold.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: gold),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: gold, fontSize: 11)),
      ],
    ),
  );
}

class StatusMessage extends StatelessWidget {
  const StatusMessage({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: deepRed,
      border: Border.all(color: gold.withValues(alpha: 0.6)),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: gold, fontSize: 12),
    ),
  );
}

class RedRadiancePainter extends CustomPainter {
  const RedRadiancePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.40);
    final radius = size.longestSide * 1.6;
    final paint = Paint()..color = gold.withValues(alpha: 0.045);
    for (var i = 0; i < 28; i++) {
      final angle = i * math.pi * 2 / 28;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius,
        )
        ..lineTo(
          center.dx + math.cos(angle + 0.075) * radius,
          center.dy + math.sin(angle + 0.075) * radius,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
    final dotPaint = Paint()..color = gold.withValues(alpha: 0.06);
    for (double x = 12; x < size.width; x += 24) {
      for (double y = 12; y < size.height; y += 24) {
        canvas.drawCircle(Offset(x, y), 0.7, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant RedRadiancePainter oldDelegate) => false;
}

class SetupDialog extends StatefulWidget {
  const SetupDialog({super.key, required this.player});
  final PlaybackController player;
  @override
  State<SetupDialog> createState() => _SetupDialogState();
}

class _SetupDialogState extends State<SetupDialog> {
  bool busy = false;
  String? error;
  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } on PlatformException catch (e) {
      if (mounted) setState(() => error = e.message ?? '设置失败，请重试');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: ListenableBuilder(
      listenable: widget.player,
      builder: (context, _) {
        final setup = widget.player.setup;
        final android = setup['platform'] == 'android';
        final permission = setup['bluetoothPermission'];
        final bluetooth = setup['bluetoothEnabled'];
        final bluetoothLabel = switch (permission) {
          'denied' => '已拒绝查询蓝牙状态，仍可尝试扬声器播放。',
          'blocked' => '蓝牙查询权限未获准，可在系统应用权限设置中修改。',
          'granted' || 'notRequired' =>
            bluetooth == true
                ? '蓝牙当前已开启。'
                : bluetooth == false
                ? '蓝牙当前已关闭。'
                : '暂时无法读取蓝牙状态。',
          _ => '可选择授权查询蓝牙是否开启。',
        };
        return AlertDialog(
          title: Text(widget.player.firstRun ? '首次使用设置' : '权限与声音设置'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('打开应用不会播放。按下大按钮开始循环，再按一次停止。'),
                const SizedBox(height: 16),
                Text(
                  android
                      ? '每次开启会尝试解除媒体静音并调至最大音量，播放中仍可自行调低。'
                      : '扬声器播放会绕过静音开关，实际音量仍由 iPhone 系统音量控制。',
                ),
                if (android) ...[
                  const SizedBox(height: 20),
                  const Text(
                    '勿扰与声音',
                    style: TextStyle(fontWeight: FontWeight.bold, color: gold),
                  ),
                  const SizedBox(height: 8),
                  Text(setup['dndAccess'] == true ? '勿扰访问：已授权' : '勿扰访问：未授权'),
                  Text(setup['dndActive'] == true ? '勿扰模式：已开启' : '勿扰模式：未开启'),
                  Text(
                    setup['canTemporarilyDisableDnd'] == true
                        ? '授权后，播放时尝试临时解除勿扰，停止时恢复此前设置。'
                        : '本 Android 版本不能由应用关闭全局勿扰。请在系统设置中允许媒体声音或关闭勿扰。',
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => run(widget.player.openDndAccess),
                    child: const Text('授予勿扰访问权限'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => run(widget.player.openDndSettings),
                    child: const Text('打开系统勿扰设置'),
                  ),
                  if (setup['fixedVolume'] == true)
                    const Text('此设备使用系统固定音量，应用权限无法解除。可检查系统声音或外接设备设置。'),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => run(widget.player.openSoundSettings),
                    child: const Text('打开系统声音设置'),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  android
                      ? '如需关闭蓝牙，请进入系统蓝牙设置。'
                      : '如需关闭蓝牙，请到 iPhone「设置 → 蓝牙」手动关闭。',
                ),
                if (android && setup['bluetoothSupported'] == true) ...[
                  const SizedBox(height: 10),
                  Text(bluetoothLabel),
                  if (permission == 'notRequested' || permission == 'denied')
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => run(widget.player.requestBluetoothPermission),
                      child: const Text('授权查询蓝牙状态（可选）'),
                    ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => run(widget.player.openBluetoothSettings),
                    child: const Text('打开系统蓝牙设置'),
                  ),
                ],
                if (error != null)
                  Text(error!, style: const TextStyle(color: gold)),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: busy
                  ? null
                  : () => run(() async {
                      await widget.player.completeSetup();
                      if (context.mounted) Navigator.of(context).pop();
                    }),
              child: const Text('完成设置'),
            ),
          ],
        );
      },
    ),
  );
}
