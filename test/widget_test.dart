import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yosakoi_countdown/main.dart';

void main() {
  testWidgets('SABERA接続後にページを開いて残り時間を送信する', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const methods = MethodChannel('jp.jig.glasses.sdk/glasses');
    const events = MethodChannel('jp.jig.glasses.sdk/connectionState');
    final messenger = tester.binding.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(events, (call) async {
      if (call.method == 'listen') {
        scheduleMicrotask(() {
          messenger.handlePlatformMessage(
            events.name,
            const StandardMethodCodec().encodeSuccessEnvelope({
              'connected': true,
              'deviceName': 'SABERA',
            }),
            (_) {},
          );
        });
      }
      return null;
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(methods, null);
      messenger.setMockMethodCallHandler(events, null);
    });
    final future = DateTime.now().add(const Duration(minutes: 20));
    SharedPreferences.setMockInitialValues({
      'gathering': '${future.toIso8601String()}\n鳴子連\n中央公園',
    });
    await tester.pumpWidget(const YosakoiApp());
    await tester.pumpAndSettle();
    expect(find.text('SABERA 接続中'), findsOneWidget);
    expect(calls.map((call) => call.method), [
      'enterTeleprompterPage',
      'sendTeleprompterContent',
    ]);
    expect(calls.last.arguments['content'], contains('あと20分'));
    await tester.pump(const Duration(seconds: 1));
    expect(calls.length, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets('保存された予定から起動してカウントダウンする', (tester) async {
    final future = DateTime.now().add(const Duration(minutes: 30));
    SharedPreferences.setMockInitialValues({
      'gathering': '${future.toIso8601String()}\n鳴子連\n中央公園',
    });
    await tester.pumpWidget(const YosakoiApp());
    await tester.pumpAndSettle();
    expect(find.text('30'), findsOneWidget);
    expect(find.text('中央公園'), findsNWidgets(2));
    expect(find.text('よさこい集合時計'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('集合時刻が未設定の場合と過去の入力を扱う', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const YosakoiApp());
    await tester.pumpAndSettle();
    expect(find.text('集合時刻を設定しましょう'), findsOneWidget);
    final button = find.text('この予定でカウントダウン');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('これからの集合日・時刻を選んでください。'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
