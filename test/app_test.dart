import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang_focus/controller.dart';
import 'package:shiguang_focus/main.dart';
import 'package:shiguang_focus/settings_page.dart';
import 'package:shiguang_focus/stats_page.dart';
import 'package:shiguang_focus/tasks.dart';
import 'package:shiguang_focus/ui.dart';
import 'test_gateway.dart';

Future<FocusController> launch(
  WidgetTester tester,
  TestGateway gateway, {
  Size size = const Size(412, 915),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final c = FocusController(gateway);
  await tester.pumpWidget(ShiguangApp(controller: c, startPolling: false));
  await tester.pumpAndSettle();
  addTearDown(c.dispose);
  return c;
}

void main() {
  for (final populated in [false, true]) {
    testWidgets('统计三卡同屏、周期居中：${populated ? "有记录" : "无记录"}', (tester) async {
      tester.view.padding = const FakeViewPadding(top: 32, bottom: 24);
      addTearDown(tester.view.resetPadding);
      final gateway = TestGateway();
      if (populated) {
        final now = DateTime.now();
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).millisecondsSinceEpoch;
        (gateway.data['sessions'] as List).add({
          'id': 'layout-record',
          'taskId': 'math',
          'title': '数学',
          'color': '#087dff',
          'mode': 'down',
          'startAt': start,
          'endAt': start + 1500000,
          'durationMs': 1500000,
          'segments': [
            {'start': start, 'end': start + 1500000},
          ],
        });
      }
      await launch(tester, gateway, size: const Size(360, 800));
      await tester.tap(find.text('统计数据').last);
      await tester.pumpAndSettle();
      final viewport = tester.getRect(
        find.byKey(const PageStorageKey('stats-scroll')),
      );
      for (final key in [
        'statistics-cumulative',
        'statistics-distribution',
        'statistics-heatmap',
      ]) {
        final card = tester.getRect(find.byKey(ValueKey(key)));
        expect(card.top, greaterThanOrEqualTo(viewport.top));
        expect(card.bottom, lessThanOrEqualTo(viewport.bottom));
      }
      final distribution = tester.getRect(
        find.byKey(const ValueKey('statistics-distribution')),
      );
      final periods = tester.getRect(
        find.byKey(const ValueKey('statistics-periods')),
      );
      expect(periods.center.dx, closeTo(distribution.center.dx, .01));
      final donut = tester.getRect(
        find.byKey(const ValueKey('distribution-donut')),
      );
      expect(
        donut.center.dy,
        closeTo((periods.center.dy + distribution.bottom) / 2, .01),
      );
      expect(donut.height, closeTo(104, .01));
      expect(find.byKey(const ValueKey('statistics-overview')), findsNothing);
      final title = tester.getRect(find.text('专注时长分布'));
      final date = tester.getRect(
        find.byKey(const ValueKey('statistics-date')),
      );
      expect(date.left, greaterThan(title.right));
      expect(date.center.dy, closeTo(title.center.dy, 1));
      expect(find.byTooltip('回到当前日期'), findsNothing);
      expect(find.text('可左右滑动查看全年，点击日期查看当天记录。'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('标题右侧日期可翻页、周期切换和选择日期，滚动后记录可见', (tester) async {
    await launch(tester, TestGateway());
    await tester.tap(find.text('统计数据').last);
    await tester.pumpAndSettle();
    final date = find.byKey(const ValueKey('statistics-date'));
    final now = DateTime.now();
    expect(
      find.descendant(
        of: date,
        matching: find.text('${now.year}.${now.month}.${now.day}'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('上一周期'));
    await tester.pumpAndSettle();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    expect(
      find.descendant(
        of: date,
        matching: find.text(
          '${yesterday.year}.${yesterday.month}.${yesterday.day}',
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('下一周期'));
    await tester.pumpAndSettle();
    for (final period in ['周', '月', '年', '日']) {
      await tester.tap(find.text(period).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(
      find.descendant(of: date, matching: find.byType(Text)).first,
    );
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const PageStorageKey('stats-scroll')),
      const Offset(0, -550),
    );
    await tester.pumpAndSettle();
    final records = tester.getRect(find.text('专注记录'));
    final viewport = tester.getRect(
      find.byKey(const PageStorageKey('stats-scroll')),
    );
    expect(records.top, greaterThanOrEqualTo(viewport.top));
    expect(records.bottom, lessThan(viewport.bottom));
    expect(tester.takeException(), isNull);
  });
  testWidgets('三个页面上滑时标题固定、内容仅在标题下滚动', (tester) async {
    await launch(tester, TestGateway(), size: const Size(360, 720));
    for (final page in ['待办', '统计数据', '设置']) {
      await tester.tap(find.text(page).last);
      await tester.pumpAndSettle();
      final title = find.byType(PageHeader);
      final before = tester.getRect(title);
      final view = find.byType(SingleChildScrollView).first;
      final scrollable = find
          .descendant(of: view, matching: find.byType(Scrollable))
          .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      await tester.drag(view, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
      expect(tester.getRect(title), before);
      expect(tester.getRect(view).top, greaterThanOrEqualTo(before.bottom));
      expect(tester.takeException(), isNull);
    }
  });
  for (final size in [
    const Size(320, 640),
    const Size(412, 915),
    const Size(768, 1024),
  ]) {
    testWidgets('三个页面在 ${size.width.toInt()} 宽度没有布局溢出', (tester) async {
      await launch(tester, TestGateway(), size: size);
      expect(find.byType(TodoPage), findsOneWidget);
      expect(
        tester.getSize(find.byType(ClockCard)).height,
        lessThanOrEqualTo(size.height * .32),
      );
      expect(find.byType(SelectableText), findsNothing);
      await tester.tap(find.text('统计数据').last);
      await tester.pumpAndSettle();
      expect(find.text('累计专注'), findsOneWidget);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -1600),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('设置').last);
      await tester.pumpAndSettle();
      expect(find.text('专注偏好'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('切页有过渡，快速切换到最后页面，同页不重复触感', (tester) async {
    final g = TestGateway();
    await launch(tester, g);
    await tester.tap(find.text('统计数据').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final opacity = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .map((w) => w.opacity);
    expect(opacity.any((v) => v > 0 && v < 1), isTrue);
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    final count = g.vibrations.length;
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();
    expect(g.vibrations.length, count);
    expect(find.text('专注偏好'), findsOneWidget);
    await tester.tap(find.text('统计数据').last);
    await tester.pumpAndSettle();
    expect(find.byType(StatsPage), findsOneWidget);
  });
  testWidgets('从界面开始、暂停并结束十秒内专注，确认和结果明确', (tester) async {
    final g = TestGateway();
    final c = await launch(tester, g);
    await tester.tap(find.byTooltip('开始专注').first);
    await tester.pumpAndSettle();
    expect(c.state.active!.running, isTrue);
    await tester.tap(find.byTooltip('暂停专注').first);
    await tester.pumpAndSettle();
    expect(c.state.active!.running, isFalse);
    await tester.tap(find.text('结束并保存').first);
    await tester.pumpAndSettle();
    expect(find.text('结束这次专注？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '结束'));
    await tester.pumpAndSettle();
    expect(c.state.active, isNull);
    expect(find.text('有效专注不超过 10 秒，本次未计入统计'), findsOneWidget);
  });
  testWidgets('新建任务校验空名称和零分钟，合法输入保存到本机', (tester) async {
    final g = TestGateway();
    await launch(tester, g);
    await tester.tap(find.byTooltip('添加学习任务'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('创建任务'));
    await tester.tap(find.text('创建任务'));
    await tester.pumpAndSettle();
    expect(find.text('请输入任务名称'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '英语听力');
    await tester.enterText(find.byType(TextFormField).last, '0');
    await tester.ensureVisible(find.text('创建任务'));
    await tester.tap(find.text('创建任务'));
    await tester.pumpAndSettle();
    expect(find.text('请输入 1–720 分钟'), findsOneWidget);
    expect(g.calls.where((n) => n == 'saveTask'), isEmpty);
    await tester.enterText(find.byType(TextFormField).last, '45');
    await tester.ensureVisible(find.text('创建任务'));
    await tester.tap(find.text('创建任务'));
    await tester.pumpAndSettle();
    expect(g.calls.where((n) => n == 'saveTask').length, 1);
    expect((g.data['tasks'] as List).last['title'], '英语听力');
    expect(find.byType(TaskEditor), findsNothing);
  });
  testWidgets('深色界面和系统减少动画设置均生效', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final g = TestGateway();
    (g.data['settings'] as Map)['theme'] = 'dark';
    await launch(tester, g);
    await tester.tap(find.text('统计数据').last);
    await tester.pump();
    final context = tester.element(find.byType(StatsPage));
    expect(Theme.of(context).brightness, Brightness.dark);
    final opacity = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .map((w) => w.opacity);
    expect(opacity.every((v) => v == 0 || v == 1), isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('有记录时累计专注、饼图和热力图依次显示', (tester) async {
    final g = TestGateway(), now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
      10,
    ).millisecondsSinceEpoch;
    (g.data['sessions'] as List).add({
      'id': 'one',
      'taskId': 'math',
      'title': '数学',
      'color': '#087dff',
      'mode': 'down',
      'startAt': start,
      'endAt': start + 1500000,
      'durationMs': 1500000,
      'segments': [
        {'start': start, 'end': start + 1500000},
      ],
    });
    await launch(tester, g, size: const Size(320, 720));
    await tester.tap(find.text('统计数据').last);
    await tester.pumpAndSettle();
    expect(find.text('专注趋势'), findsNothing);
    expect(
      tester.getTopLeft(find.text('累计专注')).dy,
      lessThan(tester.getTopLeft(find.text('专注时长分布')).dy),
    );
    expect(
      tester.getTopLeft(find.text('专注时长分布')).dy,
      lessThan(tester.getTopLeft(find.text('${now.year} 年专注热力图')).dy),
    );
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -850),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DistributionChart), findsOneWidget);
    expect(find.byType(Heatmap), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
