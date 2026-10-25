// IDE-only entry points. main.dart never imports this file, so preview data is
// not reachable from the Android release entry point.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'controller.dart';
import 'main.dart';
import 'models.dart';

@Preview(group: '拾光 UI', name: '待办', size: Size(412, 915))
Widget todoPreview() => const _UiPreview(initialPage: 0);

@Preview(group: '拾光 UI', name: '统计数据', size: Size(412, 915))
Widget statisticsPreview() => const _UiPreview(initialPage: 1);

@Preview(group: '拾光 UI', name: '设置', size: Size(412, 915))
Widget settingsPreview() => const _UiPreview(initialPage: 2);

class _UiPreview extends StatefulWidget {
  final int initialPage;
  const _UiPreview({required this.initialPage});

  @override
  State<_UiPreview> createState() => _UiPreviewState();
}

class _UiPreviewState extends State<_UiPreview> {
  late final FocusController controller;

  @override
  void initState() {
    super.initState();
    final gateway = _PreviewGateway();
    controller = FocusController(gateway)
      ..state = FocusState.decode(jsonEncode(gateway.data))
      ..loaded = true;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShiguangApp(
    controller: controller,
    startPolling: false,
    initialPage: widget.initialPage,
  );
}

// Static, in-memory display data: no timer, file access, platform channel,
// permissions, notifications, or connection to a user's study records.
class _PreviewGateway implements FocusGateway {
  final Json data = _previewData();

  @override
  Future<String> command(String name, Json params) async => jsonEncode(data);
  @override
  Future<String> poll() async => jsonEncode(data);
  @override
  Future<void> haptic(String kind) async {}
  @override
  Future<void> export(String format) async {}
  @override
  Future<void> importBackup() async {}
  @override
  Future<void> minimize() async {}
}

Json _previewData() {
  final now = DateTime.now();
  final sessions = <Json>[];
  for (var day = 0; day < 35; day++) {
    if (day % 5 == 4) continue;
    for (var task = 0; task < 2; task++) {
      final start = DateTime(
        now.year,
        now.month,
        now.day - day,
        9 + task * 2,
      ).millisecondsSinceEpoch;
      final duration = (task == 0 ? 25 : 38) * 60000;
      sessions.add({
        'id': 'preview-$day-$task',
        'taskId': task == 0 ? 'math' : 'read',
        'title': task == 0 ? '数学' : '阅读',
        'color': task == 0 ? '#087dff' : '#ed9b45',
        'mode': task == 0 ? 'down' : 'up',
        'startAt': start,
        'endAt': start + duration,
        'durationMs': duration,
        'segments': [
          {'start': start, 'end': start + duration},
        ],
      });
    }
  }
  return {
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
        'color': '#ed9b45',
        'icon': 'read',
        'mode': 'up',
        'minutes': 25,
        'done': false,
      },
      {
        'id': 'english',
        'title': '英语练习',
        'color': '#8b70e8',
        'icon': 'language',
        'mode': 'down',
        'minutes': 30,
        'done': false,
      },
    ],
    'sessions': sessions,
    'settings': {
      'goal': 120,
      'theme': 'light',
      'sound': false,
      'haptics': false,
      'keepAwake': false,
    },
    'selectedTaskId': 'math',
    'active': {
      'taskId': 'math',
      'title': '数学',
      'color': '#087dff',
      'icon': 'book',
      'mode': 'down',
      'targetMs': 1500000,
      'running': true,
    },
    'elapsedMs': 487000,
  };
}
