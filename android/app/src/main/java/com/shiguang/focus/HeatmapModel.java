package com.shiguang.focus;

import org.json.JSONArray;
import org.json.JSONObject;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;

/** Shared widget data rules, independent of Android views and timer lifecycles. */
final class HeatmapModel {
    static int level(long ms) {
        return ms <= 0 ? 0 : ms < 3600000 ? 1 : ms < 10800000 ? 2 : ms < 21600000 ? 3 : ms < 28800000 ? 4 : 5;
    }
    static boolean dark(String preference, boolean systemDark) {
        return "dark".equals(preference) || (!"light".equals(preference) && systemDark);
    }
    static LocalDate launchDate(String uri, LocalDate today) {
        final String prefix = "shiguang://heatmap/";
        try {
            if (uri == null || !uri.startsWith(prefix)) return null;
            String text = uri.substring(prefix.length());
            LocalDate date = LocalDate.parse(text);
            return date.toString().equals(text) && date.getYear() >= 2000 && !date.isAfter(today) ? date : null;
        } catch (RuntimeException ignored) {return null;}
    }
    static final class Month {
        final LocalDate first, today, gridStart;
        final long[] days;
        final int weeks;
        long total;
        int focusedDays;
        Month(LocalDate today) {
            this.today = today;
            first = today.withDayOfMonth(1);
            gridStart = first.minusDays(first.getDayOfWeek().getValue() - 1);
            days = new long[first.lengthOfMonth()];
            weeks = (first.getDayOfWeek().getValue() - 1 + days.length + 6) / 7;
        }
        LocalDate date(int week, int weekday) {return gridStart.plusDays(week * 7L + weekday);}
        boolean contains(LocalDate date) {return date.getYear() == first.getYear() && date.getMonth() == first.getMonth();}
        long duration(LocalDate date) {return contains(date) ? days[date.getDayOfMonth() - 1] : 0;}
    }
    static Month month(JSONArray records, LocalDate today, ZoneId zone) {
        Month month = new Month(today);
        long lower = month.first.atStartOfDay(zone).toInstant().toEpochMilli();
        long upper = month.first.plusMonths(1).atStartOfDay(zone).toInstant().toEpochMilli();
        for (int i = 0; i < records.length(); i++) {
            JSONObject record = records.optJSONObject(i);
            if (record == null) continue;
            JSONArray segments = record.optJSONArray("segments");
            if (segments == null) continue;
            for (int j = 0; j < segments.length(); j++) {
                JSONObject segment = segments.optJSONObject(j);
                if (segment == null) continue;
                long start = Math.max(lower, segment.optLong("start"));
                long end = Math.min(upper, segment.optLong("end"));
                while (start < end) {
                    LocalDate date = Instant.ofEpochMilli(start).atZone(zone).toLocalDate();
                    long next = Math.min(end, date.plusDays(1).atStartOfDay(zone).toInstant().toEpochMilli());
                    month.days[date.getDayOfMonth() - 1] += next - start;
                    start = next;
                }
            }
        }
        for (long ms : month.days) {month.total += ms;if (ms > 0) month.focusedDays++;}
        return month;
    }
}
