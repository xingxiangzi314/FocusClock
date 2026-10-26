import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controller.dart';
import 'ui.dart';

class SettingsPage extends StatefulWidget {
  final FocusController controller;
  const SettingsPage({super.key, required this.controller});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  FocusController get controller => widget.controller;
  bool _themePending = false;
  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context), settings = controller.state.settings;
    return PageLayout(
      storageKey: const PageStorageKey('settings-scroll'),
      header: const PageHeader(title: '设置'),
      children: [
        _group(context, '专注偏好'),
        Surface(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
          child: Column(
            children: [
              _row(
                context,
                Icons.flag_outlined,
                '每日专注目标',
                '给每天一个恰到好处的小目标',
                value: '${settings.goal} 分钟',
                onTap: () => _goal(context),
              ),
              _row(
                context,
                Icons.dark_mode_outlined,
                '外观主题',
                '明亮、深色，或跟随系统',
                value: {
                  'system': '跟随系统',
                  'dark': '深色',
                  'light': '明亮',
                }[settings.theme],
                onTap: () => _theme(context),
              ),
              _row(
                context,
                Icons.notifications_none_rounded,
                '完成提醒',
                '倒计时结束时响铃与振动',
                toggled: settings.sound,
                onTap: () => controller.command('setting', {
                  'key': 'sound',
                  'value': !settings.sound,
                }),
              ),
              _row(
                context,
                Icons.wb_sunny_outlined,
                '屏幕常亮',
                '仅在前台专注计时期间保持亮屏',
                toggled: settings.keepAwake,
                onTap: () => controller.command('setting', {
                  'key': 'keepAwake',
                  'value': !settings.keepAwake,
                }),
              ),
              _row(
                context,
                Icons.vibration_rounded,
                '触感反馈',
                '轻短的按键触感，应用内独立控制',
                toggled: settings.haptics,
                onTap: () => controller.command('setting', {
                  'key': 'haptics',
                  'value': !settings.haptics,
                }),
              ),
              _row(
                context,
                Icons.tune_rounded,
                '触感强度',
                '调整轻重，松手即可体验',
                value: '${settings.hapticStrength}%',
                border: false,
                onTap: () => _strength(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _group(context, '数据与备份'),
        Surface(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
          child: Column(
            children: [
              _row(
                context,
                Icons.download_rounded,
                '导出备份',
                '保存任务、已完成记录与偏好设置',
                onTap: () => controller.export('json'),
              ),
              _row(
                context,
                Icons.upload_rounded,
                '恢复备份',
                '从拾光 JSON 备份恢复本机数据',
                onTap: () => _restore(context),
              ),
              _row(
                context,
                Icons.description_outlined,
                '导出专注记录',
                'CSV 格式，方便用表格查看与分析',
                onTap: () => controller.export('csv'),
              ),
              _row(
                context,
                Icons.verified_user_outlined,
                '隐私与存储',
                '无需账号，学习记录只保存在你的设备上',
                border: false,
                onTap: () => _privacy(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Surface(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
          child: Column(
            children: [
              _row(
                context,
                Icons.help_outline_rounded,
                '使用帮助与关于',
                '后台计时、统计口径与版本信息',
                onTap: () => showAbout(context),
              ),
              _row(
                context,
                Icons.delete_outline_rounded,
                '清空全部数据',
                '删除本机任务、记录并重置设置',
                border: false,
                danger: true,
                onTap: () => _reset(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 27),
        Text(
          '拾光 · 2.1.2\n专注当下，自有回响。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: p.muted, height: 2),
        ),
      ],
    );
  }

  Widget _group(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: AppColors.of(context).muted,
      ),
    ),
  );

  Widget _row(
    BuildContext context,
    IconData icon,
    String title,
    String copy, {
    String? value,
    bool? toggled,
    bool border = true,
    bool danger = false,
    required VoidCallback onTap,
  }) {
    final p = AppColors.of(context);
    return Semantics(
      toggled: toggled,
      button: toggled == null,
      label: title,
      child: InkWell(
        enableFeedback: false,
        onTap: controller.busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 19),
          decoration: BoxDecoration(
            border: border ? Border(bottom: BorderSide(color: p.line)) : null,
          ),
          child: Row(
            children: [
              Icon(icon, color: danger ? p.coralInk : p.muted, size: 22),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: danger ? p.coralInk : p.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      copy,
                      style: TextStyle(
                        color: p.muted,
                        fontSize: 10,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              if (toggled != null)
                AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  width: 43,
                  height: 27,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: toggled ? p.blue : p.well,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 180),
                    alignment: toggled
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 21,
                      height: 21,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                )
              else if (value != null)
                Text(value, style: TextStyle(color: p.muted, fontSize: 11))
              else
                Icon(Icons.chevron_right_rounded, color: p.muted, size: 19),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _goal(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => GoalEditor(controller: controller),
  );
  Future<void> _strength(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (_) => HapticStrengthEditor(controller: controller),
  );
  Future<void> _theme(BuildContext context) async {
    if (_themePending || controller.busy) return;
    _themePending = true;
    try {
      final navigator = Navigator.of(context);
      final route = ModalBottomSheetRoute<String>(
        isScrollControlled: false,
        capturedThemes: InheritedTheme.capture(
          from: context,
          to: navigator.context,
        ),
        sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : const AnimationStyle(
                reverseDuration: Duration(milliseconds: 120),
              ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SectionTitle('外观主题'),
                for (final entry in const {
                  'system': '跟随系统',
                  'light': '明亮',
                  'dark': '深色',
                }.entries)
                  ListTile(
                    title: Text(entry.value),
                    trailing: controller.state.settings.theme == entry.key
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () {
                      if (ModalRoute.of(ctx)?.isCurrent ?? false)
                        Navigator.pop(ctx, entry.key);
                    },
                  ),
              ],
            ),
          ),
        ),
      );
      final value = await navigator.push(route);
      // Start the theme fade after the outgoing sheet leaves the overlay.
      await route.completed;
      if (context.mounted &&
          value != null &&
          value != controller.state.settings.theme)
        await controller.command('setting', {'key': 'theme', 'value': value});
    } finally {
      _themePending = false;
    }
  }

  Future<void> _restore(BuildContext context) async {
    if (controller.state.active != null) {
      controller.message('请先结束当前专注，再恢复备份');
      return;
    }
    if (await confirmAction(
      context,
      title: '恢复备份',
      copy: '恢复将替换当前设备上的任务、专注记录和设置。建议先导出一份现有备份。',
      confirm: '选择备份文件',
    ))
      await controller.importBackup();
  }

  Future<void> _reset(BuildContext context) async {
    if (controller.state.active != null) {
      controller.message('请先结束当前专注，再清空数据');
      return;
    }
    if (await confirmAction(
      context,
      title: '清空全部数据？',
      copy: '本机任务、专注记录和偏好将被永久删除，无法撤销。请先导出备份。重置后会恢复三个初始示例任务。',
      confirm: '清空全部数据',
      danger: true,
    )) {
      if (await controller.command('reset')) controller.message('已重置全部数据');
    }
  }

  Future<void> _privacy(BuildContext context) => _info(context, '隐私与存储', [
    '拾光不申请网络权限，不收集或上传你的任务与学习记录。',
    '任务、偏好和专注记录保存在应用私有存储中。卸载或清除应用数据会移除这些信息，建议定期导出 JSON 备份。',
    '通知权限用于后台计时与完成提醒；导入导出通过系统文件选择器完成，不需要读取全部文件的权限。',
    '当前任务 ${controller.state.tasks.length} 个，专注记录 ${controller.state.sessions.length} 条。',
  ]);
}

class HapticStrengthEditor extends StatefulWidget {
  final FocusController controller;
  const HapticStrengthEditor({super.key, required this.controller});

  @override
  State<HapticStrengthEditor> createState() => _HapticStrengthEditorState();
}

class _HapticStrengthEditorState extends State<HapticStrengthEditor> {
  late double strength = widget.controller.state.settings.hapticStrength
      .toDouble();

  Future<void> save(double value) async {
    final saved = await widget.controller.command('setting', {
      'key': 'hapticStrength',
      'value': value.round(),
    });
    if (!saved && mounted) {
      setState(
        () => strength = widget.controller.state.settings.hapticStrength
            .toDouble(),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final c = widget.controller, p = AppColors.of(context);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SectionTitle('触感强度'),
              Text(
                '${strength.round()}%',
                style: TextStyle(fontSize: 34, color: p.ink),
              ),
              const SizedBox(height: 8),
              Slider(
                value: strength,
                min: 1,
                max: 100,
                activeColor: p.blue,
                inactiveColor: p.well,
                onChanged: c.busy
                    ? null
                    : (value) =>
                          setState(() => strength = value.roundToDouble()),
                onChangeEnd: c.busy ? null : save,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('轻柔', style: TextStyle(fontSize: 12, color: p.muted)),
                  Text('明显', style: TextStyle(fontSize: 12, color: p.muted)),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                c.state.settings.haptics
                    ? '自动保存，松手即可感受当前强度'
                    : '触感反馈已关闭，开启后使用此强度',
                style: TextStyle(fontSize: 12, color: p.muted),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  TextButton(
                    onPressed: c.busy
                        ? null
                        : () {
                            setState(() => strength = 35);
                            save(35);
                          },
                    child: const Text('恢复默认'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: c.busy || !c.state.settings.haptics
                        ? null
                        : () => c.feedback(),
                    icon: const Icon(Icons.touch_app_outlined, size: 18),
                    label: const Text('轻触体验'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class GoalEditor extends StatefulWidget {
  final FocusController controller;
  const GoalEditor({super.key, required this.controller});
  @override
  State<GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<GoalEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController goal;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    goal = TextEditingController(
      text: '${widget.controller.state.settings.goal}',
    );
  }

  @override
  void dispose() {
    goal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      0,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle('每日专注目标'),
            const Text('每日目标（5–1440 分钟）', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextFormField(
              controller: goal,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return n == null || n < 5 || n > 1440 ? '请输入 5–1440 分钟' : null;
              },
            ),
            const SizedBox(height: 16),
            Text(
              '保持稳定比一次学很久更重要。目标仅用于展示进度，不会中断计时。',
              style: TextStyle(
                color: AppColors.of(context).muted,
                height: 1.8,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      setState(() => saving = true);
                      final ok = await widget.controller.command('setting', {
                        'key': 'goal',
                        'value': int.parse(goal.text),
                      });
                      if (!context.mounted) return;
                      if (ok)
                        Navigator.pop(context);
                      else
                        setState(() => saving = false);
                    },
              child: const Text('保存目标'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showAbout(BuildContext context) => _info(context, '关于拾光 · 2.1.2', [
  '用一段段专注时间，积累看得见的成长。',
  '后台与锁屏\n开始计时后会显示常驻通知，可以暂停、继续或结束。允许通知以接收完成提醒。系统限制后台运行时，请在手机设置中允许拾光后台活动。',
  '计时与统计\n新计时有效专注超过 10 秒才生成记录，暂停时间不累计。倒计时结束按设定时长保存，正计时单次最多记录 24 小时。跨日专注按实际区间分配，累计次数只计一次。日均为首次专注日至今的总时长除以自然日数，包含未专注日。',
  '触感反馈\n触感由拾光内的开关独立控制，开启时会立即尝试轻振一次，不会因系统触感关闭而主动跳过。系统全部禁振、勿扰、省电或厂商限制仍可能阻止反馈。完成提醒单独控制。',
  '热力图\n展示所选周期所在年份。颜色依次表示无专注、不足 1 小时、1 至不足 3 小时、3 至不足 6 小时、6 至不足 8 小时和 8 小时及以上。左右滑动查看，点击日期进入当日统计。',
  '数据与恢复\n直接覆盖升级会保留任务、记录和偏好。卸载前请导出备份。JSON 备份不包含正在进行的专注，恢复会替换本机数据。设备重启后，计时暂停在最近的检查点，关机时间不计入；检查点间隔约 30 秒。',
]);
Future<void> _info(
  BuildContext context,
  String title,
  List<String> paragraphs,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (ctx) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(ctx).height * .8,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(title),
            for (final paragraph in paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  paragraph,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.95,
                    color: AppColors.of(ctx).muted,
                  ),
                ),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了'),
            ),
          ],
        ),
      ),
    ),
  ),
);
