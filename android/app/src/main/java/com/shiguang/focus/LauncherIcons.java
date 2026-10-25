package com.shiguang.focus;

import android.content.ComponentName;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;
import java.util.ArrayList;
import java.util.List;

/** Switches launcher artwork without restarting the activity or process. */
final class LauncherIcons {
    private static final String[] NAMES = {"MainActivity", "LauncherLight", "LauncherDark"};

    static int selection(String preference) {
        return "light".equals(preference) ? 1 : "dark".equals(preference) ? 2 : 0;
    }

    static void apply(Context context, String preference) {
        PackageManager pm = context.getPackageManager();
        int target = selection(preference);
        ComponentName[] components = new ComponentName[NAMES.length];
        int[] previous = new int[NAMES.length];
        List<PackageManager.ComponentEnabledSetting> changes = new ArrayList<>();
        for (int i = 0; i < NAMES.length; i++) {
            components[i] = new ComponentName(context.getPackageName(), context.getPackageName() + "." + NAMES[i]);
            previous[i] = pm.getComponentEnabledSetting(components[i]);
            boolean enabled = previous[i] == PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                || (previous[i] == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT && i == 0);
            if (enabled != (i == target) && Build.VERSION.SDK_INT >= 33)
                changes.add(new PackageManager.ComponentEnabledSetting(components[i],
                    i == target ? PackageManager.COMPONENT_ENABLED_STATE_ENABLED : PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP));
        }
        if (Build.VERSION.SDK_INT >= 33) {
            if (!changes.isEmpty()) pm.setComponentEnabledSettings(changes);
            return;
        }
        // Older Android has no atomic batch. Enable the new entry first; roll
        // back if disabling an old entry fails, so the app stays launchable.
        boolean targetWasEnabled = previous[target] == PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            || (previous[target] == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT && target == 0);
        List<Integer> disabled = new ArrayList<>();
        try {
            if (!targetWasEnabled) pm.setComponentEnabledSetting(components[target], PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP);
            for (int i = 0; i < NAMES.length; i++) {
                if (i == target) continue;
                if (previous[i] == PackageManager.COMPONENT_ENABLED_STATE_ENABLED || (previous[i] == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT && i == 0)) {
                    pm.setComponentEnabledSetting(components[i], PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP);
                    disabled.add(i);
                }
            }
        } catch (RuntimeException ex) {
            // Restore an original entry before removing the replacement.
            for (int i : disabled) pm.setComponentEnabledSetting(components[i], previous[i], PackageManager.DONT_KILL_APP);
            if (!targetWasEnabled) pm.setComponentEnabledSetting(components[target], previous[target], PackageManager.DONT_KILL_APP);
            throw ex;
        }
    }
}
