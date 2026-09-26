import 'package:anthem_player/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'first-run setup, denied permission, big button and reopen stay silent until tapped',
    (tester) async {
      const audio = MethodChannel('anthem/audio');
      const setup = MethodChannel('anthem/setup');
      var state = 'idle';
      var starts = 0;
      var complete = false;
      var permission = 'notRequested';
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(setup, (call) async {
        if (call.method == 'complete') {
          complete = true;
          return null;
        }
        if (call.method == 'requestBluetooth') permission = 'denied';
        return {
          'platform': 'android',
          'firstRun': !complete,
          'bluetoothSupported': true,
          'bluetoothPermission': permission,
        };
      });
      messenger.setMockMethodCallHandler(audio, (call) async {
        if (call.method == 'play') {
          state = 'playing';
          starts++;
        }
        if (call.method == 'stop') state = 'stopped';
        if (call.method == 'status') {
          return {'state': state, 'position': 0.0, 'duration': 49.7};
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(audio, null);
        messenger.setMockMethodCallHandler(setup, null);
      });
      await tester.pumpWidget(const AnthemApp());
      await tester.pumpAndSettle();
      expect(starts, 0);
      expect(find.text('首次使用设置'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('授权查询蓝牙状态（可选）'));
      await tester.tap(find.text('授权查询蓝牙状态（可选）'));
      await tester.pumpAndSettle();
      expect(find.text('已拒绝查询蓝牙状态，仍可尝试扬声器播放。'), findsOneWidget);
      await tester.tap(find.text('完成设置'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(starts, 0);
      final button = find.byKey(const Key('power-button'));
      await tester.ensureVisible(button);
      expect(tester.getSize(button).width, greaterThanOrEqualTo(280));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(starts, 1);
      expect(find.text('关闭守护'), findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(state, 'stopped');
      expect(find.text('开启守护'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const AnthemApp());
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(starts, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
