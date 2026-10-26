import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'models.dart';
import 'statistics.dart';

abstract class FocusGateway {
  Future<String> command(String name, Json params);
  Future<String> poll();
  Future<void> haptic(String kind);
  Future<void> export(String format);
  Future<void> importBackup();
  Future<void> minimize();
}

class AndroidGateway implements FocusGateway {
  static const channel = MethodChannel('com.shiguang.focus/native');
  @override
  Future<String> command(String name, Json params) async =>
      (await channel.invokeMethod<String>('command', {
        'name': name,
        'params': jsonEncode(params),
      }))!;
  @override
  Future<String> poll() async => (await channel.invokeMethod<String>('poll'))!;
  @override
  Future<void> haptic(String kind) => channel.invokeMethod('haptic', kind);
  @override
  Future<void> export(String format) => channel.invokeMethod('export', format);
  @override
  Future<void> importBackup() => channel.invokeMethod('import');
  @override
  Future<void> minimize() => channel.invokeMethod('minimize');
}

class FocusController extends ChangeNotifier with WidgetsBindingObserver {
  final FocusGateway gateway;
  FocusState state = const FocusState();
  bool loaded = false, busy = false;
  String? statisticsDate;
  int statisticsRequest = 0;

  void openStatisticsDate(String value) {
    final date = beijingParseDate(value);
    if (_disposed ||
        date == null ||
        dayKey(date) != value ||
        date.year < 2000 ||
        date.isAfter(dayStart(beijingNow())))
      return;
    statisticsDate = value;
    statisticsRequest++;
    notifyListeners();
  }

  Future<void> _takeWidgetDate() async {
    try {
      final value = await AndroidGateway.channel.invokeMethod<String>(
        'widgetDate',
      );
      if (value != null) openStatisticsDate(value);
    } catch (_) {
      /* A normal launch has no widget request. */
    }
  }

  String? loadError;
  final messages = StreamController<String>.broadcast();
  Timer? _timer;
  bool _disposed = false, _polling = false;
  int _generation = 0;
  FocusStatistics? _statistics;
  List<FocusSession>? _statisticsSource;
  String? _statisticsDay;
  FocusStatistics get statistics {
    final today = dayKey(beijingNow());
    if (!identical(_statisticsSource, state.sessions) ||
        _statisticsDay != today) {
      _statistics = FocusStatistics(state.sessions);
      _statisticsSource = state.sessions;
      _statisticsDay = today;
    }
    return _statistics!;
  }

  FocusController(this.gateway);
  Future<void> initialize({bool polling = true}) async {
    WidgetsBinding.instance.addObserver(this);
    if (gateway is AndroidGateway) {
      AndroidGateway.channel.setMethodCallHandler((call) async {
        if (call.method == 'refresh') await reload();
        if (call.method == 'message') message(call.arguments.toString());
        if (call.method == 'widgetLaunch') {
          await reload();
          await _takeWidgetDate();
        }
      });
      await _takeWidgetDate();
    }
    await reload();
    if (polling) _startPolling();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => poll());
  }

  void message(String text) {
    if (!_disposed) messages.add(text);
  }

  String _error(Object e) =>
      e is PlatformException ? e.message ?? '操作未完成，请重试' : '数据读取失败，请重试';
  Future<void> reload() async {
    final generation = ++_generation;
    try {
      final next = FocusState.decode(await gateway.command('snapshot', {}));
      if (_disposed || generation != _generation) return;
      state = next;
      loaded = true;
      loadError = null;
      notifyListeners();
    } catch (e) {
      if (_disposed || generation != _generation) return;
      loadError = _error(e);
      notifyListeners();
    }
  }

  Future<void> poll() async {
    if (_polling || busy || !loaded || _disposed) return;
    _polling = true;
    final generation = _generation;
    try {
      final j = jsonDecode(await gateway.poll()) as Json;
      if (_disposed || generation != _generation) return;
      if (number(j['sessionCount']) != state.sessions.length) {
        final wasActive = state.active != null;
        await reload();
        if (wasActive && state.active == null) message('专注已完成，记录已自动保存');
      } else {
        if (state.active == null &&
            j['active'] == null &&
            j['selectedTaskId'] == state.selectedTaskId)
          return;
        state = state.withTimer(j);
        notifyListeners();
      }
    } catch (_) {
      /* A transient lifecycle interruption does not reset an active timer. */
    } finally {
      _polling = false;
    }
  }

  Future<bool> command(String name, [Json params = const {}]) async {
    if (busy || _disposed) return false;
    busy = true;
    ++_generation;
    notifyListeners();
    try {
      final next = FocusState.decode(await gateway.command(name, params));
      if (_disposed) return false;
      state = next;
      loaded = true;
      loadError = null;
      if (['start', 'finish', 'saveTask', 'doneTask'].contains(name)) {
        await feedback('confirm');
      } else if ([
        'pause',
        'select',
        'taskMode',
        'deleteTask',
        'deleteSession',
        'setting',
      ].contains(name)) {
        await feedback();
      }
      return true;
    } catch (e) {
      message(_error(e));
      return false;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> feedback([String kind = 'click']) async {
    if (!state.settings.haptics || _disposed) return;
    try {
      await gateway.haptic(kind);
    } catch (_) {
      /* Haptics never fail a task or timer action. */
    }
  }

  Future<void> export(String format) async {
    try {
      await gateway.export(format);
    } catch (e) {
      message(_error(e));
    }
  }

  Future<void> importBackup() async {
    try {
      await gateway.importBackup();
    } catch (e) {
      message(_error(e));
    }
  }

  Future<void> minimize() async {
    try {
      await gateway.minimize();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) {
      reload();
      _startPolling();
    } else if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.detached) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (gateway is AndroidGateway)
      AndroidGateway.channel.setMethodCallHandler(null);
    messages.close();
    super.dispose();
  }
}
