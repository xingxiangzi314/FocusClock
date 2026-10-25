// Explicit preview of actual Flutter frames; demonstration data never ships.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang_focus/controller.dart';
import 'package:shiguang_focus/main.dart';
import 'package:shiguang_focus/tasks.dart';

import '../test/test_gateway.dart';

void main() {
  testWidgets('Render real start and pause animation frames', (tester) async {
    const output = String.fromEnvironment('PREVIEW_DIR');
    const fontPath = String.fromEnvironment('PREVIEW_FONT');
    const iconPath = String.fromEnvironment('PREVIEW_ICONS');
    if (output.isEmpty) throw StateError('Pass PREVIEW_DIR');
    debugDisableShadows = false;
    await tester.runAsync(() async {
      await Directory(output).create(recursive: true);
      for (final entry in {
        'Roboto': fontPath,
        'MaterialIcons': iconPath,
      }.entries) {
        if (entry.value.isEmpty) continue;
        final bytes = await File(entry.value).readAsBytes();
        await (FontLoader(
          entry.key,
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
    });
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 32, bottom: 24);
    final gateway = TestGateway();
    final controller = FocusController(gateway);
    const boundary = Key('motion-canvas');
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ShiguangApp(controller: controller, startPolling: false),
      ),
    );
    await tester.pumpAndSettle();
    final card = tester.getRect(find.byType(ClockCard));
    await tester.runAsync(
      () => File('$output/crop.json').writeAsString(
        jsonEncode({
          'left': card.left,
          'top': card.top,
          'right': card.right,
          'bottom': card.bottom,
        }),
      ),
    );
    var frame = 0;
    Future<void> capture() async {
      final render = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundary),
      );
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '$output/${(frame++).toString().padLeft(3, '0')}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }

    await capture();
    for (final action in ['start', 'pause']) {
      await controller.command(action);
      await tester.pump();
      await capture();
      for (var index = 0; index < 24; index++) {
        await tester.pump(const Duration(milliseconds: 20));
        await capture();
      }
    }
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPadding();
    debugDisableShadows = true;
  });
}
