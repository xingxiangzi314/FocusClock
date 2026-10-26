import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang_focus/controller.dart';
import 'package:shiguang_focus/main.dart';
import 'package:shiguang_focus/statistics.dart';
import 'package:shiguang_focus/stats_page.dart';
import 'test_gateway.dart';

void main() {
  test('热力图五档严格处理1、3、6、8小时边界', () {
    final cases = {
      -1: 0,
      0: 0,
      1: 1,
      3599999: 1,
      3600000: 2,
      10799999: 2,
      10800000: 3,
      21599999: 3,
      21600000: 4,
      28799999: 4,
      28800000: 5,
      86400000: 5,
    };
    for (final entry in cases.entries)
      expect(heatmapLevel(entry.key), entry.value);
    expect(heatmapSamples.map(heatmapLevel).toList(), [0, 1, 2, 3, 4, 5]);
  });
  testWidgets('冷启动和已有页面均能定位小部件点击日期，同一天新请求恢复日统计', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = FocusController(TestGateway());
    await c.initialize(polling: false);
    addTearDown(c.dispose);
    c.openStatisticsDate('2024-02-29');
    await tester.pumpWidget(ShiguangApp(controller: c, startPolling: false));
    await tester.pumpAndSettle();
    expect(find.byType(StatsPage), findsOneWidget);
    expect(find.text('2024.2.29'), findsOneWidget);
    await tester.tap(find.text('周').first);
    await tester.pumpAndSettle();
    c.openStatisticsDate('2024-02-29');
    await tester.pumpAndSettle();
    expect(find.text('2024.2.29'), findsOneWidget);
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();
    c.openStatisticsDate('2025-01-01');
    await tester.pumpAndSettle();
    expect(find.byType(StatsPage), findsOneWidget);
    expect(find.text('2025.1.1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('无效或未来日期不改变导航请求', () async {
    final c = FocusController(TestGateway());
    addTearDown(c.dispose);
    for (final bad in [
      '',
      '2024-02-30',
      '1999-12-31',
      '9999-01-01',
      '2024-01-01?x=1',
    ])
      c.openStatisticsDate(bad);
    expect(c.statisticsDate, isNull);
    expect(c.statisticsRequest, 0);
  });
  testWidgets('安卓握手在首次数据载入前读取小部件日期', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      AndroidGateway.channel,
      (call) async {
        calls.add(call.method);
        if (call.method == 'widgetDate') return '2024-02-29';
        if (call.method == 'command') return jsonEncode(sampleState());
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidGateway.channel,
        null,
      ),
    );
    final c = FocusController(AndroidGateway());
    addTearDown(c.dispose);
    await c.initialize(polling: false);
    expect(calls.take(2), ['widgetDate', 'command']);
    expect(c.statisticsDate, '2024-02-29');
    expect(c.loaded, isTrue);
  });
}
