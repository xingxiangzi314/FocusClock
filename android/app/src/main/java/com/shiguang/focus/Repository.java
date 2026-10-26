package com.shiguang.focus;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.SystemClock;
import android.provider.Settings;
import org.json.JSONArray;
import org.json.JSONObject;
import java.util.HashSet;
import java.util.UUID;

/** Single synchronized owner of tasks, focus intervals, and timer state. */
public final class Repository {
    private static Repository instance;
    public static synchronized Repository get(Context ctx) {
        if (instance == null) instance = new Repository(ctx.getApplicationContext());
        return instance;
    }
    private final Context ctx;
    private final SharedPreferences prefs;
    private JSONObject state;
    private boolean completed;
    private long lastCheckpoint;
    private static final long MAX_UP = 24L * 60 * 60 * 1000;

    private Repository(Context c) {
        ctx = c; prefs = c.getSharedPreferences("focus", Context.MODE_PRIVATE);
        try { state = new JSONObject(prefs.getString("state", "")); if (state.optInt("schemaVersion") != 1) throw new Exception(); }
        catch (Exception ex) { state = defaults(); }
        try {
            if (!settings().has("hapticStrength")) { settings().put("hapticStrength", 35); save(); }
            JSONObject a = active();
            // A powered-off device is not study time. Recover only the last checkpoint.
            if (a != null && a.optBoolean("running") && a.optInt("bootCount", -1) != bootCount()) {
                long elapsed = Math.max(a.optLong("baseMs"), a.optLong("checkpointMs"));
                append(a, Math.max(0, elapsed - a.optLong("baseMs")));
                a.put("baseMs", elapsed); a.put("running", false); save();
            }
        } catch (Exception ignored) {}
    }
    private int bootCount() { return Settings.Global.getInt(ctx.getContentResolver(), "boot_count", -1); }
    private static JSONObject object(String value) { try {return new JSONObject(value);}catch(Exception e){throw new IllegalStateException(e);} }
    private static JSONObject defaults() {
        return object("{\"schemaVersion\":1,\"selectedTaskId\":\"learn\",\"active\":null,\"sessions\":[],\"settings\":{\"goal\":120,\"theme\":\"system\",\"sound\":true,\"haptics\":true,\"hapticStrength\":35,\"keepAwake\":false},\"tasks\":[{\"id\":\"learn\",\"title\":\"深度学习\",\"color\":\"#087dff\",\"icon\":\"book\",\"mode\":\"down\",\"minutes\":25,\"done\":false},{\"id\":\"read\",\"title\":\"阅读与思考\",\"color\":\"#8b70e8\",\"icon\":\"read\",\"mode\":\"up\",\"minutes\":25,\"done\":false},{\"id\":\"english\",\"title\":\"英语练习\",\"color\":\"#ed9b45\",\"icon\":\"language\",\"mode\":\"down\",\"minutes\":30,\"done\":false}]}");
    }
    private void save() { if (!prefs.edit().putString("state", state.toString()).commit()) throw new IllegalStateException("本机存储失败，请检查可用空间"); }
    public synchronized String widgetSnapshot() {return "{\"theme\":" + JSONObject.quote(settings().optString("theme","system")) + ",\"sessions\":" + sessions().toString() + "}";}
    public synchronized JSONObject active() { return state.optJSONObject("active"); }
    public synchronized JSONObject settings() { return state.optJSONObject("settings"); }
    private JSONArray tasks() { return state.optJSONArray("tasks"); }
    private JSONArray sessions() { return state.optJSONArray("sessions"); }
    private JSONObject findTask(String id) {
        for (int i = 0; i < tasks().length(); i++) { JSONObject t = tasks().optJSONObject(i); if (id.equals(t.optString("id"))) return t; }
        return null;
    }
    private long limit(JSONObject a) { return "down".equals(a.optString("mode")) ? a.optLong("targetMs") : MAX_UP; }
    public synchronized long elapsed() {
        JSONObject a = active(); if (a == null) return 0;
        long delta = a.optBoolean("running") ? Math.max(0, SystemClock.elapsedRealtime() - a.optLong("startedElapsed")) : 0;
        return Math.min(limit(a), a.optLong("baseMs") + delta);
    }
    private void append(JSONObject a, long duration) throws Exception {
        if (duration > 0) a.getJSONArray("segments").put(new JSONObject().put("start", a.getLong("startedAt")).put("end", a.getLong("startedAt") + duration));
    }
    private void finish() throws Exception {
        JSONObject a = active(); if (a == null) return; long ms = elapsed();
        if (a.optBoolean("running")) append(a, Math.max(0, ms - a.optLong("baseMs")));
        JSONArray segments = a.getJSONArray("segments");
        if (ms > 10000 && segments.length() > 0) sessions().put(new JSONObject().put("id", "s" + UUID.randomUUID()).put("taskId", a.getString("taskId")).put("title", a.getString("title")).put("color", a.getString("color")).put("mode", a.getString("mode")).put("startAt", segments.getJSONObject(0).getLong("start")).put("endAt", segments.getJSONObject(segments.length() - 1).getLong("end")).put("durationMs", ms).put("segments", segments));
        state.put("active", JSONObject.NULL);
    }
    public synchronized void tick() {
        try {
            JSONObject a = active();
            if (a != null && a.optBoolean("running")) {
                if (elapsed() >= limit(a)) { finish(); completed = true; save(); HeatmapWidget.requestUpdate(ctx); }
                else if (SystemClock.elapsedRealtime() - lastCheckpoint >= 30000) { a.put("checkpointMs", elapsed()); save(); lastCheckpoint = SystemClock.elapsedRealtime(); }
            }
        } catch (Exception ex) { android.util.Log.e("Focus", "Timer checkpoint failed", ex); }
    }
    public synchronized boolean consumeCompletion() { boolean c = completed; completed = false; return c; }
    public synchronized String snapshot() throws Exception { tick(); return new JSONObject(state.toString()).put("elapsedMs", elapsed()).toString(); }
    public synchronized String timerSnapshot() throws Exception {
        tick();
        return new JSONObject().put("active", active() == null ? JSONObject.NULL : active())
            .put("elapsedMs", elapsed()).put("sessionCount", sessions().length())
            .put("selectedTaskId", state.optString("selectedTaskId")).toString();
    }
    public synchronized String backup() throws Exception { return new JSONObject(state.toString()).put("active", JSONObject.NULL).toString(2); }
    private void ensureIdle() { if (active() != null) throw new IllegalArgumentException("请先结束当前专注"); }
    private void taskEditable(String id) { if (active() != null && id.equals(active().optString("taskId"))) throw new IllegalArgumentException("请先结束该任务的专注"); }
    private void selectFirst() throws Exception {
        state.put("selectedTaskId", "");
        for (int i = 0; i < tasks().length(); i++) if (!tasks().getJSONObject(i).optBoolean("done")) { state.put("selectedTaskId", tasks().getJSONObject(i).getString("id")); break; }
    }
    private static void require(boolean ok, String msg) { if (!ok) throw new IllegalArgumentException(msg); }
    private static boolean validColor(String c) { return c.matches("#[a-fA-F0-9]{6}"); }
    private static boolean validIcon(String i) { return ("|book|read|language|code|pen|coffee|").contains("|" + i + "|"); }
    private static void validateTask(JSONObject t) {
        require(!t.optString("title").trim().isEmpty() && t.optString("title").length() <= 40, "请输入 1–40 字的任务名称");
        require(validColor(t.optString("color")) && validIcon(t.optString("icon")), "任务颜色或图标无效");
        require("up".equals(t.optString("mode")) || "down".equals(t.optString("mode")), "计时模式无效");
        double m = t.optDouble("minutes", 0); require(m == Math.floor(m) && m >= 1 && m <= 720, "倒计时时长为 1–720 分钟");
    }
    public synchronized String command(String cmd, JSONObject p) {
        try {
            tick(); JSONObject a = active(); String id = p.optString("id");
            switch (cmd) {
                case "snapshot": return snapshot();
                case "select": ensureIdle(); require(findTask(id) != null && !findTask(id).optBoolean("done"), "任务不存在"); state.put("selectedTaskId", id); break;
                case "saveTask": {
                    taskEditable(id); JSONObject old = findTask(id); validateTask(p);
                    require(old != null || tasks().length() < 500, "任务最多可创建 500 个");
                    JSONObject t = new JSONObject().put("id", old == null ? "t" + UUID.randomUUID() : id).put("title", p.getString("title").trim()).put("color", p.getString("color")).put("icon", p.getString("icon")).put("mode", p.getString("mode")).put("minutes", p.getInt("minutes")).put("done", old != null && old.optBoolean("done"));
                    if (old == null) tasks().put(t); else for (int i = 0; i < tasks().length(); i++) if (id.equals(tasks().getJSONObject(i).getString("id"))) {tasks().put(i, t); break;}
                    if (t.optBoolean("done")) selectFirst(); else state.put("selectedTaskId", t.getString("id")); break;
                }
                case "taskMode": { ensureIdle(); JSONObject t = findTask(state.optString("selectedTaskId")); require(t != null, "请先添加任务"); require("up".equals(p.optString("mode")) || "down".equals(p.optString("mode")), "计时模式无效");t.put("mode", p.getString("mode"));break; }
                case "doneTask": case "deleteTask": {
                    taskEditable(id); JSONObject t = findTask(id); require(t != null, "任务不存在");
                    if ("doneTask".equals(cmd)) t.put("done", !t.optBoolean("done")); else for (int i = 0; i < tasks().length(); i++) if (id.equals(tasks().getJSONObject(i).optString("id"))) {tasks().remove(i);break;}
                    if (id.equals(state.optString("selectedTaskId"))) selectFirst(); break;
                }
                case "start": {
                    if (a != null) { require(id.isEmpty() || id.equals(a.optString("taskId")), "请先结束当前专注"); if (!a.optBoolean("running")) {a.put("running", true).put("startedAt", System.currentTimeMillis()).put("startedElapsed", SystemClock.elapsedRealtime()).put("bootCount", bootCount());} }
                    else {JSONObject t = findTask(id.isEmpty() ? state.optString("selectedTaskId") : id);require(t != null && !t.optBoolean("done"), "请先选择或添加一个任务");state.put("selectedTaskId", t.getString("id"));state.put("active", new JSONObject().put("taskId", t.getString("id")).put("title", t.getString("title")).put("color", t.getString("color")).put("icon", t.getString("icon")).put("mode", t.getString("mode")).put("targetMs", t.getLong("minutes") * 60000).put("baseMs", 0).put("checkpointMs", 0).put("running", true).put("startedAt", System.currentTimeMillis()).put("startedElapsed", SystemClock.elapsedRealtime()).put("bootCount", bootCount()).put("segments", new JSONArray()));}
                    break;
                }
                case "pause": if (a != null && a.optBoolean("running")) {long ms = elapsed();append(a, ms - a.optLong("baseMs"));a.put("baseMs", ms).put("running", false).put("checkpointMs", ms);}break;
                case "finish": finish();break;
                case "discard": state.put("active", JSONObject.NULL);break;
                case "setting": {
                    String key = p.getString("key");require(settings().has(key), "未知设置");
                    if ("goal".equals(key)) {double v = p.optDouble("value");require(v == Math.floor(v) && v >= 5 && v <= 1440, "每日目标为 5–1440 分钟");}
                    else if ("hapticStrength".equals(key)) {double v = p.optDouble("value");require(p.get("value") instanceof Number && v == Math.floor(v) && v >= 1 && v <= 100, "触感强度为 1–100");}
                    else if ("theme".equals(key)) require("|light|dark|system|".contains("|" + p.optString("value") + "|"), "主题无效");
                    else require(p.get("value") instanceof Boolean, "设置值无效");
                    settings().put(key, p.get("value")); break;
                }
                case "deleteSession": for (int i = 0; i < sessions().length(); i++) if (id.equals(sessions().getJSONObject(i).optString("id"))) {sessions().remove(i);break;}break;
                case "restore": ensureIdle();state = validatedBackup(p.getJSONObject("data"));break;
                case "reset": ensureIdle();state = defaults();break;
                default: throw new IllegalArgumentException("未知操作");
            }
            save();
            if ("finish".equals(cmd) || "deleteSession".equals(cmd) || "restore".equals(cmd) || "reset".equals(cmd)
                || ("setting".equals(cmd) && "theme".equals(p.optString("key")))) HeatmapWidget.requestUpdate(ctx);
            return snapshot();
        } catch (Exception ex) {return new JSONObjectBuilder().error(ex.getMessage());}
    }
    public static JSONObject validatedBackup(JSONObject raw) throws Exception {
        require(raw.optInt("schemaVersion") == 1, "这不是有效的拾光备份文件");
        JSONArray tasks = raw.getJSONArray("tasks"), records = raw.getJSONArray("sessions");require(tasks.length() <= 500 && records.length() <= 100000, "备份条目过多");
        HashSet<String> ids = new HashSet<>();JSONArray cleanTasks = new JSONArray();
        String selected = "";
        for (int i = 0; i < tasks.length(); i++) {
            JSONObject t = tasks.getJSONObject(i);String id = t.getString("id");require(!id.isEmpty() && id.length() <= 100 && ids.add(id), "备份任务编号无效");
            if (!validIcon(t.optString("icon"))) t.put("icon", "book");validateTask(t);
            JSONObject clean = new JSONObject().put("id", id).put("title", t.getString("title").trim()).put("color", t.getString("color")).put("icon", t.getString("icon")).put("mode", t.getString("mode")).put("minutes", t.getInt("minutes")).put("done", t.optBoolean("done"));cleanTasks.put(clean);
            if (selected.isEmpty() && !clean.optBoolean("done")) selected = id;
        }
        ids.clear();JSONArray cleanRecords = new JSONArray();
        for (int i = 0; i < records.length(); i++) {
            JSONObject r = records.getJSONObject(i);String id = r.getString("id"), title = r.getString("title");
            require(!id.isEmpty() && ids.add(id) && title.length() <= 40 && validColor(r.getString("color")) && ("down".equals(r.getString("mode")) || "up".equals(r.getString("mode"))), "备份专注记录无效");
            long start = r.getLong("startAt"), end = r.getLong("endAt"), duration = r.getLong("durationMs");
            require(start >= 0 && end >= start && end <= System.currentTimeMillis() + 86400000L && duration >= 1000 && duration <= 31536000000L, "备份时间数据无效");
            JSONArray segments = r.getJSONArray("segments"), cleanSegments = new JSONArray();require(segments.length() > 0 && segments.length() <= 10000, "备份时间区间无效");long sum = 0, previous = start;
            for (int j = 0; j < segments.length(); j++) {JSONObject p = segments.getJSONObject(j);long from = p.getLong("start"), to = p.getLong("end");require(from >= previous && to >= from && to <= end, "备份时间区间无效");sum += to - from;previous = to;cleanSegments.put(new JSONObject().put("start", from).put("end", to));}
            require(Math.abs(sum - duration) <= 2, "备份时长与记录不一致");
            cleanRecords.put(new JSONObject().put("id", id).put("taskId", r.getString("taskId")).put("title", title).put("color", r.getString("color")).put("mode", r.getString("mode")).put("startAt", start).put("endAt", end).put("durationMs", duration).put("segments", cleanSegments));
        }
        JSONObject cfg = raw.getJSONObject("settings");double goal = cfg.optDouble("goal");require(goal == Math.floor(goal) && goal >= 5 && goal <= 1440 && "|light|dark|system|".contains("|" + cfg.optString("theme") + "|"), "备份设置无效");
        JSONObject cleanSettings = new JSONObject().put("goal", (int) goal).put("theme", cfg.getString("theme")).put("sound", cfg.optBoolean("sound", true)).put("haptics", cfg.optBoolean("haptics", true)).put("keepAwake", cfg.optBoolean("keepAwake"));
        int strength = 35;
        if (cfg.has("hapticStrength")) {
            double value = cfg.optDouble("hapticStrength");
            require(cfg.get("hapticStrength") instanceof Number && value == Math.floor(value) && value >= 1 && value <= 100, "备份触感强度无效");
            strength = (int) value;
        }
        cleanSettings.put("hapticStrength", strength);
        return new JSONObject().put("schemaVersion", 1).put("tasks", cleanTasks).put("sessions", cleanRecords).put("settings", cleanSettings).put("active", JSONObject.NULL).put("selectedTaskId", selected);
    }
    public synchronized String csv() throws Exception {
        java.text.SimpleDateFormat date = new java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.CHINA);
        StringBuilder out = new StringBuilder("\uFEFF任务,模式,开始时间,结束时间,专注秒数,专注分钟数\r\n");
        for (int i = 0; i < sessions().length(); i++) {JSONObject r = sessions().getJSONObject(i);String title = r.getString("title");if (title.matches("^[=+\\-@\\t\\r].*")) title = "'" + title;String[] fields = {title,"down".equals(r.getString("mode")) ? "倒计时" : "正计时",date.format(new java.util.Date(r.getLong("startAt"))),date.format(new java.util.Date(r.getLong("endAt"))),String.valueOf(r.getLong("durationMs") / 1000),String.format(java.util.Locale.US,"%.2f",r.getLong("durationMs") / 60000.0)};for (int j = 0; j < fields.length; j++) {if (j > 0) out.append(',');out.append('"').append(fields[j].replace("\"", "\"\"")).append('"');}out.append("\r\n");}
        return out.toString();
    }
    private static final class JSONObjectBuilder { String error(String message) {try {return new JSONObject().put("error", message == null ? "数据读取失败" : message).toString();}catch(Exception e){return "{\"error\":\"操作失败\"}";}} }
}
