import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'controller.dart';
import 'settings_page.dart';
import 'stats_page.dart';
import 'tasks.dart';
import 'ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const ShiguangApp());
}

class ShiguangApp extends StatefulWidget {
  final FocusController? controller;
  final bool startPolling;
  final int initialPage;
  const ShiguangApp({
    super.key,
    this.controller,
    this.startPolling = true,
    this.initialPage = 0,
  }) : assert(initialPage >= 0 && initialPage < 3);
  @override
  State<ShiguangApp> createState() => _ShiguangAppState();
}

class _ShiguangAppState extends State<ShiguangApp> {
  late final FocusController controller;
  final messenger = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<String>? subscription;
  final lightTheme = focusTheme(Brightness.light);
  final darkTheme = focusTheme(Brightness.dark);
  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? FocusController(AndroidGateway());
    subscription = controller.messages.stream.listen((text) {
      final state = messenger.currentState;
      if (state == null) return;
      state.hideCurrentSnackBar();
      state.showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 3)),
      );
    });
    if (!controller.loaded)
      unawaited(controller.initialize(polling: widget.startPolling));
  }

  @override
  void dispose() {
    subscription?.cancel();
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MaterialApp(
      title: '拾光',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messenger,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeAnimationDuration:
          WidgetsBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 280),
      themeAnimationCurve: Curves.easeOutCubic,
      themeMode: switch (controller.state.settings.theme) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      },
      home: _Home(controller: controller, initialPage: widget.initialPage),
    ),
  );
}

// Keep scroll positions and page state while isolating hidden pages from the
// per-frame theme interpolation (especially the annual heatmap).
class _RetainedPage extends StatefulWidget {
  final bool active;
  final Widget Function() builder;
  const _RetainedPage({required this.active, required this.builder});
  @override
  State<_RetainedPage> createState() => _RetainedPageState();
}

class _RetainedPageState extends State<_RetainedPage> {
  ThemeData? theme;
  Widget? child;
  @override
  Widget build(BuildContext context) {
    if (widget.active) {
      theme = Theme.of(context);
      child = widget.builder();
    }
    if (child == null) return const SizedBox.shrink();
    return TickerMode(
      enabled: widget.active,
      child: Theme(data: theme!, child: child!),
    );
  }
}

class _Home extends StatefulWidget {
  final FocusController controller;
  final int initialPage;
  const _Home({required this.controller, required this.initialPage});
  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> with SingleTickerProviderStateMixin {
  late int page = widget.initialPage;
  int handledStatisticsRequest = -1;
  void _readStatisticsRequest() {
    final c = widget.controller;
    if (handledStatisticsRequest != c.statisticsRequest) {
      handledStatisticsRequest = c.statisticsRequest;
      if (c.statisticsDate != null) page = 1;
    }
  }

  @override
  void initState() {
    super.initState();
    _readStatisticsRequest();
  }

  @override
  void didUpdateWidget(_Home oldWidget) {
    super.didUpdateWidget(oldWidget);
    _readStatisticsRequest();
  }

  int direction = 1;
  late final AnimationController animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  late final Animation<double> curve = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
  );
  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  void select(int next) {
    if (next == page) return;
    widget.controller.feedback();
    setState(() {
      direction = next > page ? 1 : -1;
      page = next;
    });
    if (MediaQuery.disableAnimationsOf(context))
      animation.value = 1;
    else
      animation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, p = AppColors.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (page != 0)
          select(0);
        else
          c.minimize();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: p.dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: p.dark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: p.dark
              ? Brightness.light
              : Brightness.dark,
        ),
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: !c.loaded
                    ? _loading(c)
                    : ClipRect(
                        child: AnimatedBuilder(
                          animation: curve,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(
                              direction * (1 - curve.value) * 22,
                              0,
                            ),
                            child: Opacity(opacity: curve.value, child: child),
                          ),
                          child: IndexedStack(
                            index: page,
                            children: [
                              _RetainedPage(
                                active: page == 0,
                                builder: () => TodoPage(controller: c),
                              ),
                              _RetainedPage(
                                active: page == 1,
                                builder: () => StatsPage(
                                  controller: c,
                                  requestedDate: c.statisticsDate,
                                  requestId: c.statisticsRequest,
                                ),
                              ),
                              _RetainedPage(
                                active: page == 2,
                                builder: () => SettingsPage(controller: c),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
          bottomNavigationBar: c.loaded
              ? SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(18, 4, 18, 10),
                  child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 644),
                      child: _navigation(p),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _loading(FocusController c) => Center(
    child: c.loadError == null
        ? const CircularProgressIndicator()
        : Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 40),
                const SizedBox(height: 15),
                Text(c.loadError!),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: c.reload,
                  child: const Text('重新读取本机数据'),
                ),
              ],
            ),
          ),
  );
  Widget _navigation(AppColors p) => Container(
    height: 76,
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: p.card,
      borderRadius: BorderRadius.circular(40),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .07),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: LayoutBuilder(
      builder: (context, bounds) => Stack(
        children: [
          AnimatedPositioned(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            left: bounds.maxWidth / 3 * page,
            top: 0,
            bottom: 0,
            width: bounds.maxWidth / 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.well,
                borderRadius: BorderRadius.circular(32),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: page == i,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => select(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            [
                              Icons.grid_view_rounded,
                              Icons.bar_chart_rounded,
                              Icons.settings_rounded,
                            ][i],
                            size: 26,
                            color: page == i ? p.blue : p.muted,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            ['待办', '统计数据', '设置'][i],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: page == i ? p.blue : p.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
