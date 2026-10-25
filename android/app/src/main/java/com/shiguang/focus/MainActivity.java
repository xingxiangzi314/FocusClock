package com.shiguang.focus;

import android.Manifest;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.view.WindowManager;
import org.json.JSONObject;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

/** Flutter is the complete UI; Android retains the original durable timer and storage. */
public class MainActivity extends FlutterActivity {
    private static final int EXPORT = 41, IMPORT = 42;
    private Repository repo;
    private MethodChannel channel;
    private String pendingExport;
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private Boolean appliedAwake;
    private boolean barsConfigured;

    @Override public void onCreate(Bundle state) {
        repo = Repository.get(this);
        super.onCreate(state);
        applyAppearance();
        if (repo.active() != null) updateService();
    }
    @Override public void configureFlutterEngine(FlutterEngine engine) {
        super.configureFlutterEngine(engine);
        if (repo == null) repo = Repository.get(this);
        channel = new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), "com.shiguang.focus/native");
        channel.setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "command": {
                    final String name = call.argument("name"), params = call.argument("params");
                    worker.execute(() -> {
                        try {
                            JSONObject arguments = new JSONObject(params == null ? "{}" : params);
                            JSONObject payload = new JSONObject(repo.command(name, arguments));
                            boolean refreshSettingsNotification = "setting".equals(name) && !"theme".equals(arguments.optString("key"));
                            runOnUiThread(() -> {
                                if (payload.has("error")) {result.error("command", payload.optString("error"), null);return;}
                                if (!"snapshot".equals(name)) {
                                    applyAppearance();
                                    if ("start".equals(name) || "pause".equals(name) || "finish".equals(name) || "discard".equals(name)) updateService();
                                    if (refreshSettingsNotification && repo.active() != null) updateService();
                                    if ("start".equals(name)) requestNotificationPermission();
                                }
                                result.success(payload.toString());
                            });
                        } catch (Exception ex) {runOnUiThread(() -> result.error("command", "操作失败，请重试", null));}
                    });
                    break;
                }
                case "poll": worker.execute(() -> {
                    try {String value = repo.timerSnapshot();runOnUiThread(() -> {applyAppearance();result.success(value);});}
                    catch (Exception ex) {runOnUiThread(() -> result.error("poll", "计时状态读取失败", null));}
                });break;
                case "haptic": Haptics.perform(this,repo.settings().optBoolean("haptics",true),repo.settings().optInt("hapticStrength",Haptics.DEFAULT_STRENGTH),(String)call.arguments);result.success(null);break;
                case "export": exportData((String)call.arguments);result.success(null);break;
                case "import": importData();result.success(null);break;
                case "minimize": moveTaskToBack(true);result.success(null);break;
                default: result.notImplemented();
            }
        });
    }
    private void updateService() {
        try {
            if (repo.active() != null) startForegroundService(new Intent(this,FocusService.class));
            else startService(new Intent(this,FocusService.class));
        } catch (Exception ex) {message("系统限制了后台服务，前台计时仍可使用");}
    }
    private void requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED && !getSharedPreferences("MainActivity",0).getBoolean("notificationAsked",false)) {
            getSharedPreferences("MainActivity",0).edit().putBoolean("notificationAsked",true).apply();
            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS},70);
        }
    }
    private void applyAppearance() {
        if (repo == null) return;
        JSONObject active = repo.active();
        boolean awake = repo.settings().optBoolean("keepAwake") && active != null && active.optBoolean("running");
        if (appliedAwake == null || appliedAwake != awake) {
            if (awake) getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
            else getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
            appliedAwake = awake;
        }
        if (!barsConfigured) {
            getWindow().setStatusBarColor(Color.TRANSPARENT);
            getWindow().setNavigationBarColor(Color.TRANSPARENT);
            barsConfigured = true;
        }
    }
    private void refresh() {if (channel != null) channel.invokeMethod("refresh",null);}
    private void message(String text) {runOnUiThread(() -> {if (channel != null) channel.invokeMethod("message",text);});}
    private void exportData(String format) {
        try {
            pendingExport = "csv".equals(format) ? repo.csv() : repo.backup();
            Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
                .setType("csv".equals(format) ? "text/csv" : "application/json")
                .putExtra(Intent.EXTRA_TITLE,"拾光-" + new java.text.SimpleDateFormat("yyyy-MM-dd",java.util.Locale.CHINA).format(new java.util.Date()) + ("csv".equals(format) ? ".csv" : ".json"));
            startActivityForResult(intent,EXPORT);
        } catch (Exception ex) {pendingExport = null;message("未能打开文件保存窗口");}
    }
    private void importData() {
        if (repo.active() != null) {message("请先结束当前专注，再恢复备份");return;}
        try {startActivityForResult(new Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
            .setType("*/*").putExtra(Intent.EXTRA_MIME_TYPES,new String[]{"application/json","text/plain","application/octet-stream"}),IMPORT);}
        catch (Exception ex) {message("未能打开文件选择窗口");}
    }
    @Override protected void onActivityResult(int request,int result,Intent data) {
        super.onActivityResult(request,result,data);
        if (result != RESULT_OK || data == null || data.getData() == null) {if (request == EXPORT) pendingExport = null;return;}
        Uri uri = data.getData();
        if (request == EXPORT) {
            final String text = pendingExport;pendingExport = null;
            if (text == null) {message("导出已取消，请重试");return;}
            worker.execute(() -> {
                try (OutputStream out = getContentResolver().openOutputStream(uri,"wt")) {
                    if (out == null) throw new IOException();out.write(text.getBytes(StandardCharsets.UTF_8));message("文件已保存");
                } catch (Exception ex) {message("保存失败，请检查文件位置或存储空间");}
            });
        }
        if (request == IMPORT) worker.execute(() -> {
            try (InputStream in = getContentResolver().openInputStream(uri);ByteArrayOutputStream out = new ByteArrayOutputStream()) {
                if (in == null) throw new IOException();byte[] chunk = new byte[8192];int n;
                while ((n = in.read(chunk)) != -1) {if (out.size()+n > 20*1024*1024) throw new IllegalArgumentException("备份文件不能超过 20 MB");out.write(chunk,0,n);}
                String text = out.toString("UTF-8");if (text.startsWith("\uFEFF")) text = text.substring(1);
                JSONObject validated = Repository.validatedBackup(new JSONObject(text));
                runOnUiThread(() -> new AlertDialog.Builder(this).setTitle("确认恢复备份？")
                    .setMessage("即将恢复 " + validated.optJSONArray("tasks").length() + " 个任务与 " + validated.optJSONArray("sessions").length() + " 条记录，并替换当前本机数据。")
                    .setNegativeButton("取消",null).setPositiveButton("恢复",(dialog,which) -> worker.execute(() -> {
                        try {
                            JSONObject value = new JSONObject(repo.command("restore",new JSONObject().put("data",validated)));
                            if (value.has("error")) {message(value.optString("error"));return;}
                            runOnUiThread(() -> {applyAppearance();refresh();message("已恢复备份");});
                        } catch (Exception ex) {message("恢复失败，原有数据已保留");}
                    })).show());
            } catch (Exception ex) {message(ex instanceof IllegalArgumentException ? ex.getMessage() : "备份文件无效或无法读取，原有数据已保留");}
        });
    }
    @Override public void onRequestPermissionsResult(int request,String[] permissions,int[] grants) {
        super.onRequestPermissionsResult(request,permissions,grants);
        if (request == 70 && (grants.length == 0 || grants[0] != PackageManager.PERMISSION_GRANTED)) message("通知未开启，完成提醒可能无法显示。可在系统设置中开启。");
    }
    @Override protected void onResume() {super.onResume();applyAppearance();}
    @Override public void onConfigurationChanged(Configuration config) {super.onConfigurationChanged(config);applyAppearance();}
    @Override public void cleanUpFlutterEngine(FlutterEngine engine) {if (channel != null) {channel.setMethodCallHandler(null);channel = null;}super.cleanUpFlutterEngine(engine);}
    @Override protected void onDestroy() {worker.shutdown();super.onDestroy();}
}
