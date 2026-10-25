package com.shiguang.focus;

import android.content.Context;
import android.media.AudioAttributes;
import android.os.Build;
import android.os.VibrationAttributes;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.os.VibratorManager;
import android.util.Log;

/** Short, independently controlled touch feedback for controls and notifications. */
final class Haptics {
    static final int DEFAULT_STRENGTH = 35;
    private Haptics() {}

    static void perform(Context context, boolean enabled, int strength, String kind) {
        if (!enabled || (!"click".equals(kind) && !"confirm".equals(kind))) return;
        try {
            Vibrator vibrator = null;
            if (Build.VERSION.SDK_INT >= 31) {
                VibratorManager manager = context.getSystemService(VibratorManager.class);
                if (manager != null) vibrator = manager.getDefaultVibrator();
            }
            if (vibrator == null) vibrator = (Vibrator) context.getSystemService(Context.VIBRATOR_SERVICE);
            if (vibrator == null || !vibrator.hasVibrator()) return;

            float level = Math.max(1, Math.min(100, strength)) / 100f;
            float scale = (float) (0.02 + 0.98 * Math.pow(level, 1.35));
            if ("confirm".equals(kind)) scale = Math.min(1f, scale * 1.12f);
            VibrationEffect effect = effect(vibrator, level, scale);
            // Explicit user-triggered interactive-media pulses retain independent app control.
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

    private static VibrationEffect effect(Vibrator vibrator, float level, float scale) {
        if (Build.VERSION.SDK_INT >= 30) {
            try {
                int primitive = Build.VERSION.SDK_INT >= 31
                    && vibrator.arePrimitivesSupported(VibrationEffect.Composition.PRIMITIVE_LOW_TICK)[0]
                    ? VibrationEffect.Composition.PRIMITIVE_LOW_TICK
                    : VibrationEffect.Composition.PRIMITIVE_TICK;
                if (vibrator.arePrimitivesSupported(primitive)[0]) {
                    return VibrationEffect.startComposition().addPrimitive(primitive, scale).compose();
                }
            } catch (RuntimeException unsupported) {
                // Fall back if an OEM reports primitives inconsistently.
            }
        }
        if (vibrator.hasAmplitudeControl()) {
            int peak = Math.max(1, Math.min(255, Math.round(255 * scale * scale)));
            return VibrationEffect.createWaveform(new long[]{2, 4, 2},
                new int[]{Math.max(1, peak / 2), peak, Math.max(1, peak / 5)}, -1);
        }
        // Legacy motors cannot scale amplitude, so use a 3–8ms pulse.
        return VibrationEffect.createOneShot(3 + Math.round(5 * level), VibrationEffect.DEFAULT_AMPLITUDE);
    }
}
