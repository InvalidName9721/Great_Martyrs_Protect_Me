import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anthem_player/playback_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const audio = MethodChannel('anthem/audio');
  const setup = MethodChannel('anthem/setup');
  final calls = <String>[];
  final playArguments = <dynamic>[];
  var nativeState = 'idle';
  var firstRun = false;
  var rejectPlay = false;
  Completer<void>? delayedPlay;
  Completer<Map<String, dynamic>>? delayedStatus;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    calls.clear();
    playArguments.clear();
    nativeState = 'idle';
    firstRun = false;
    rejectPlay = false;
    delayedPlay = null;
    delayedStatus = null;
    messenger.setMockMethodCallHandler(setup, (call) async {
      calls.add('setup:${call.method}');
      if (call.method == 'complete') {
        firstRun = false;
        return null;
      }
      return {
        'platform': 'android',
        'firstRun': firstRun,
        'bluetoothSupported': true,
        'bluetoothPermission': call.method == 'requestBluetooth'
            ? 'denied'
            : 'notRequested',
      };
    });
    messenger.setMockMethodCallHandler(audio, (call) async {
      calls.add(call.method);
      if (call.method == 'play') {
        playArguments.add(call.arguments);
        if (rejectPlay) {
          nativeState = 'error';
          throw PlatformException(code: 'AUDIO', message: '无法切换扬声器');
        }
        if (delayedPlay != null) await delayedPlay!.future;
        nativeState = 'playing';
      }
      if (call.method == 'stop') {
        nativeState = 'stopped';
        if (delayedPlay != null && !delayedPlay!.isCompleted) {
          delayedPlay!.completeError(PlatformException(code: 'CANCELLED'));
        }
      }
      if (call.method == 'status') {
        if (delayedStatus != null) return delayedStatus!.future;
        return {
          'state': nativeState,
          'position': nativeState == 'playing' ? 2.0 : 0.0,
          'duration': 49.7,
        };
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(audio, null);
    messenger.setMockMethodCallHandler(setup, null);
  });
  PlaybackController makePlayer() {
    final player = PlaybackController(channel: audio, setupChannel: setup);
    addTearDown(player.dispose);
    return player;
  }

  test(
    'launch reads settings once without preparing audio or changing volume',
    () async {
      final player = makePlayer();
      await Future.wait([player.initializeOnce(), player.initializeOnce()]);
      await player.initializeOnce();
      expect(calls, ['setup:read']);
      expect(player.active, false);
      expect(player.ready, true);
    },
  );

  test(
    'first-run permission denial and completion never trigger playback',
    () async {
      firstRun = true;
      final player = makePlayer();
      await player.initializeOnce();
      await player.toggle();
      expect(playArguments, isEmpty);
      await player.requestBluetoothPermission();
      expect(player.setup['bluetoothPermission'], 'denied');
      await player.completeSetup();
      expect(playArguments, isEmpty);
      await player.toggle();
      expect(player.active, true);
    },
  );

  test('DND and sound settings do not trigger playback', () async {
    final player = makePlayer();
    await player.initializeOnce();
    await player.openDndAccess();
    await player.openDndSettings();
    await player.openSoundSettings();
    expect(
      calls,
      containsAllInOrder([
        'setup:openDndAccess',
        'setup:openDndSettings',
        'setup:openSoundSettings',
      ]),
    );
    expect(playArguments, isEmpty);
  });

  test('completed setup is remembered when opening a new controller', () async {
    firstRun = true;
    final player = makePlayer();
    await player.initializeOnce();
    await player.completeSetup();
    final reopened = makePlayer();
    await reopened.initializeOnce();
    expect(reopened.firstRun, false);
    expect(playArguments, isEmpty);
  });

  test(
    'button starts at maximum, stops at zero, then starts from the beginning',
    () async {
      final player = makePlayer();
      await player.initializeOnce();
      await player.toggle();
      expect(player.active, true);
      await player.refresh();
      expect(playArguments, hasLength(1)); // Polling never reasserts volume.
      await player.toggle();
      expect(player.state, 'stopped');
      expect(player.position, 0);
      await player.toggle();
      expect(playArguments, [
        {'maximize': true, 'restart': true},
        {'maximize': true, 'restart': true},
      ]);
    },
  );

  test(
    'second press cancels pending preparation without leaving a busy button',
    () async {
      delayedPlay = Completer<void>();
      final player = makePlayer();
      await player.initializeOnce();
      final starting = player.toggle();
      await Future<void>.delayed(Duration.zero);
      expect(player.active, true);
      expect(player.canToggle, true);
      await player.toggle();
      await starting;
      expect(player.state, 'stopped');
      expect(player.active, false);
      expect(player.busy, false);
      expect(player.error, isNull);
    },
  );

  test('old status response cannot undo a later stop', () async {
    final player = makePlayer();
    await player.initializeOnce();
    await player.toggle();
    delayedStatus = Completer<Map<String, dynamic>>();
    final poll = player.refresh();
    await Future<void>.delayed(Duration.zero);
    await player.stop();
    delayedStatus!.complete({'state': 'playing', 'position': 10.0});
    await poll;
    expect(player.state, 'stopped');
    expect(player.active, false);
  });

  test('background stops and reopening never restarts', () async {
    final player = makePlayer();
    await player.initializeOnce();
    await player.toggle();
    await player.stopForBackground();
    await player.initializeOnce();
    expect(player.state, 'stopped');
    expect(playArguments, hasLength(1));
  });

  test('route failure is visible and user can retry at maximum', () async {
    rejectPlay = true;
    final player = makePlayer();
    await player.initializeOnce();
    await player.toggle();
    expect(player.error, '无法切换扬声器');
    expect(player.busy, false);
    rejectPlay = false;
    await player.toggle();
    expect(player.state, 'playing');
    expect(player.error, isNull);
    expect(playArguments.last, {'maximize': true, 'restart': true});
  });
}
