package com.shiguang.focus;

/** Standalone JVM regression test; compile alongside NotificationContent.java. */
public final class NotificationContentTest {
    private static int checks;
    private static void check(boolean ok, String label) {
        if (!ok) throw new AssertionError(label);
        System.out.println("PASS " + label);
        checks++;
    }
    public static void main(String[] args) {
        long now = 1792764000000L;
        NotificationContent down = NotificationContent.from(true,true,true,7071001L,now);
        check(down.live && down.when == now + 7071001L, "running countdown targets exact remaining time");
        check(!down.text.matches(".*[0-9].*") && !down.text.contains(":"), "running countdown does not contain a second frozen clock");
        NotificationContent up = NotificationContent.from(true,true,false,65234L,now);
        check(up.live && up.when == now - 65234L, "running stopwatch anchors exact elapsed time");
        check(!up.text.matches(".*[0-9].*"), "running stopwatch does not contain a second frozen clock");
        NotificationContent pausedDown = NotificationContent.from(true,false,true,7071001L,now);
        check(!pausedDown.live && pausedDown.when == 0, "pause hides the system chronometer");
        check(pausedDown.text.endsWith("01:57:52"), "paused countdown rounds up like app display");
        NotificationContent pausedUp = NotificationContent.from(true,false,false,65234L,now);
        check(!pausedUp.live && pausedUp.text.endsWith("00:01:05"), "paused stopwatch rounds down like app display");
        NotificationContent resumed = NotificationContent.from(true,true,true,7071001L,now+10000L);
        check(resumed.when == down.when + 10000L && resumed.live, "resume excludes paused time from countdown deadline");
        NotificationContent zero = NotificationContent.from(true,false,true,-200L,now);
        check(zero.text.endsWith("00:00:00"), "negative remaining time clamps to zero");
        NotificationContent idle = NotificationContent.from(false,false,false,0L,now);
        check(!idle.live && !idle.text.matches(".*[0-9].*"), "idle state contains no misleading timer");
        NotificationContent later = NotificationContent.from(true,true,true,7061001L,now+10000L);
        check(later.when == down.when, "same running countdown retains deadline across snapshots");
        System.out.println("ALL " + checks + " NOTIFICATION CHECKS PASSED");
    }
}
