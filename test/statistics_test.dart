import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang_focus/models.dart';
import 'package:shiguang_focus/statistics.dart';

FocusSession record(
  String id,
  List<TimeSegment> segments, {
  String task = 'deleted',
}) => FocusSession(
  id: id,
  taskId: task,
  title: '旧任务',
  color: '#087dff',
  mode: 'up',
  startAt: segments.first.start,
  endAt: segments.last.end,
  durationMs: segments.fold(0, (n, p) => n + p.end - p.start),
  segments: segments,
);
int at(int day, int hour, [int minute = 0]) =>
    beijingEpoch(beijingCalendar(2026, 10, day, hour, minute));

void main() {
  test('北京时间在UTC16点跨日跨月，日区间固定24小时', () {
    final before = DateTime.parse(
      '2026-10-31T15:59:59Z',
    ).millisecondsSinceEpoch;
    final midnight = DateTime.parse(
      '2026-10-31T16:00:00Z',
    ).millisecondsSinceEpoch;
    expect(dayKey(beijingTime(before)), '2026-10-31');
    expect(dayKey(beijingTime(midnight)), '2026-11-01');
    expect(timeText(before), '23:59');
    expect(timeText(midnight), '00:00');
    final range = PeriodRange.of(FocusPeriod.day, beijingCalendar(2026, 11, 1));
    expect(beijingEpoch(range.start), midnight);
    expect(beijingEpoch(range.end) - beijingEpoch(range.start), 86400000);
  });
  test('统计、分布和小时趋势统一按北京时间切分实际时间戳', () {
    final start = DateTime.parse('2026-10-31T15:30:00Z').millisecondsSinceEpoch;
    final end = DateTime.parse('2026-10-31T16:30:00Z').millisecondsSinceEpoch;
    final stats = FocusStatistics([
      record('bj', [TimeSegment(start, end)]),
    ], now: beijingCalendar(2026, 11, 1));
    expect(stats.days, {'2026-10-31': 1800000, '2026-11-01': 1800000});
    final range = PeriodRange.of(FocusPeriod.day, beijingCalendar(2026, 11, 1));
    expect(stats.inRange(range), 1800000);
    expect(stats.distribution(range).single.duration, 1800000);
    expect(stats.trend(FocusPeriod.day, range).first.duration, 1800000);
    expect(stats.today, 1800000);
    expect(beijingParseDate('2026-11-01'), beijingCalendar(2026, 11, 1));
  });
  test('跨午夜按有效片段分摊，暂停不计入任何日期或趋势', () {
    final r = record('one', [
      TimeSegment(at(23, 23, 50), at(24, 0, 10)),
      TimeSegment(at(24, 1), at(24, 1, 30)),
    ]);
    final s = FocusStatistics([r], now: beijingCalendar(2026, 10, 24));
    expect(s.total, 50 * 60000);
    expect(s.days, {'2026-10-23': 10 * 60000, '2026-10-24': 40 * 60000});
    final range = PeriodRange.of(
      FocusPeriod.day,
      beijingCalendar(2026, 10, 24),
    );
    expect(s.inRange(range), 40 * 60000);
    final hours = s.trend(FocusPeriod.day, range);
    expect(hours[0].duration, 10 * 60000);
    expect(hours[1].duration, 30 * 60000);
    expect(hours.fold<int>(0, (n, p) => n + p.duration), s.inRange(range));
  });
  test('日均包含没有学习的日期，昨天仍计入连续天数', () {
    final s = FocusStatistics([
      record('1', [TimeSegment(at(20, 8), at(20, 9))]),
      record('2', [TimeSegment(at(22, 8), at(22, 9))]),
      record('3', [TimeSegment(at(23, 8), at(23, 9))]),
    ], now: beijingCalendar(2026, 10, 24));
    expect(s.dailyAverage, 180 * 60000 ~/ 5);
    expect(s.streak, 2);
    expect(s.today, 0);
  });
  test('已删除任务仍在饼图内，区间边界不重复统计', () {
    final s = FocusStatistics([
      record('1', [TimeSegment(at(23, 23), at(24, 0))]),
      record('2', [TimeSegment(at(24, 0), at(24, 1))]),
    ]);
    final range = PeriodRange.of(
      FocusPeriod.day,
      beijingCalendar(2026, 10, 24),
    );
    expect(s.records(range).map((r) => r.id), ['2']);
    expect(s.distribution(range).single.duration, 3600000);
    expect(s.distribution(range).single.title, '旧任务');
  });
  test('周从周一开始，闰年、跨年和月份切换正确', () {
    final week = PeriodRange.of(FocusPeriod.week, beijingCalendar(2026, 1, 1));
    expect(week.start, beijingCalendar(2025, 12, 29));
    expect(week.end, beijingCalendar(2026, 1, 5));
    final leap = PeriodRange.of(
      FocusPeriod.month,
      beijingCalendar(2024, 2, 29),
    );
    expect(FocusStatistics([]).trend(FocusPeriod.month, leap).length, 29);
    expect(leap.shift(FocusPeriod.month, 1), beijingCalendar(2024, 3));
    expect(
      PeriodRange.of(FocusPeriod.year, beijingCalendar(2026)).end,
      beijingCalendar(2027),
    );
  });
  test('无记录不会生成虚假统计，倒计时取整且不显示负数', () {
    final s = FocusStatistics([]);
    expect([s.total, s.dailyAverage, s.streak, s.today], [0, 0, 0, 0]);
    expect(clockText(1, countdown: true), '00:00:01');
    expect(clockText(999), '00:00:00');
    const state = FocusState(
      active: ActiveFocus(
        taskId: 'a',
        title: '数学',
        color: '#087dff',
        icon: 'book',
        mode: 'down',
        targetMs: 60000,
        running: true,
      ),
      elapsedMs: 61000,
    );
    expect(state.clockMs, 0);
    expect(state.progress, 1);
  });
}
