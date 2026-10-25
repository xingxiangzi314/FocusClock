import 'dart:convert';

typedef Json = Map<String, dynamic>;
int number(dynamic value) => (value as num?)?.toInt() ?? 0;

class FocusTask {
  final String id, title, color, icon, mode;
  final int minutes;
  final bool done;
  const FocusTask({
    required this.id,
    required this.title,
    required this.color,
    required this.icon,
    required this.mode,
    required this.minutes,
    this.done = false,
  });
  factory FocusTask.fromJson(Json j) => FocusTask(
    id: j['id'] as String,
    title: j['title'] as String,
    color: j['color'] as String,
    icon: j['icon'] as String? ?? 'book',
    mode: j['mode'] as String,
    minutes: number(j['minutes']),
    done: j['done'] == true,
  );
}

class TimeSegment {
  final int start, end;
  const TimeSegment(this.start, this.end);
  factory TimeSegment.fromJson(Json j) =>
      TimeSegment(number(j['start']), number(j['end']));
}

class FocusSession {
  final String id, taskId, title, color, mode;
  final int startAt, endAt, durationMs;
  final List<TimeSegment> segments;
  const FocusSession({
    required this.id,
    required this.taskId,
    required this.title,
    required this.color,
    required this.mode,
    required this.startAt,
    required this.endAt,
    required this.durationMs,
    required this.segments,
  });
  factory FocusSession.fromJson(Json j) => FocusSession(
    id: j['id'] as String,
    taskId: j['taskId'] as String,
    title: j['title'] as String,
    color: j['color'] as String,
    mode: j['mode'] as String,
    startAt: number(j['startAt']),
    endAt: number(j['endAt']),
    durationMs: number(j['durationMs']),
    segments: (j['segments'] as List)
        .map((v) => TimeSegment.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList(growable: false),
  );
}

class ActiveFocus {
  final String taskId, title, color, icon, mode;
  final int targetMs;
  final bool running;
  const ActiveFocus({
    required this.taskId,
    required this.title,
    required this.color,
    required this.icon,
    required this.mode,
    required this.targetMs,
    required this.running,
  });
  factory ActiveFocus.fromJson(Json j) => ActiveFocus(
    taskId: j['taskId'] as String,
    title: j['title'] as String,
    color: j['color'] as String,
    icon: j['icon'] as String? ?? 'book',
    mode: j['mode'] as String,
    targetMs: number(j['targetMs']),
    running: j['running'] == true,
  );
}

class FocusSettings {
  final int goal;
  final String theme;
  final bool sound, haptics, keepAwake;
  const FocusSettings({
    this.goal = 120,
    this.theme = 'system',
    this.sound = true,
    this.haptics = true,
    this.keepAwake = false,
  });
  factory FocusSettings.fromJson(Json j) => FocusSettings(
    goal: number(j['goal']),
    theme: j['theme'] as String? ?? 'system',
    sound: j['sound'] != false,
    haptics: j['haptics'] != false,
    keepAwake: j['keepAwake'] == true,
  );
}

class FocusState {
  final List<FocusTask> tasks;
  final List<FocusSession> sessions;
  final ActiveFocus? active;
  final FocusSettings settings;
  final String selectedTaskId;
  final int elapsedMs;
  const FocusState({
    this.tasks = const [],
    this.sessions = const [],
    this.active,
    this.settings = const FocusSettings(),
    this.selectedTaskId = '',
    this.elapsedMs = 0,
  });
  factory FocusState.decode(String text) {
    final j = jsonDecode(text) as Json;
    return FocusState(
      tasks: (j['tasks'] as List)
          .map((v) => FocusTask.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList(growable: false),
      sessions: (j['sessions'] as List)
          .map(
            (v) => FocusSession.fromJson(Map<String, dynamic>.from(v as Map)),
          )
          .toList(growable: false),
      active: j['active'] is Map
          ? ActiveFocus.fromJson(Map<String, dynamic>.from(j['active'] as Map))
          : null,
      settings: FocusSettings.fromJson(
        Map<String, dynamic>.from(j['settings'] as Map),
      ),
      selectedTaskId: j['selectedTaskId'] as String? ?? '',
      elapsedMs: number(j['elapsedMs']),
    );
  }
  FocusTask? get selected {
    for (final t in tasks) {
      if (t.id == selectedTaskId && !t.done) return t;
    }
    for (final t in tasks) {
      if (!t.done) return t;
    }
    return null;
  }

  FocusState withTimer(Json j) => FocusState(
    tasks: tasks,
    sessions: sessions,
    settings: settings,
    selectedTaskId: j['selectedTaskId'] as String? ?? selectedTaskId,
    active: j['active'] is Map
        ? ActiveFocus.fromJson(Map<String, dynamic>.from(j['active'] as Map))
        : null,
    elapsedMs: number(j['elapsedMs']),
  );
  bool get countingDown => (active?.mode ?? selected?.mode) == 'down';
  int get clockMs => active != null
      ? countingDown
            ? (active!.targetMs - elapsedMs).clamp(0, active!.targetMs)
            : elapsedMs
      : countingDown
      ? (selected?.minutes ?? 25) * 60000
      : 0;
  double get progress => active != null && countingDown
      ? (elapsedMs / active!.targetMs).clamp(0, 1)
      : 0;
}

String clockText(int ms, {bool countdown = false}) {
  final seconds = countdown ? (ms / 1000).ceil() : ms ~/ 1000;
  return [
    seconds ~/ 3600,
    seconds ~/ 60 % 60,
    seconds % 60,
  ].map((n) => n.toString().padLeft(2, '0')).join(':');
}

String durationText(int ms) {
  final minutes = ms ~/ 60000;
  if (minutes >= 60)
    return '${minutes ~/ 60} 小时${minutes % 60 > 0 ? ' ${minutes % 60} 分钟' : ''}';
  return minutes > 0 ? '$minutes 分钟' : '${ms ~/ 1000} 秒';
}

String dateText(DateTime d, {bool year = false}) =>
    '${year ? '${d.year}年' : ''}${d.month}月${d.day}日';
String timeText(int epoch) {
  final d = DateTime.fromMillisecondsSinceEpoch(epoch);
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
