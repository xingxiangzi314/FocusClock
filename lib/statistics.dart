import 'dart:math' as math;

import 'models.dart';

enum FocusPeriod { day, week, month, year }

/// Zero is a separate empty state; the five positive bands use elapsed hours.
int heatmapLevel(int ms) => ms <= 0
    ? 0
    : ms < 3600000
    ? 1
    : ms < 10800000
    ? 2
    : ms < 21600000
    ? 3
    : ms < 28800000
    ? 4
    : 5;
const heatmapSamples = [0, 1, 3600000, 10800000, 21600000, 28800000];
const heatmapOpacity = [0.0, .20, .38, .58, .78, 1.0];

extension FocusPeriodLabel on FocusPeriod {
  String get label => ['日', '周', '月', '年'][index];
}

DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class PeriodRange {
  final DateTime start, end;
  const PeriodRange(this.start, this.end);
  factory PeriodRange.of(FocusPeriod period, DateTime anchor) {
    final d = dayStart(anchor);
    switch (period) {
      case FocusPeriod.day:
        return PeriodRange(d, DateTime(d.year, d.month, d.day + 1));
      case FocusPeriod.week:
        final s = DateTime(d.year, d.month, d.day - d.weekday + 1);
        return PeriodRange(s, DateTime(s.year, s.month, s.day + 7));
      case FocusPeriod.month:
        return PeriodRange(
          DateTime(d.year, d.month),
          DateTime(d.year, d.month + 1),
        );
      case FocusPeriod.year:
        return PeriodRange(DateTime(d.year), DateTime(d.year + 1));
    }
  }
  DateTime shift(FocusPeriod period, int delta) => switch (period) {
    FocusPeriod.day => DateTime(start.year, start.month, start.day + delta),
    FocusPeriod.week => DateTime(
      start.year,
      start.month,
      start.day + delta * 7,
    ),
    FocusPeriod.month => DateTime(start.year, start.month + delta),
    FocusPeriod.year => DateTime(start.year + delta),
  };
  String title(FocusPeriod period) => switch (period) {
    FocusPeriod.day => dateText(start, year: true),
    FocusPeriod.week =>
      '${dateText(start)} — ${dateText(end.subtract(const Duration(seconds: 1)))}',
    FocusPeriod.month => '${start.year}年${start.month}月',
    FocusPeriod.year => '${start.year}年',
  };
}

int overlap(FocusSession session, int start, int end) => session.segments.fold(
  0,
  (sum, p) =>
      sum + math.max(0, math.min(p.end, end) - math.max(p.start, start)),
);

class Distribution {
  final String taskId, title, color;
  final int duration;
  const Distribution(this.taskId, this.title, this.color, this.duration);
}

class TrendPoint {
  final String label;
  final int duration;
  const TrendPoint(this.label, this.duration);
}

class FocusStatistics {
  final List<FocusSession> sessions;
  final DateTime now;
  FocusStatistics(this.sessions, {DateTime? now}) : now = now ?? DateTime.now();
  int get total => sessions.fold(0, (sum, r) => sum + r.durationMs);
  int get dailyAverage {
    if (sessions.isEmpty) return 0;
    final first = sessions.map((r) => r.startAt).reduce(math.min);
    final start = dayStart(DateTime.fromMillisecondsSinceEpoch(first));
    final end = dayStart(now);
    // Compare calendar dates in UTC so daylight-saving changes do not alter day count.
    final days =
        DateTime.utc(
          end.year,
          end.month,
          end.day,
        ).difference(DateTime.utc(start.year, start.month, start.day)).inDays +
        1;
    return total ~/ math.max(1, days);
  }

  late final Map<String, int> days = _dayTotals();
  Map<String, int> _dayTotals() {
    final result = <String, int>{};
    for (final r in sessions) {
      for (final p in r.segments) {
        var start = p.start;
        while (start < p.end) {
          final d = DateTime.fromMillisecondsSinceEpoch(start);
          final end = math.min(
            p.end,
            DateTime(d.year, d.month, d.day + 1).millisecondsSinceEpoch,
          );
          final key = dayKey(d);
          result[key] = (result[key] ?? 0) + end - start;
          start = end;
        }
      }
    }
    return result;
  }

  int get today => days[dayKey(now)] ?? 0;
  int get streak {
    var d = dayStart(now), count = 0;
    if ((days[dayKey(d)] ?? 0) == 0) d = DateTime(d.year, d.month, d.day - 1);
    while ((days[dayKey(d)] ?? 0) > 0) {
      count++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return count;
  }

  int inRange(PeriodRange range) => sessions.fold(
    0,
    (sum, r) =>
        sum +
        overlap(
          r,
          range.start.millisecondsSinceEpoch,
          range.end.millisecondsSinceEpoch,
        ),
  );
  List<FocusSession> records(PeriodRange range) =>
      sessions
          .where(
            (r) =>
                overlap(
                  r,
                  range.start.millisecondsSinceEpoch,
                  range.end.millisecondsSinceEpoch,
                ) >
                0,
          )
          .toList()
        ..sort((a, b) => b.startAt.compareTo(a.startAt));
  List<Distribution> distribution(PeriodRange range) {
    final totals = <String, Distribution>{};
    for (final r in sessions) {
      final ms = overlap(
        r,
        range.start.millisecondsSinceEpoch,
        range.end.millisecondsSinceEpoch,
      );
      if (ms == 0) continue;
      totals[r.taskId] = Distribution(
        r.taskId,
        r.title,
        r.color,
        (totals[r.taskId]?.duration ?? 0) + ms,
      );
    }
    return totals.values.toList()
      ..sort((a, b) => b.duration.compareTo(a.duration));
  }

  List<TrendPoint> trend(FocusPeriod period, PeriodRange range) {
    final points = <TrendPoint>[];
    if (period == FocusPeriod.day) {
      for (var hour = 0; hour < 24; hour++) {
        final d = range.start;
        points.add(
          TrendPoint(
            '$hour',
            inRange(
              PeriodRange(
                DateTime(d.year, d.month, d.day, hour),
                DateTime(d.year, d.month, d.day, hour + 1),
              ),
            ),
          ),
        );
      }
    } else if (period == FocusPeriod.year) {
      for (var month = 1; month <= 12; month++) {
        points.add(
          TrendPoint(
            '$month',
            inRange(
              PeriodRange(
                DateTime(range.start.year, month),
                DateTime(range.start.year, month + 1),
              ),
            ),
          ),
        );
      }
    } else {
      var d = range.start;
      while (d.isBefore(range.end)) {
        final n = DateTime(d.year, d.month, d.day + 1);
        points.add(
          TrendPoint(
            period == FocusPeriod.week
                ? ['一', '二', '三', '四', '五', '六', '日'][d.weekday - 1]
                : '${d.day}',
            inRange(PeriodRange(d, n)),
          ),
        );
        d = n;
      }
    }
    return points;
  }
}
