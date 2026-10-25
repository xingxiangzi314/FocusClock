import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'controller.dart';
import 'models.dart';
import 'statistics.dart';
import 'ui.dart';

class StatsPage extends StatefulWidget {
  final FocusController controller;
  const StatsPage({super.key, required this.controller});
  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  FocusPeriod period = FocusPeriod.day;
  DateTime anchor = DateTime.now();
  int recordLimit = 10;
  final scroll = ScrollController();
  FocusController get c => widget.controller;
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void changePeriod(int delta) {
    final date = PeriodRange.of(period, anchor).shift(period, delta);
    if (date.isAfter(DateTime.now())) return;
    c.feedback();
    setState(() {
      anchor = date;
      recordLimit = 10;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context), stats = c.statistics;
    final range = PeriodRange.of(period, anchor), now = DateTime.now();
    final total = stats.inRange(range), records = stats.records(range);
    return PageLayout(
      storageKey: const PageStorageKey('stats-scroll'),
      controller: scroll,
      header: PageHeader(
        title: '统计数据',
        action: RoundAction(
          size: 40,
          icon: Icons.calendar_today_rounded,
          label: '选择统计日期',
          onTap: () => _pickDate(context),
        ),
      ),
      children: [
        Surface(
          key: const ValueKey('statistics-cumulative'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 18, color: p.muted),
                  const SizedBox(width: 8),
                  const Text(
                    '累计专注',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    '${stats.streak} 天连续专注',
                    style: TextStyle(fontSize: 10, color: p.muted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _metric(
                    context,
                    '专注次数',
                    '${c.state.sessions.length}',
                    '次',
                    horizontalOffset: -8,
                  ),
                  _metric(context, '专注时长', '${stats.total ~/ 60000}', '分钟'),
                  _metric(
                    context,
                    '日均时长',
                    '${stats.dailyAverage ~/ 60000}',
                    '分钟',
                    horizontalOffset: 8,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _distributionCard(context, range, now, total),
        const SizedBox(height: 12),
        Surface(
          key: const ValueKey('statistics-heatmap'),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(
                '${anchor.year} 年专注热力图',
                icon: Icons.grid_view_rounded,
                fontSize: 16,
                spacing: 8,
                fontWeight: FontWeight.w600,
              ),
              Heatmap(
                year: anchor.year,
                days: stats.days,
                selected: dayStart(anchor),
                onSelected: (d) {
                  c.feedback();
                  setState(() {
                    anchor = d;
                    period = FocusPeriod.day;
                    recordLimit = 10;
                  });
                  scroll.animateTo(
                    0,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                  c.message(
                    '${dateText(d)} · ${durationText(stats.days[dayKey(d)] ?? 0)}',
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionTitle(
          '专注记录',
          trailing: Text(
            '所选周期 · ${records.length} 条',
            style: TextStyle(fontSize: 11, color: p.muted),
          ),
        ),
        Surface(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
          child: Column(
            children: [
              if (records.isEmpty) const EmptyHint('还没有记录', '完成一段专注，让积累看得见。'),
              for (
                var i = 0;
                i < math.min(recordLimit, records.length);
                i++
              ) ...[
                if (i > 0) Divider(height: 1, color: p.line),
                _record(context, records[i], range),
              ],
              if (records.length > recordLimit)
                TextButton(
                  onPressed: () => setState(() => recordLimit += 20),
                  child: const Text('查看更多记录'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _distributionCard(
    BuildContext context,
    PeriodRange range,
    DateTime now,
    int total,
  ) {
    final diameter = (MediaQuery.sizeOf(context).height * .13).clamp(
      88.0,
      112.0,
    );
    double lineHeight(String text, double size) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: DefaultTextStyle.of(
            context,
          ).style.merge(TextStyle(fontSize: size, fontWeight: FontWeight.w600)),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final titleHeight = math.max(21.0, lineHeight('专注时长分布', 16));
    final periodHeight = lineHeight('日', 10) + 14;
    // Preserve the 2.0.2 card's intrinsic height after removing its separate date row.
    final cardHeight =
        24 + titleHeight + 8 + periodHeight + 2 + 48 + 6 + diameter;
    final headerHeight = math.max(28.0, titleHeight);
    final periodTop = 12 + headerHeight + 8;
    final chartCenter = (periodTop + periodHeight / 2 + cardHeight) / 2;
    return SizedBox(
      height: cardHeight,
      child: Surface(
        key: const ValueKey('statistics-distribution'),
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              height: headerHeight,
              child: _distributionHeading(context, range, now),
            ),
            Positioned(
              top: periodTop,
              left: 16,
              right: 16,
              child: Align(
                alignment: Alignment.center,
                child: FractionallySizedBox(
                  widthFactor: .55,
                  child: ChoiceBar<FocusPeriod>(
                    key: const ValueKey('statistics-periods'),
                    compact: true,
                    values: FocusPeriod.values,
                    selected: period,
                    label: (v) => v.label,
                    onChanged: (v) {
                      if (period == v) return;
                      c.feedback();
                      setState(() {
                        period = v;
                        recordLimit = 10;
                      });
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: chartCenter - diameter / 2,
              left: 16,
              right: 16,
              child: DistributionChart(
                items: c.statistics.distribution(range),
                total: total,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: anchor.isAfter(now) ? now : anchor,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date != null && mounted)
      setState(() {
        anchor = date;
        recordLimit = 10;
      });
  }

  Widget _distributionHeading(
    BuildContext context,
    PeriodRange range,
    DateTime now,
  ) {
    final p = AppColors.of(context);
    final end = range.end.subtract(const Duration(days: 1));
    final label = switch (period) {
      FocusPeriod.day => '${anchor.year}.${anchor.month}.${anchor.day}',
      FocusPeriod.week =>
        '${range.start.month}.${range.start.day}–${end.month}.${end.day}',
      FocusPeriod.month => '${anchor.year}年${anchor.month}月',
      FocusPeriod.year => '${anchor.year}年',
    };
    return LayoutBuilder(
      builder: (context, space) => Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Icon(Icons.donut_large_rounded, size: 21, color: p.muted),
                  const SizedBox(width: 10),
                  const Text(
                    '专注时长分布',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: space.maxWidth * .46,
            child: Row(
              key: const ValueKey('statistics-date'),
              children: [
                IconButton(
                  tooltip: '上一周期',
                  constraints: const BoxConstraints.tightFor(
                    width: 22,
                    height: 28,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  onPressed: () => changePeriod(-1),
                  icon: const Icon(Icons.chevron_left_rounded, size: 17),
                ),
                Expanded(
                  child: Tooltip(
                    message: range.title(period),
                    child: InkWell(
                      enableFeedback: false,
                      onTap: () => _pickDate(context),
                      child: SizedBox(
                        height: 28,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            style: TextStyle(fontSize: 10, color: p.muted),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '下一周期',
                  constraints: const BoxConstraints.tightFor(
                    width: 22,
                    height: 28,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  onPressed: range.shift(period, 1).isAfter(now)
                      ? null
                      : () => changePeriod(1),
                  icon: const Icon(Icons.chevron_right_rounded, size: 17),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(
    BuildContext context,
    String label,
    String value,
    String unit, {
    double horizontalOffset = 0,
  }) {
    final p = AppColors.of(context);
    return Expanded(
      child: Transform.translate(
        offset: Offset(horizontalOffset, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: p.muted)),
            const SizedBox(height: 5),
            SizedBox(
              height: 28,
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: ' $unit',
                        style: TextStyle(fontSize: 10, color: p.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _record(BuildContext context, FocusSession record, PeriodRange range) {
    final p = AppColors.of(context),
        d = DateTime.fromMillisecondsSinceEpoch(record.startAt);
    final ms = overlap(
      record,
      range.start.millisecondsSinceEpoch,
      range.end.millisecondsSinceEpoch,
    );
    return InkWell(
      enableFeedback: false,
      onTap: () => _recordDetail(context, record),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 17),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 32,
              decoration: BoxDecoration(
                color: taskColor(record.color),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${dateText(d)} ${timeText(record.startAt)} · ${record.mode == 'up' ? '正计时' : '倒计时'}',
                    style: TextStyle(color: p.muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 7),
            Text(
              durationText(ms),
              style: TextStyle(color: p.muted, fontSize: 11),
            ),
            Icon(Icons.chevron_right_rounded, color: p.muted, size: 17),
          ],
        ),
      ),
    );
  }

  Future<void> _recordDetail(BuildContext context, FocusSession record) async {
    final remove = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle('专注记录'),
              Text(
                record.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                '${dateText(DateTime.fromMillisecondsSinceEpoch(record.startAt), year: true)} ${timeText(record.startAt)}\n至 ${dateText(DateTime.fromMillisecondsSinceEpoch(record.endAt), year: true)} ${timeText(record.endAt)}\n\n完整有效专注：${durationText(record.durationMs)}（${record.durationMs ~/ 1000} 秒）\n计时方式：${record.mode == 'up' ? '正计时' : '倒计时'}',
                style: const TextStyle(fontSize: 13, height: 1.9),
              ),
              const SizedBox(height: 25),
              SoftButton(
                label: '删除这条记录',
                icon: Icons.delete_outline_rounded,
                danger: true,
                onTap: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || remove != true) return;
    if (await confirmAction(
      context,
      title: '删除这条专注记录？',
      copy: '删除后，累计时长与图表会同步更新，操作不能撤销。',
      confirm: '删除记录',
      danger: true,
    )) {
      if (await c.command('deleteSession', {'id': record.id}))
        c.message('记录已删除');
    }
  }
}

class DistributionChart extends StatelessWidget {
  final List<Distribution> items;
  final int total;
  const DistributionChart({
    super.key,
    required this.items,
    required this.total,
  });
  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final diameter = (MediaQuery.sizeOf(context).height * .13).clamp(
      88.0,
      112.0,
    );
    return SizedBox(
      height: diameter,
      child: Row(
        children: [
          Semantics(
            label: '按任务分布，共 ${durationText(total)}',
            child: SizedBox(
              key: const ValueKey('distribution-donut'),
              width: diameter,
              height: diameter,
              child: CustomPaint(
                painter: _DonutPainter(items, total, p.well),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${total ~/ 60000}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text('分钟', style: TextStyle(color: p.muted, fontSize: 9)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: items.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('暂无专注记录', style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 5),
                      Text(
                        '完成专注后显示分布',
                        style: TextStyle(color: p.muted, fontSize: 10),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    primary: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final item in items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: taskColor(item.color),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${(item.duration / total * 100).round()}%',
                                            style: TextStyle(
                                              color: p.muted,
                                              fontSize: 9,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        durationText(item.duration),
                                        style: TextStyle(
                                          color: p.muted,
                                          fontSize: 9,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<Distribution> items;
  final int total;
  final Color empty;
  _DonutPainter(this.items, this.total, this.empty);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(11);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20;
    canvas.drawArc(arc, 0, math.pi * 2, false, paint..color = empty);
    var start = -math.pi / 2;
    for (final item in items) {
      final sweep = item.duration / total * math.pi * 2,
          gap = items.length == 1 ? 0.0 : math.min(.035, sweep * .12);
      canvas.drawArc(
        arc,
        start + gap / 2,
        sweep - gap,
        false,
        paint..color = taskColor(item.color),
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.items != items || old.total != total || old.empty != empty;
}

class Heatmap extends StatefulWidget {
  final int year;
  final Map<String, int> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  const Heatmap({
    super.key,
    required this.year,
    required this.days,
    required this.selected,
    required this.onSelected,
  });
  @override
  State<Heatmap> createState() => _HeatmapState();
}

class _HeatmapState extends State<Heatmap> {
  final scroll = ScrollController();
  int get year => widget.year;
  Map<String, int> get days => widget.days;
  DateTime get selected => widget.selected;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => revealSelected());
  }

  @override
  void didUpdateWidget(Heatmap old) {
    super.didUpdateWidget(old);
    if (old.year != year || dayKey(old.selected) != dayKey(selected)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => revealSelected());
    }
  }

  void revealSelected() {
    if (!mounted || !scroll.hasClients) return;
    final first = DateTime(year);
    final start = DateTime(year, 1, 2 - first.weekday);
    final week = selected.difference(start).inDays ~/ 7;
    final offset = (week * 15 - scroll.position.viewportDimension / 2)
        .clamp(0.0, scroll.position.maxScrollExtent)
        .toDouble();
    scroll.jumpTo(offset);
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Color levelColor(int ms, AppColors p) {
    if (ms <= 0) return p.well;
    final level = ms < 1800000
        ? .24
        : ms < 3600000
        ? .46
        : ms < 7200000
        ? .7
        : 1.0;
    return Color.alphaBlend(p.blue.withValues(alpha: level), p.card);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context),
        first = DateTime(year),
        last = DateTime(year + 1),
        now = dayStart(DateTime.now());
    final start = DateTime(year, 1, 2 - first.weekday);
    final count = (last.difference(start).inDays / 7).ceil();
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 18, right: 7),
              child: Column(
                children: [
                  for (var day = 0; day < 7; day++)
                    SizedBox(
                      height: 15,
                      child: Text(
                        day.isEven
                            ? ['一', '二', '三', '四', '五', '六', '日'][day]
                            : '',
                        style: TextStyle(fontSize: 8, color: p.muted),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scroll,
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var week = 0; week < count; week++)
                      Column(
                        children: [
                          SizedBox(
                            height: 18,
                            width: 15,
                            child: Text(
                              _monthLabel(start, week),
                              style: TextStyle(fontSize: 7, color: p.muted),
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                          for (var day = 0; day < 7; day++)
                            _cell(
                              context,
                              DateTime(
                                start.year,
                                start.month,
                                start.day + week * 7 + day,
                              ),
                              now,
                              p,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('少', style: TextStyle(fontSize: 9, color: p.muted)),
            const SizedBox(width: 6),
            for (final ms in [0, 60000, 1800000, 3600000, 7200000])
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: levelColor(ms, p),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            const SizedBox(width: 3),
            Text('多', style: TextStyle(fontSize: 9, color: p.muted)),
          ],
        ),
      ],
    );
  }

  String _monthLabel(DateTime start, int week) {
    for (var day = 0; day < 7; day++) {
      final date = DateTime(
        start.year,
        start.month,
        start.day + week * 7 + day,
      );
      if (date.year == year && date.day == 1) return '${date.month}月';
    }
    return '';
  }

  Widget _cell(BuildContext context, DateTime date, DateTime now, AppColors p) {
    final inYear = date.year == year,
        future = date.isAfter(now),
        ms = days[dayKey(date)] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(right: 3, bottom: 3),
      child: Semantics(
        button: inYear && !future,
        label: '${dateText(date)}，${durationText(ms)}',
        selected: date == selected,
        child: Tooltip(
          message: inYear ? '${dateText(date)} · ${durationText(ms)}' : '',
          child: GestureDetector(
            onTap: inYear && !future ? () => widget.onSelected(date) : null,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: !inYear
                    ? Colors.transparent
                    : future
                    ? p.well.withValues(alpha: .4)
                    : levelColor(ms, p),
                borderRadius: BorderRadius.circular(3),
                border: inYear && date == selected
                    ? Border.all(color: p.blue, width: 1.5)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
