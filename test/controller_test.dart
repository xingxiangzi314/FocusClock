import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang_focus/controller.dart';
import 'test_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('触感只由应用开关控制，开启立即反馈、关闭及失败均不振动', () async {
    final g = TestGateway();
    final controller = FocusController(g);
    await controller.initialize(polling: false);
    await controller.command('setting', {'key': 'haptics', 'value': false});
    await controller.feedback();
    expect(g.vibrations, isEmpty);
    await controller.command('setting', {'key': 'haptics', 'value': true});
    expect(g.vibrations, ['click']);
    await controller.command('start');
    await controller.command('pause');
    expect(g.vibrations, ['click', 'confirm', 'click']);
    g.fail = true;
    expect(await controller.command('start'), isFalse);
    expect(g.vibrations.length, 3);
    controller.dispose();
  });
  test('迟到的轮询结果不会把暂停状态恢复成运行', () async {
    final g = TestGateway();
    final c = FocusController(g);
    await c.initialize(polling: false);
    await c.command('start');
    final delayed = Completer<String>();
    final stale = jsonEncode({
      'active': {...g.data['active'] as Map},
      'elapsedMs': 15000,
      'selectedTaskId': 'math',
      'sessionCount': 0,
    });
    g.delayedPoll = () => delayed.future;
    final pending = c.poll();
    await c.command('pause');
    delayed.complete(stale);
    await pending;
    expect(c.state.active!.running, isFalse);
    c.dispose();
  });
  test('轻量轮询保留统计缓存，自动结束会完整刷新记录', () async {
    final g = TestGateway();
    final controller = FocusController(g);
    await controller.initialize(polling: false);
    await controller.command('start');
    final sessions = controller.state.sessions;
    g.data['elapsedMs'] = 20000;
    await controller.poll();
    expect(controller.state.elapsedMs, 20000);
    expect(identical(sessions, controller.state.sessions), isTrue);
    g.data['active'] = null;
    (g.data['sessions'] as List).add({
      'id': 's',
      'taskId': 'math',
      'title': '数学',
      'color': '#087dff',
      'mode': 'down',
      'startAt': 100000,
      'endAt': 160000,
      'durationMs': 60000,
      'segments': [
        {'start': 100000, 'end': 160000},
      ],
    });
    await controller.poll();
    expect(controller.state.active, isNull);
    expect(controller.state.sessions.single.durationMs, 60000);
    controller.dispose();
  });
}
