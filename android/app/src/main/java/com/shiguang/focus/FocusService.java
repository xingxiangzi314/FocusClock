package com.shiguang.focus;

import android.app.*;
import android.content.*;
import android.os.*;
import org.json.JSONObject;

public class FocusService extends Service {
    private static final int RUNNING = 101, COMPLETE = 102;
    private static final String TIMER = "focus_timer", DONE = "focus_complete";
    private final Handler handler = new Handler(Looper.getMainLooper());
    private Repository repo;
    private PowerManager.WakeLock wakeLock;
    private boolean foreground;
    private final Runnable ticker = new Runnable() {
        @Override public void run() { if (update(false)) handler.postDelayed(this, 1000); }
    };
    @Override public void onCreate() {
        super.onCreate();repo = Repository.get(this);
        NotificationManager nm = getSystemService(NotificationManager.class);
        NotificationChannel low = new NotificationChannel(TIMER, "专注计时", NotificationManager.IMPORTANCE_LOW);
        low.setDescription("后台计时与暂停、继续、结束控制");low.setSound(null,null);low.setShowBadge(false);nm.createNotificationChannel(low);
        NotificationChannel done = new NotificationChannel(DONE, "专注完成", NotificationManager.IMPORTANCE_DEFAULT);
        done.setDescription("倒计时结束提醒");done.enableVibration(true);nm.createNotificationChannel(done);
        PowerManager pm = (PowerManager) getSystemService(POWER_SERVICE);
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "shiguang:countdown");wakeLock.setReferenceCounted(false);
    }
    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        // Even a stale notification action must immediately satisfy startForegroundService.
        if (!foreground) { startForeground(RUNNING, notification());foreground = true; }
        if (intent != null && intent.getAction() != null) {
            String action = intent.getAction();
            if ("pause".equals(action) || "start".equals(action) || "finish".equals(action)) {
                boolean hadActive = repo.active() != null;
                String result = repo.command(action,new JSONObject());
                try {
                    if (hadActive && !new JSONObject(result).has("error")) Haptics.perform(this,repo.settings().optBoolean("haptics",true),repo.settings().optInt("hapticStrength",Haptics.DEFAULT_STRENGTH),"pause".equals(action)?"click":"confirm");
                } catch (org.json.JSONException ignored) {}
            }
        }
        handler.removeCallbacks(ticker);
        if (update(true)) handler.postDelayed(ticker,1000);
        return repo.active() == null ? START_NOT_STICKY : START_STICKY;
    }
    private boolean update(boolean force) {
        synchronized (repo) {
            repo.tick();
            if (repo.consumeCompletion()) completedNotification();
            JSONObject a = repo.active();
            if (a == null) {
                releaseWakeLock();if (foreground) stopForeground(STOP_FOREGROUND_REMOVE);foreground = false;stopSelf();return false;
            }
            boolean countdown = a.optBoolean("running") && "down".equals(a.optString("mode"));
            if (countdown && !wakeLock.isHeld()) wakeLock.acquire(Math.max(60000,a.optLong("targetMs") - repo.elapsed() + 60000));
            if (!countdown) releaseWakeLock();
            // SystemUI advances the chronometer. Repost only when timer state changes;
            // a second, periodically refreshed text clock can lag on Xiaomi devices.
            if (force) getSystemService(NotificationManager.class).notify(RUNNING,notification());
            return true;
        }
    }
    private PendingIntent openApp() {return PendingIntent.getActivity(this,0,new Intent(this,FocusActivity.class).setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP),PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);}
    private PendingIntent action(String a, int id) {return PendingIntent.getService(this,id,new Intent(this,FocusService.class).setAction(a),PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);}
    private Notification notification() {
        synchronized (repo) {
            JSONObject a = repo.active();boolean running = a != null && a.optBoolean("running");boolean down = a != null && "down".equals(a.optString("mode"));
            long elapsed = repo.elapsed();
            long ms = a == null ? 0 : down ? Math.max(0,a.optLong("targetMs") - elapsed) : elapsed;
            NotificationContent content = NotificationContent.from(a != null,running,down,ms,System.currentTimeMillis());
            Notification.Builder b = new Notification.Builder(this,TIMER).setSmallIcon(R.drawable.ic_stat).setColor(0xff087dff).setContentTitle(a == null ? "拾光 · 准备就绪" : a.optString("title") + (running ? " · 专注中" : " · 已暂停")).setContentText(content.text).setContentIntent(openApp()).setOnlyAlertOnce(true).setOngoing(true).setShowWhen(content.live).setUsesChronometer(content.live).setChronometerCountDown(down).setCategory(Notification.CATEGORY_STOPWATCH).setVisibility(Notification.VISIBILITY_PRIVATE);
            if (content.live) b.setWhen(content.when);
            b.addAction(new Notification.Action.Builder(R.drawable.ic_stat,running ? "暂停" : "继续",action(running ? "pause" : "start",1)).build());
            b.addAction(new Notification.Action.Builder(R.drawable.ic_stat,"结束并保存",action("finish",2)).build());
            return b.build();
        }
    }
    private void completedNotification() {
        if (!repo.settings().optBoolean("sound",true)) return;
        try {getSystemService(NotificationManager.class).notify(COMPLETE,new Notification.Builder(this,DONE).setSmallIcon(R.drawable.ic_stat).setColor(0xff087dff).setContentTitle("专注完成，做得很好").setContentText("本次专注已自动保存。站起来走走，给自己一个小休息吧。").setContentIntent(openApp()).setAutoCancel(true).setCategory(Notification.CATEGORY_REMINDER).build());}catch(SecurityException ignored){}
    }
    private void releaseWakeLock() {if (wakeLock != null && wakeLock.isHeld()) wakeLock.release();}
    @Override public void onDestroy() {handler.removeCallbacks(ticker);releaseWakeLock();super.onDestroy();}
    @Override public IBinder onBind(Intent intent) {return null;}
}
