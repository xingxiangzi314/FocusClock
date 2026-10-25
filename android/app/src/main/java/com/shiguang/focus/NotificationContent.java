package com.shiguang.focus;

import java.util.Locale;

/** One clock per notification: live system chronometer, or frozen paused text. */
final class NotificationContent {
    final String text;
    final boolean live;
    final long when;

    private NotificationContent(String text, boolean live, long when) {
        this.text = text;
        this.live = live;
        this.when = when;
    }

    static NotificationContent from(boolean hasTask, boolean running, boolean down, long ms, long now) {
        if (!hasTask) return new NotificationContent("点击返回拾光", false, 0);
        ms = Math.max(0, ms);
        if (running) {
            // Never duplicate the dynamic clock as a stale snapshot in contentText.
            return new NotificationContent(down ? "倒计时 · 结束后自动保存" : "正计时 · 每一秒都算数", true, now + (down ? ms : -ms));
        }
        // Match the app: round remaining countdown time up, elapsed stopwatch time down.
        long seconds = down ? (ms + 999) / 1000 : ms / 1000;
        String time = String.format(Locale.US, "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60);
        return new NotificationContent((down ? "倒计时已暂停 · 剩余 " : "正计时已暂停 · 已专注 ") + time, false, 0);
    }
}
