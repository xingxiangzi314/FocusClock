import 'dart:convert';

import 'package:shiguang_focus/controller.dart';
import 'package:shiguang_focus/models.dart';

Json sampleState() => {
  'schemaVersion': 1,
  'tasks': [
    {
      'id': 'math',
      'title': '数学',
      'color': '#087dff',
      'icon': 'book',
      'mode': 'down',
      'minutes': 25,
      'done': false,
    },
    {
      'id': 'read',
      'title': '阅读',
      'color': '#ffad33',
      'icon': 'book',
      'mode': 'up',
      'minutes': 25,
      'done': false,
    },
  ],
  'sessions': [],
  'settings': {
    'goal': 120,
    'theme': 'light',
    'sound': true,
    'haptics': true,
    'keepAwake': false,
  },
  'selectedTaskId': 'math',
  'active': null,
  'elapsedMs': 0,
};

class TestGateway implements FocusGateway {
  Json data = jsonDecode(jsonEncode(sampleState())) as Json;
  final List<String> calls = [], vibrations = [], exports = [];
  Future<String> Function()? delayedPoll;
  bool fail = false;
  @override
  Future<String> command(String name, Json params) async {
    calls.add(name);
    if (fail) throw StateError('offline bridge error');
    if (name == 'setting')
      (data['settings'] as Json)[params['key']] = params['value'];
    if (name == 'start') {
      if (data['active'] == null) {
        final t =
            (data['tasks'] as List).firstWhere(
                  (t) => t['id'] == (params['id'] ?? data['selectedTaskId']),
                )
                as Json;
        data['active'] = {
          ...t,
          'taskId': t['id'],
          'targetMs': t['minutes'] * 60000,
          'running': true,
        };
      } else {
        (data['active'] as Json)['running'] = true;
      }
    }
    if (name == 'pause') (data['active'] as Json)['running'] = false;
    if (name == 'finish') {
      data['active'] = null;
      data['elapsedMs'] = 0;
    }
    if (name == 'saveTask')
      (data['tasks'] as List).add({...params, 'id': 'new', 'done': false});
    return jsonEncode(data);
  }

  @override
  Future<String> poll() async => delayedPoll != null
      ? delayedPoll!()
      : jsonEncode({
          'active': data['active'],
          'elapsedMs': data['elapsedMs'],
          'selectedTaskId': data['selectedTaskId'],
          'sessionCount': (data['sessions'] as List).length,
        });
  @override
  Future<void> haptic(String kind) async {
    vibrations.add(kind);
  }

  @override
  Future<void> export(String format) async {
    exports.add(format);
  }

  @override
  Future<void> importBackup() async {
    calls.add('import');
  }

  @override
  Future<void> minimize() async {
    calls.add('minimize');
  }
}
