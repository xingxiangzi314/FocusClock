import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang_focus/controller.dart';
import 'package:shiguang_focus/main.dart';
import 'package:shiguang_focus/settings_page.dart';
import 'package:shiguang_focus/stats_page.dart';
import 'package:shiguang_focus/ui.dart';
import 'test_gateway.dart';

Future<FocusController> mount(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final c = FocusController(TestGateway());
  await tester.pumpWidget(
    ShiguangApp(controller: c, startPolling: false, initialPage: 2),
  );
  await tester.pumpAndSettle();
  addTearDown(c.dispose);
  return c;
}

AppColors palette(WidgetTester tester) =>
    AppColors.of(tester.element(find.byType(SettingsPage)));

void main() {
  testWidgets('卡片与文字连续渐变，中途反向切换从当前颜色继续', (tester) async {
    final c = await mount(tester);
    const light = AppColors(false), dark = AppColors(true);
    expect(palette(tester).card, light.card);
    await c.command('setting', {'key': 'theme', 'value': 'dark'});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final intermediate = palette(tester);
    expect(intermediate.card, isNot(anyOf(light.card, dark.card)));
    expect(intermediate.ink, isNot(anyOf(light.ink, dark.ink)));
    expect(
      tester.widget<Text>(find.text('设置').first).style!.color,
      intermediate.ink,
    );
    await c.command('setting', {'key': 'theme', 'value': 'light'});
    await tester.pump();
    expect(palette(tester).card, intermediate.card);
    await tester.pumpAndSettle();
    expect(palette(tester).card, light.card);
    expect(tester.takeException(), isNull);
  });

  testWidgets('关闭系统动画时主题立即完成', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final c = await mount(tester);
    await c.command('setting', {'key': 'theme', 'value': 'dark'});
    await tester.pump();
    expect(palette(tester).card, const AppColors(true).card);
  });

  testWidgets('跟随系统也使用连续渐变', (tester) async {
    final c = await mount(tester);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await c.command('setting', {'key': 'theme', 'value': 'system'});
    await tester.pumpAndSettle();
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      palette(tester).card,
      isNot(anyOf(const AppColors(false).card, const AppColors(true).card)),
    );
    await tester.pumpAndSettle();
    expect(palette(tester).card, const AppColors(true).card);
  });

  testWidgets('主题面板完全收起后才切换，取消不会改变设置', (tester) async {
    final c = await mount(tester);
    await tester.ensureVisible(find.text('外观主题'));
    await tester.tap(find.text('外观主题'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色'));
    await tester.pump();
    expect(c.state.settings.theme, 'light');
    await tester.pump(const Duration(milliseconds: 60));
    expect(c.state.settings.theme, 'light');
    await tester.pumpAndSettle();
    expect(c.state.settings.theme, 'dark');
    await tester.tap(find.text('外观主题'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(15, 100));
    await tester.pumpAndSettle();
    expect(c.state.settings.theme, 'dark');
  });

  testWidgets('隐藏统计页保留状态且不参与主题逐帧重绘', (tester) async {
    final c = await mount(tester);
    await tester.tap(find.text('统计数据').last);
    await tester.pumpAndSettle();
    final stats = tester.state(find.byType(StatsPage));
    final statsWidget = tester.widget(find.byType(StatsPage));
    final oldTheme = Theme.of(tester.element(find.byType(StatsPage)));
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();
    await c.command('setting', {'key': 'theme', 'value': 'dark'});
    await tester.pumpAndSettle();
    final hidden = find.byType(StatsPage, skipOffstage: false);
    expect(Theme.of(tester.element(hidden)), oldTheme);
    expect(tester.widget(hidden), same(statsWidget));
    expect(tester.state(hidden), same(stats));
    await tester.tap(find.text('统计数据').last);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(StatsPage)), same(stats));
    expect(
      AppColors.of(tester.element(find.byType(StatsPage))).card,
      const AppColors(true).card,
    );
    expect(tester.takeException(), isNull);
  });
}
