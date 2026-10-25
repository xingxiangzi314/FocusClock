// Explicit preview tool, not bundled in the application. All records below are demonstration data.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang_focus/controller.dart';
import 'package:shiguang_focus/main.dart';
import 'package:shiguang_focus/ui.dart';
import '../test/test_gateway.dart';

void main() {
  testWidgets('Render Flutter preview with demonstration records', (
    tester,
  ) async {
    const output = String.fromEnvironment('PREVIEW_DIR');
    const fontPath = String.fromEnvironment('PREVIEW_FONT');
    const iconPath = String.fromEnvironment('PREVIEW_ICONS');
    debugDisableShadows = false;
    if (output.isEmpty)
      throw StateError(
        'Pass PREVIEW_DIR and optionally PREVIEW_FONT with --dart-define.',
      );
    if (fontPath.isNotEmpty) {
      await tester.runAsync(() async {
        final bytes = await File(fontPath).readAsBytes();
        await (FontLoader(
          'Roboto',
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        await (FontLoader(
          'Ahem',
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      });
    }
    if (iconPath.isNotEmpty) {
      await tester.runAsync(() async {
        final bytes = await File(iconPath).readAsBytes();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      });
    }
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 32, bottom: 24);
    final gateway = TestGateway();
    final now = DateTime.now();
    final sessions = gateway.data['sessions'] as List;
    var sequence = 0;
    for (var day = 0; day < 38; day++) {
      if (day % 6 == 4) continue;
      for (var task = 0; task < 2; task++) {
        final start = DateTime(
          now.year,
          now.month,
          now.day - day,
          8 + task * 2,
        ).millisecondsSinceEpoch;
        final duration = (25 + (day * 7 + task * 13) % 50) * 60000;
        sessions.add({
          'id': 'demo-${sequence++}',
          'taskId': task == 0 ? 'math' : 'read',
          'title': task == 0 ? '数学' : '阅读',
          'color': task == 0 ? '#087dff' : '#ed9b45',
          'mode': 'down',
          'startAt': start,
          'endAt': start + duration,
          'durationMs': duration,
          'segments': [
            {'start': start, 'end': start + duration},
          ],
        });
      }
    }
    gateway.data['active'] = {
      'taskId': 'math',
      'title': '数学',
      'color': '#087dff',
      'icon': 'book',
      'mode': 'down',
      'targetMs': 1500000,
      'running': true,
    };
    gateway.data['elapsedMs'] = 487000;
    final controller = FocusController(gateway);
    const boundary = Key('preview-canvas');
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ShiguangApp(controller: controller, startPolling: false),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      final render = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundary),
      );
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '$output/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }

    await capture('todo');
    await tester.tap(find.text('统计数据').last);
    await tester.pumpAndSettle();
    await capture('stats');
    await tester.tap(find.text('周').first);
    await tester.pumpAndSettle();
    await capture('stats-week');
    await tester.tap(find.text('日').first);
    await tester.pumpAndSettle();
    gateway.data['sessions'] = [];
    await controller.reload();
    await tester.pumpAndSettle();
    await capture('stats-empty');
    gateway.data['sessions'] = sessions;
    await controller.reload();
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -270),
    );
    await tester.pumpAndSettle();
    await capture('heatmap');
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();
    await capture('settings');
    await controller.command('setting', {'key': 'theme', 'value': 'dark'});
    await tester.pump();
    await capture('theme-00');
    for (var frame = 1; frame <= 14; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
      await capture('theme-${frame.toString().padLeft(2, '0')}');
    }
    await tester.pumpAndSettle();
    await capture('settings-dark');
    await controller.command('setting', {'key': 'theme', 'value': 'light'});
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('触感强度'));
    await tester.tap(find.text('触感强度'));
    await tester.pumpAndSettle();
    await capture('haptic-strength');
    Navigator.of(tester.element(find.byType(Slider))).pop();
    await tester.pumpAndSettle();
    final header = tester.getRect(find.byType(PageHeader));
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(PageHeader)), header);
    await capture('settings-scroll');
    await controller.command('setting', {'key': 'theme', 'value': 'dark'});
    await tester.pumpAndSettle();
    await tester.tap(find.text('待办').last);
    await tester.pumpAndSettle();
    await capture('dark');
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPadding();
    debugDisableShadows = true;
  });
}
