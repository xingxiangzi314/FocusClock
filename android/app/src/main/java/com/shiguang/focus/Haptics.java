package com.shiguang.focus;

import android.app.Activity;
import android.content.Context;
import android.media.AudioAttributes;
import android.os.Build;
import android.os.VibrationAttributes;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.os.VibratorManager;
import android.util.Log;
import android.view.HapticFeedbackConstants;
import android.view.View;

/** Native touch feedback shared by WebView controls and notification actions. */
final class Haptics {
    private Haptics() {}

    static void perform(Context context, boolean enabled, String kind) {
        if (!enabled || (!"click".equals(kind) && !"confirm".equals(kind))) return;
        try {
            // The user explicitly controls feedback inside this app; never read or change
            // the phone's touch-feedback preference. The legacy override is public before 33.
            if (Build.VERSION.SDK_INT < 33 && context instanceof Activity) {
                View view = ((Activity) context).getWindow().getDecorView();
                int feedback = "confirm".equals(kind)
                    ? (Build.VERSION.SDK_INT >= 30 ? HapticFeedbackConstants.CONFIRM : HapticFeedbackConstants.LONG_PRESS)
                    : HapticFeedbackConstants.CONTEXT_CLICK;
                if (view.performHapticFeedback(feedback, HapticFeedbackConstants.FLAG_IGNORE_GLOBAL_SETTING | HapticFeedbackConstants.FLAG_IGNORE_VIEW_SETTING)) return;
            }
            Vibrator vibrator = null;
            if (Build.VERSION.SDK_INT >= 31) {
                VibratorManager manager = context.getSystemService(VibratorManager.class);
                if (manager != null) vibrator = manager.getDefaultVibrator();
            }
            if (vibrator == null) vibrator = (Vibrator) context.getSystemService(Context.VIBRATOR_SERVICE);
            if (vibrator == null || !vibrator.hasVibrator()) return;

            boolean confirm = "confirm".equals(kind);
            // A custom in-app pulse uses the interactive-media vibration category, separate
            // from system touch feedback. Global vibration, DND and OEM restrictions still apply.
            int amplitude = vibrator.hasAmplitudeControl() ? (confirm ? 180 : 110) : VibrationEffect.DEFAULT_AMPLITUDE;
            VibrationEffect effect = VibrationEffect.createOneShot(confirm ? 35 : 25, amplitude);
            if (Build.VERSION.SDK_INT >= 33) {
                vibrator.vibrate(effect, new VibrationAttributes.Builder().setUsage(VibrationAttributes.USAGE_MEDIA).build());
            } else {
                vibrator.vibrate(effect, new AudioAttributes.Builder().setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).setUsage(AudioAttributes.USAGE_MEDIA).build());
            }
        } catch (RuntimeException ex) {
            // Missing hardware or an OEM restriction must never interrupt the user's action.
            Log.w("FocusHaptics", "Touch feedback unavailable", ex);
        }
    }
}
