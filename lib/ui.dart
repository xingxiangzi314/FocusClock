import 'package:flutter/material.dart';

const focusColors = [
  '#087dff',
  '#8b70e8',
  '#ed9b45',
  '#31aa91',
  '#e87591',
  '#63758a',
];
const taskIcons = <String, IconData>{
  'book': Icons.menu_book_rounded,
  'read': Icons.auto_stories_rounded,
  'language': Icons.translate_rounded,
  'code': Icons.code_rounded,
  'pen': Icons.edit_rounded,
  'coffee': Icons.coffee_rounded,
};
Color taskColor(String hex) =>
    Color(0xff000000 | int.parse(hex.substring(1), radix: 16));

class AppColors {
  final bool dark;
  const AppColors(this.dark);
  factory AppColors.of(BuildContext context) =>
      AppColors(Theme.of(context).brightness == Brightness.dark);
  Color get background =>
      dark ? const Color(0xff14171d) : const Color(0xfff0eff2);
  Color get card => dark ? const Color(0xff20242c) : const Color(0xfffffcfd);
  Color get well => dark ? const Color(0xff2a2f39) : const Color(0xffefedf0);
  Color get ink => dark ? const Color(0xfff3f4f8) : const Color(0xff191c22);
  Color get muted => dark ? const Color(0xff9ba2af) : const Color(0xff7d808b);
  Color get line => dark ? const Color(0xff30353e) : const Color(0xffe9e6eb);
  Color get blue => dark ? const Color(0xff409aff) : const Color(0xff087dff);
  Color get blueSoft =>
      dark ? const Color(0xff203957) : const Color(0xffe6f0ff);
  Color get coral => dark ? const Color(0xff422d33) : const Color(0xffffe5e2);
  Color get coralInk =>
      dark ? const Color(0xffffaaa0) : const Color(0xffa3413f);
}

ThemeData focusTheme(Brightness brightness) {
  final p = AppColors(brightness == Brightness.dark);
  final scheme = ColorScheme.fromSeed(
    seedColor: p.blue,
    brightness: brightness,
    primary: p.blue,
    surface: p.card,
    onSurface: p.ink,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    textTheme: ThemeData(
      brightness: brightness,
    ).textTheme.apply(bodyColor: p.ink, displayColor: p.ink),
    dividerColor: p.line,
    splashFactory: InkRipple.splashFactory,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.well,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(color: p.card),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        enableFeedback: false,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(enableFeedback: false),
    ),
  );
}

class Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });
  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.dark ? .06 : .045),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}

class PageLayout extends StatelessWidget {
  final PageHeader header;
  final List<Widget> children;
  final PageStorageKey<String> storageKey;
  final ScrollController? controller;
  const PageLayout({
    super.key,
    required this.header,
    required this.children,
    required this.storageKey,
    this.controller,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 0), child: header),
      Expanded(
        child: ClipRect(
          child: SingleChildScrollView(
            key: storageKey,
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    ],
  );
}

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: AppColors.of(context).muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 10), action!],
        ],
      ),
    ),
  );
}

class RoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final double size;
  const RoundAction({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.primary = false,
    this.size = 56,
  });
  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Semantics(
      button: true,
      label: label,
      enabled: onTap != null,
      child: Tooltip(
        message: label,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primary ? p.blue : p.card,
            boxShadow: [
              BoxShadow(
                color: (primary ? p.blue : Colors.black).withValues(
                  alpha: primary ? .18 : .035,
                ),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              enableFeedback: false,
              child: Icon(
                icon,
                size: size * .43,
                color: primary ? Colors.white : p.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Widget? trailing;
  final FontWeight fontWeight;
  final double fontSize, spacing;
  const SectionTitle(
    this.text, {
    super.key,
    this.icon,
    this.trailing,
    this.fontWeight = FontWeight.w700,
    this.fontSize = 18,
    this.spacing = 18,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: spacing),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 21, color: AppColors.of(context).muted),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: fontSize, fontWeight: fontWeight),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class TaskBadge extends StatelessWidget {
  final String color, icon;
  final double size;
  const TaskBadge({
    super.key,
    required this.color,
    required this.icon,
    this.size = 44,
  });
  @override
  Widget build(BuildContext context) {
    final c = taskColor(color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(size * .32),
      ),
      child: Icon(
        taskIcons[icon] ?? Icons.menu_book_rounded,
        color: c,
        size: size * .49,
      ),
    );
  }
}

class SoftButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool danger;
  const SoftButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.danger = false,
  });
  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Material(
      color: danger ? p.coral : p.well,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        enableFeedback: false,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: danger ? p.coralInk : p.muted),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: danger ? p.coralInk : p.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChoiceBar<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T>? onChanged;
  final bool compact;
  const ChoiceBar({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    this.onChanged,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Container(
      padding: EdgeInsets.all(compact ? 2 : 4),
      decoration: BoxDecoration(
        color: p.well,
        borderRadius: BorderRadius.circular(compact ? 12 : 19),
      ),
      child: Row(
        children: values
            .map(
              (v) => Expanded(
                child: Semantics(
                  button: true,
                  selected: v == selected,
                  child: GestureDetector(
                    onTap: onChanged == null ? null : () => onChanged!(v),
                    child: AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      padding: EdgeInsets.symmetric(vertical: compact ? 5 : 11),
                      decoration: BoxDecoration(
                        color: v == selected ? p.blue : Colors.transparent,
                        borderRadius: BorderRadius.circular(compact ? 9 : 15),
                      ),
                      child: Text(
                        label(v),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: compact ? 10 : 13,
                          fontWeight: FontWeight.w600,
                          color: v == selected ? Colors.white : p.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  final String title, subtitle;
  const EmptyHint(this.title, this.subtitle, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Center(
      child: Column(
        children: [
          Icon(
            Icons.spa_outlined,
            size: 35,
            color: AppColors.of(context).muted.withValues(alpha: .5),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(color: AppColors.of(context).muted, fontSize: 14),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.of(context).muted,
              fontSize: 11,
              height: 1.7,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String copy,
  String confirm = '确认',
  bool danger = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(copy, style: const TextStyle(height: 1.8)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(
                    backgroundColor: AppColors.of(ctx).coral,
                    foregroundColor: AppColors.of(ctx).coralInk,
                  )
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirm),
          ),
        ],
      ),
    ) ??
    false;
