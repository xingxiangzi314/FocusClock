import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controller.dart';
import 'focus_toggle.dart';
import 'models.dart';
import 'statistics.dart';
import 'ui.dart';

Future<void> finishFocus(
  BuildContext context,
  FocusController controller,
) async {
  final before = controller.state;
  if (before.active == null) return;
  final short = before.elapsedMs <= 10000;
  final yes = await confirmAction(
    context,
    title: short ? '结束这次专注？' : '保存这次专注？',
    copy: short
        ? '当前有效专注不超过 10 秒。结束时若仍不超过 10 秒，将不生成记录、不计入统计。'
        : '本次有效专注 ${durationText(before.elapsedMs)}。结束后会计入统计，随时可以开始下一次。',
    confirm: short ? '结束' : '结束并保存',
    danger: true,
  );
  if (yes && await controller.command('finish')) {
    controller.message(
      controller.state.sessions.length > before.sessions.length
          ? '专注已结束，记录已保存'
          : '有效专注不超过 10 秒，本次未计入统计',
    );
  }
}

class TodoPage extends StatefulWidget {
  final FocusController controller;
  const TodoPage({super.key, required this.controller});
  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  bool showDone = false;
  FocusController get c => widget.controller;
  @override
  Widget build(BuildContext context) {
    final s = c.state, p = AppColors.of(context), now = beijingNow();
    final stats = c.statistics;
    final tasks = s.tasks.where((t) => showDone || !t.done).toList();
    final done = s.tasks.where((t) => t.done).length;
    return PageLayout(
      storageKey: const PageStorageKey('todo-scroll'),
      header: PageHeader(
        title: '拾光',
        subtitle:
            '${dateText(now)} 星期${['一', '二', '三', '四', '五', '六', '日'][now.weekday - 1]}',
        action: RoundAction(
          size: 40,
          icon: Icons.add_rounded,
          label: '添加学习任务',
          onTap: () => editTask(context, c),
        ),
      ),
      children: [
        ClockCard(controller: c),
        const SizedBox(height: 18),
        Surface(
          child: Column(
            children: [
              SectionTitle(
                '今日专注',
                icon: Icons.wb_sunny_outlined,
                trailing: Text(
                  '${stats.streak} 天连续专注',
                  style: TextStyle(fontSize: 11, color: p.muted),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${stats.today ~/ 60000}',
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(
                            text: ' 分钟',
                            style: TextStyle(fontSize: 13, color: p.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    '目标 ${s.settings.goal} 分钟',
                    style: TextStyle(fontSize: 12, color: p.muted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (stats.today / (s.settings.goal * 60000)).clamp(0, 1),
                  minHeight: 7,
                  color: p.blue,
                  backgroundColor: p.well,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  stats.today >= s.settings.goal * 60000
                      ? '今日目标已达成，记得适当休息。'
                      : '每一段专注，都是向前的一小步。',
                  style: TextStyle(color: p.muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionTitle(
          '学习待办',
          trailing: Text(
            '${s.tasks.where((t) => !t.done).length} 个任务',
            style: TextStyle(fontSize: 12, color: p.muted),
          ),
        ),
        Surface(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 4),
          child: Column(
            children: [
              if (tasks.isEmpty)
                const EmptyHint('给专注一个方向', '点击右上角 ＋，添加你的第一个学习任务'),
              for (var i = 0; i < tasks.length; i++) ...[
                if (i > 0) Divider(height: 1, color: p.line),
                _taskRow(context, tasks[i], stats),
              ],
              if (done > 0) ...[
                Divider(height: 1, color: p.line),
                TextButton(
                  onPressed: () => setState(() => showDone = !showDone),
                  child: Text(
                    showDone ? '收起已完成任务' : '查看已完成任务（$done）',
                    style: TextStyle(color: p.muted, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _taskRow(BuildContext context, FocusTask task, FocusStatistics stats) {
    final p = AppColors.of(context), s = c.state;
    final running = s.active?.taskId == task.id && s.active!.running;
    final total = s.sessions
        .where((r) => r.taskId == task.id)
        .fold(0, (int n, r) => n + r.durationMs);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          TaskBadge(color: task.color, icon: task.icon),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: task.done
                  ? null
                  : () => c.command('select', {'id': task.id}),
              onLongPress: () => taskMenu(context, c, task),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: task.done ? p.muted : p.ink,
                      decoration: task.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${task.mode == 'up' ? '正计时' : '倒计时 ${task.minutes} 分钟'} · 累计 ${durationText(total)}',
                    style: TextStyle(fontSize: 10, color: p.muted),
                  ),
                ],
              ),
            ),
          ),
          if (!task.done)
            IconButton(
              tooltip: running ? '暂停${task.title}' : '开始${task.title}',
              onPressed: c.busy
                  ? null
                  : () => running
                        ? c.command('pause')
                        : c.command('start', {'id': task.id}),
              icon: Icon(
                running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: taskColor(task.color),
                size: 27,
              ),
            ),
          IconButton(
            tooltip: '${task.title}更多操作',
            onPressed: () => taskMenu(context, c, task),
            icon: Icon(Icons.more_horiz_rounded, color: p.muted, size: 22),
          ),
        ],
      ),
    );
  }
}

class ClockCard extends StatelessWidget {
  final FocusController controller;
  const ClockCard({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final s = controller.state, p = AppColors.of(context), a = s.active;
    final height = (MediaQuery.sizeOf(context).height * .25).clamp(
      200.0,
      260.0,
    );
    final minutes = a != null ? a.targetMs ~/ 60000 : s.selected?.minutes ?? 25;
    return SizedBox(
      height: height,
      child: Surface(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: FocusPetalStage(
            running: a?.running == true,
            card: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 32,
                    child: Row(
                      children: [
                        Icon(Icons.timelapse_rounded, color: p.muted, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          '专注时钟',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: a?.running == true ? p.blueSoft : p.well,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            a == null
                                ? '准备就绪'
                                : a.running
                                ? '专注中'
                                : '已暂停',
                            style: TextStyle(
                              fontSize: 10,
                              color: a?.running == true ? p.blue : p.muted,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: '沉浸时钟',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 32,
                            height: 32,
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  FocusScreen(controller: controller),
                            ),
                          ),
                          icon: Icon(
                            Icons.open_in_full_rounded,
                            size: 17,
                            color: p.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => selectTask(context, controller),
                                child: Row(
                                  children: [
                                    Icon(
                                      taskIcons[a?.icon ?? s.selected?.icon] ??
                                          Icons.menu_book_rounded,
                                      size: 15,
                                      color: taskColor(
                                        a?.color ??
                                            s.selected?.color ??
                                            focusColors.first,
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Flexible(
                                      child: Text(
                                        a?.title ??
                                            s.selected?.title ??
                                            '选择学习任务',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: p.muted,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: p.muted,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              ClockDigits(state: s, size: 44),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FocusToggleButton(
                          running: a?.running == true,
                          label: a == null
                              ? '开始专注'
                              : a.running
                              ? '暂停专注'
                              : '继续专注',
                          onTap:
                              controller.busy || s.selected == null && a == null
                              ? null
                              : () => controller.command(
                                  a?.running == true ? 'pause' : 'start',
                                ),
                          size: 58,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.countingDown ? '$minutes 分钟倒计时' : '正计时',
                                style: TextStyle(fontSize: 11, color: p.muted),
                              ),
                              if (s.countingDown && a != null) ...[
                                const SizedBox(height: 7),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: s.progress,
                                    minHeight: 4,
                                    color: p.blue,
                                    backgroundColor: p.well,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (a != null) ...[
                          const SizedBox(width: 18),
                          TextButton.icon(
                            onPressed: controller.busy
                                ? null
                                : () => finishFocus(context, controller),
                            style: TextButton.styleFrom(
                              backgroundColor: p.coral,
                              foregroundColor: p.coralInk,
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              enableFeedback: false,
                            ),
                            icon: const Icon(Icons.stop_rounded, size: 16),
                            label: const Text(
                              '结束并保存',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ClockDigits extends StatelessWidget {
  final FocusState state;
  final double size;
  const ClockDigits({super.key, required this.state, this.size = 58});
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${state.countingDown ? '倒计时' : '正计时'} ${clockText(state.clockMs, countdown: state.countingDown)}',
    child: SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          clockText(state.clockMs, countdown: state.countingDown),
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w700,
            letterSpacing: -2.2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    ),
  );
}

class FocusScreen extends StatelessWidget {
  final FocusController controller;
  const FocusScreen({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final s = controller.state, p = AppColors.of(context);
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: '退出沉浸模式',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_fullscreen_rounded),
                  ),
                ),
                const Spacer(),
                Text(
                  '${dateText(beijingNow(), year: true)} · ${s.countingDown ? '倒计时' : '正计时'}',
                  style: TextStyle(
                    color: p.muted,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 35),
                Text(
                  s.active?.title ?? s.selected?.title ?? '专注当下',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 28),
                ClockDigits(state: s, size: 92),
                const SizedBox(height: 20),
                Text(
                  s.active == null
                      ? '准备好了，就开始吧。'
                      : s.active!.running
                      ? '专注中'
                      : '已暂停',
                  style: TextStyle(color: p.muted),
                ),
                const SizedBox(height: 42),
                FocusPetalStage(
                  running: s.active?.running == true,
                  child: FocusToggleButton(
                    running: s.active?.running == true,
                    label: s.active?.running == true ? '暂停专注' : '开始或继续专注',
                    onTap:
                        controller.busy ||
                            s.selected == null && s.active == null
                        ? null
                        : () => controller.command(
                            s.active?.running == true ? 'pause' : 'start',
                          ),
                    size: 86,
                  ),
                ),
                if (s.active != null) ...[
                  const SizedBox(height: 25),
                  SoftButton(
                    label: '结束并保存',
                    icon: Icons.stop_rounded,
                    danger: true,
                    onTap: controller.busy
                        ? null
                        : () => finishFocus(context, controller),
                  ),
                ],
                const Spacer(),
                Text(
                  '专注当下，自有回响。',
                  style: TextStyle(
                    fontSize: 12,
                    color: p.muted,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 35),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> selectTask(BuildContext context, FocusController c) async {
  if (c.state.active != null) {
    c.message('请先结束当前专注，再切换任务');
    return;
  }
  if (!c.state.tasks.any((t) => !t.done)) {
    await editTask(context, c);
    return;
  }
  final id = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * .65,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              const SectionTitle('选择学习任务'),
              for (final t in c.state.tasks.where((t) => !t.done))
                ListTile(
                  leading: TaskBadge(color: t.color, icon: t.icon),
                  title: Text(t.title),
                  trailing: c.state.selected?.id == t.id
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.pop(ctx, t.id),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  if (id != null) await c.command('select', {'id': id});
}

Future<void> taskMenu(
  BuildContext context,
  FocusController c,
  FocusTask task,
) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SectionTitle(task.title),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑任务'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: Icon(
                task.done
                    ? Icons.undo_rounded
                    : Icons.check_circle_outline_rounded,
              ),
              title: Text(task.done ? '恢复到待办' : '标为已完成'),
              onTap: () => Navigator.pop(ctx, 'done'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: AppColors.of(ctx).coralInk,
              ),
              title: Text(
                '删除任务',
                style: TextStyle(color: AppColors.of(ctx).coralInk),
              ),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted) return;
  if (action == 'edit') await editTask(context, c, task: task);
  if (action == 'done') await c.command('doneTask', {'id': task.id});
  if (action == 'delete' &&
      await confirmAction(
        context,
        title: '删除这个任务？',
        copy: '已有专注记录会保留在统计中。任务删除后不能撤销。',
        confirm: '删除任务',
        danger: true,
      )) {
    if (await c.command('deleteTask', {'id': task.id}))
      c.message('任务已删除，历史记录已保留');
  }
}

Future<void> editTask(
  BuildContext context,
  FocusController c, {
  FocusTask? task,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => TaskEditor(controller: c, task: task),
);

class TaskEditor extends StatefulWidget {
  final FocusController controller;
  final FocusTask? task;
  const TaskEditor({super.key, required this.controller, this.task});
  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title, minutes;
  late String mode, color, icon;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final t = widget.task;
    title = TextEditingController(text: t?.title ?? '');
    minutes = TextEditingController(text: '${t?.minutes ?? 25}');
    mode = t?.mode ?? 'down';
    color = t?.color ?? focusColors.first;
    icon = t?.icon ?? 'book';
  }

  @override
  void dispose() {
    title.dispose();
    minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SectionTitle(widget.task == null ? '新建学习任务' : '编辑任务'),
              const Text('任务名称', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 9),
              TextFormField(
                controller: title,
                maxLength: 40,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: '例如：读完一章书',
                  counterText: '',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? '请输入任务名称' : null,
              ),
              const SizedBox(height: 22),
              const Text('计时方式', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 9),
              ChoiceBar<String>(
                values: const ['up', 'down'],
                selected: mode,
                label: (v) => v == 'up' ? '正计时' : '倒计时',
                onChanged: (v) => setState(() => mode = v),
              ),
              if (mode == 'down') ...[
                const SizedBox(height: 22),
                const Text('倒计时时长（1–720 分钟）', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 9),
                TextFormField(
                  controller: minutes,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n < 1 || n > 720
                        ? '请输入 1–720 分钟'
                        : null;
                  },
                ),
              ],
              const SizedBox(height: 22),
              const Text('任务颜色', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 13,
                runSpacing: 12,
                children: focusColors
                    .map(
                      (v) => Semantics(
                        label: '选择颜色 $v',
                        button: true,
                        selected: color == v,
                        child: GestureDetector(
                          onTap: () => setState(() => color = v),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: taskColor(v),
                              shape: BoxShape.circle,
                            ),
                            child: color == v
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 22),
              const Text('任务图标', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 9,
                runSpacing: 8,
                children: taskIcons.entries
                    .map(
                      (entry) => IconButton(
                        tooltip: '图标 ${entry.key}',
                        style: IconButton.styleFrom(
                          backgroundColor: icon == entry.key
                              ? p.blueSoft
                              : p.well,
                          foregroundColor: icon == entry.key ? p.blue : p.muted,
                        ),
                        onPressed: () => setState(() => icon = entry.key),
                        icon: Icon(entry.value, size: 22),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 22),
              Text(
                '正计时自由积累，倒计时完成后自动保存。\n暂停时间不累计，有效专注超过 10 秒才计入统计。',
                style: TextStyle(fontSize: 11, color: p.muted, height: 1.8),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        setState(() => saving = true);
                        final ok = await widget.controller.command('saveTask', {
                          'id': widget.task?.id ?? '',
                          'title': title.text.trim(),
                          'minutes': int.tryParse(minutes.text) ?? 25,
                          'mode': mode,
                          'color': color,
                          'icon': icon,
                        });
                        if (!context.mounted) return;
                        if (ok) {
                          widget.controller.message(
                            widget.task == null ? '任务已创建' : '任务已更新',
                          );
                          Navigator.pop(context);
                        } else {
                          setState(() => saving = false);
                        }
                      },
                child: Text(
                  saving
                      ? '保存中…'
                      : widget.task == null
                      ? '创建任务'
                      : '保存修改',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
