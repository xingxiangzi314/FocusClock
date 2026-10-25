import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang_focus/controller.dart';
import 'package:shiguang_focus/focus_toggle.dart';
import 'package:shiguang_focus/main.dart';
import 'package:shiguang_focus/tasks.dart';

import 'test_gateway.dart';

double shapeProgress(WidgetTester tester) => tester
    .widgetList<Material>(find.byType(Material))
    .map((widget) => widget.shape)
    .whereType<FocusToggleShape>()
    .single
    .progress;

FocusPetalPainter backdrop(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((widget) => widget.painter)
    .whereType<FocusPetalPainter>()
    .single;

void main() {
  Future<void> show(
    WidgetTester tester, {
    required bool running,
    bool reduced = false,
    VoidCallback? onTap,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Center(
          child: FocusPetalStage(
            running: running,
            child: FocusToggleButton(
              running: running,
              label: running ? '暂停专注' : '开始专注',
              onTap: onTap,
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('初始状态正确，静止后不持续运行动画', (tester) async {
    await show(tester, running: true);
    expect(shapeProgress(tester), 1);
    expect(tester.getSize(find.byType(FocusToggleButton)), const Size(58, 58));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await show(tester, running: false);
    await tester.pumpAndSettle();
    expect(shapeProgress(tester), 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('启停连续变形，快速反向从当前进度衔接，尺寸不变', (tester) async {
    await show(tester, running: false);
    final before = tester.getRect(find.byType(FocusToggleButton));
    await show(tester, running: true);
    await tester.pump(const Duration(milliseconds: 100));
    final middle = shapeProgress(tester);
    expect(middle, greaterThan(0));
    expect(middle, lessThan(1));
    await show(tester, running: false);
    expect(shapeProgress(tester), middle);
    await tester.pump(const Duration(milliseconds: 80));
    expect(shapeProgress(tester), lessThan(middle));
    await show(tester, running: true);
    await tester.pumpAndSettle();
    expect(shapeProgress(tester), 1);
    expect(tester.getRect(find.byType(FocusToggleButton)), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('减少动态效果时直接同步状态，也可中途关闭动画', (tester) async {
    await show(tester, running: false);
    await show(tester, running: true);
    await tester.pump(const Duration(milliseconds: 90));
    await show(tester, running: true, reduced: true);
    expect(shapeProgress(tester), 1);
    expect(backdrop(tester).progress, 1);
    await show(tester, running: false, reduced: true);
    expect(shapeProgress(tester), 0);
    expect(backdrop(tester).progress, 0);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('灰色花瓣与按钮同步且反向旋转，中途反向保持衔接', (tester) async {
    await show(tester, running: false);
    await show(tester, running: true);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      final shape = tester
          .widgetList<Material>(find.byType(Material))
          .map((widget) => widget.shape)
          .whereType<FocusToggleShape>()
          .single;
      final gray = backdrop(tester);
      expect(gray.progress, closeTo(shape.progress, .000001));
      expect(gray.rotation, lessThan(0));
      expect(shape.rotation, greaterThan(0));
      expect(gray.rotation + shape.rotation, closeTo(0, .000001));
    }
    final middle = backdrop(tester).progress;
    await show(tester, running: false);
    expect(backdrop(tester).progress, closeTo(middle, .000001));
    await tester.pump(const Duration(milliseconds: 80));
    expect(backdrop(tester).progress, closeTo(shapeProgress(tester), .000001));
    await tester.pumpAndSettle();
    expect(backdrop(tester).progress, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('点击只提交操作，确认状态前不自行变形，禁用时不可点击', (tester) async {
    var calls = 0;
    await show(tester, running: false, onTap: () => calls++);
    await tester.tap(find.byType(FocusToggleButton));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(shapeProgress(tester), 0);
    await show(tester, running: false);
    await tester.tap(find.byType(FocusToggleButton));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('时钟卡片与沉浸页同步，失败不误显示运行，外部结束恢复圆形', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = TestGateway();
    final controller = FocusController(gateway);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ShiguangApp(controller: controller, startPolling: false),
    );
    await tester.pumpAndSettle();
    gateway.fail = true;
    await tester.tap(find.byType(FocusToggleButton));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FocusToggleButton>(find.byType(FocusToggleButton)).running,
      isFalse,
    );
    expect(shapeProgress(tester), 0);
    gateway.fail = false;
    await tester.tap(find.byType(FocusToggleButton));
    await tester.pumpAndSettle();
    expect(shapeProgress(tester), 1);
    await tester.pumpWidget(
      MaterialApp(home: FocusScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<FocusToggleButton>(find.byType(FocusToggleButton)).size,
      86,
    );
    expect(shapeProgress(tester), 1);
    await tester.tap(find.byType(FocusToggleButton));
    await tester.pumpAndSettle();
    expect(shapeProgress(tester), 0);
    await controller.command('start');
    await tester.pumpAndSettle();
    expect(shapeProgress(tester), 1);
    await controller.command('finish');
    await tester.pumpAndSettle();
    expect(shapeProgress(tester), 0);
    expect(gateway.calls.where((name) => name == 'pause').length, 1);
    expect(tester.takeException(), isNull);
  });
}
