import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlaybackController extends ChangeNotifier {
  PlaybackController({MethodChannel? channel, MethodChannel? setupChannel})
    : _channel = channel ?? const MethodChannel('anthem/audio'),
      _setupChannel = setupChannel ?? const MethodChannel('anthem/setup');

  final MethodChannel _channel;
  final MethodChannel _setupChannel;
  Future<void>? _initialization;
  bool _disposed = false;
  int _revision = 0;
  bool _polling = false;
  bool _starting = false;
  bool busy = false;
  bool ready = false;
  bool firstRun = false;
  String state = 'idle';
  String? error;
  String? notice;
  Map<String, dynamic> setup = {};
  double position = 0;
  double duration = 0;
  Timer? _timer;

  bool get active =>
      _starting || const ['playing', 'preparing', 'routing'].contains(state);
  bool get canToggle => ready && (!busy || active);

  Future<void> initializeOnce() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    try {
      await refreshSetup();
      if (_disposed) return;
      ready = true;
      // Reading settings must never prepare audio or change volume.
      _timer = Timer.periodic(
        const Duration(milliseconds: 300),
        (_) => refresh(),
      );
    } on PlatformException catch (e) {
      error = e.message ?? '无法读取首次设置';
    } on MissingPluginException {
      error = '请在 Android 或 iPhone 上运行此应用';
    }
    _notify();
  }

  Future<void> refreshSetup() async {
    final value = await _setupChannel.invokeMapMethod<String, dynamic>('read');
    if (_disposed) return;
    setup = value ?? {};
    firstRun = setup['firstRun'] == true;
    _notify();
  }

  Future<void> requestBluetoothPermission() async {
    final value = await _setupChannel.invokeMapMethod<String, dynamic>(
      'requestBluetooth',
    );
    if (_disposed) return;
    setup = value ?? setup;
    _notify();
  }

  Future<void> completeSetup() async {
    await _setupChannel.invokeMethod<void>('complete');
    if (_disposed) return;
    firstRun = false;
    _notify();
  }

  Future<void> openBluetoothSettings() =>
      _setupChannel.invokeMethod<void>('openBluetoothSettings');

  Future<void> openDndAccess() =>
      _setupChannel.invokeMethod<void>('openDndAccess');
  Future<void> openDndSettings() =>
      _setupChannel.invokeMethod<void>('openDndSettings');
  Future<void> openSoundSettings() =>
      _setupChannel.invokeMethod<void>('openSoundSettings');

  Future<void> toggle() async {
    if (!canToggle || firstRun) return;
    if (active) {
      await stop();
      return;
    }
    final ticket = ++_revision;
    _starting = true;
    busy = true;
    state = 'preparing';
    error = null;
    notice = null;
    _notify();
    try {
      // Each explicit OFF -> ON transition requests maximum volume once.
      await _channel.invokeMethod<void>('play', {
        'maximize': true,
        'restart': true,
      });
      if (ticket != _revision || _disposed) return;
      _starting = false;
      state = 'playing';
    } on PlatformException catch (e) {
      if (ticket != _revision || _disposed) return;
      state = e.code == 'CANCELLED' ? 'stopped' : 'error';
      error = e.code == 'CANCELLED' ? null : e.message ?? '播放失败，请重试';
    } on MissingPluginException {
      if (ticket != _revision || _disposed) return;
      state = 'error';
      error = '当前平台不支持播放';
    } finally {
      if (ticket == _revision && !_disposed) {
        _starting = false;
        busy = false;
        _notify();
        await refresh();
      }
    }
  }

  Future<void> stop() async {
    if (_disposed) return;
    final ticket = ++_revision;
    _starting = false;
    busy = true;
    state = 'stopping';
    _notify();
    try {
      await _channel.invokeMethod<void>('stop');
      if (ticket != _revision || _disposed) return;
      state = 'stopped';
      position = 0;
      error = null;
      notice = null;
    } on PlatformException catch (e) {
      if (ticket != _revision || _disposed) return;
      state = 'error';
      error = e.message ?? '停止失败，请重试';
    } on MissingPluginException {
      if (ticket == _revision) state = 'stopped';
    } finally {
      if (ticket == _revision && !_disposed) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> stopForBackground() async {
    if (active) await stop();
  }

  Future<void> refresh() async {
    if (_disposed || _polling || busy) return;
    _polling = true;
    final ticket = _revision;
    try {
      final value = await _channel.invokeMapMethod<String, dynamic>('status');
      if (_disposed || ticket != _revision || value == null) return;
      state = value['state'] as String? ?? state;
      position = (value['position'] as num?)?.toDouble() ?? 0;
      duration = (value['duration'] as num?)?.toDouble() ?? 0;
      notice = value['notice'] as String?;
      if (value['error'] != null) error = value['error'] as String;
      _notify();
    } on PlatformException catch (e) {
      if (ticket == _revision && !_disposed) {
        error = e.message;
        _notify();
      }
    } on MissingPluginException {
      // Initialization describes unsupported platforms.
    } finally {
      _polling = false;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
