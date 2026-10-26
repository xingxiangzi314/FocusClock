package com.shiguang.focus;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.res.Configuration;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
import android.util.TypedValue;
import android.view.View;
import android.widget.RemoteViews;
import org.json.JSONObject;
import java.time.LocalDate;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;

/** A native RemoteViews widget: works without a Flutter engine or running timer. */
public final class HeatmapWidget extends AppWidgetProvider {
    private static final String REFRESH = "com.shiguang.focus.HEATMAP_REFRESH";
    private static final ExecutorService worker = Executors.newSingleThreadExecutor();
    private static final AtomicInteger revision = new AtomicInteger();
    private static final int[] ALPHA = {0, 51, 97, 148, 199, 255};

    static void requestUpdate(Context context) {
        try {
            if (AppWidgetManager.getInstance(context).getAppWidgetIds(new ComponentName(context, HeatmapWidget.class)).length > 0)
                context.sendBroadcast(new Intent(context, HeatmapWidget.class).setAction(REFRESH));
        } catch (RuntimeException ex) {Log.w("HeatmapWidget", "Widget refresh unavailable", ex);}
    }
    @Override public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        if (REFRESH.equals(action) || Intent.ACTION_DATE_CHANGED.equals(action) || Intent.ACTION_TIME_CHANGED.equals(action)
            || Intent.ACTION_TIMEZONE_CHANGED.equals(action) || Intent.ACTION_CONFIGURATION_CHANGED.equals(action)
            || Intent.ACTION_LOCALE_CHANGED.equals(action) || Intent.ACTION_MY_PACKAGE_REPLACED.equals(action)
            || Intent.ACTION_BOOT_COMPLETED.equals(action)) enqueue(context);
        else super.onReceive(context, intent);
    }
    @Override public void onUpdate(Context context, AppWidgetManager manager, int[] ids) {enqueue(context);}
    @Override public void onAppWidgetOptionsChanged(Context context, AppWidgetManager manager, int id, Bundle options) {enqueue(context);}
    private void enqueue(Context context) {
        final PendingResult result = goAsync();
        final Context app = context.getApplicationContext();
        final int token = revision.incrementAndGet();
        worker.execute(() -> {
            try {
                if (token != revision.get()) return;
                AppWidgetManager manager = AppWidgetManager.getInstance(app);
                int[] ids = manager.getAppWidgetIds(new ComponentName(app, HeatmapWidget.class));
                if (ids.length == 0) return;
                JSONObject data = new JSONObject(Repository.get(app).widgetSnapshot());
                LocalDate today = HeatmapModel.today();
                HeatmapModel.Month month = HeatmapModel.month(data.getJSONArray("sessions"), today);
                boolean systemDark = (app.getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES;
                boolean dark = HeatmapModel.dark(data.optString("theme"), systemDark);
                for (int id : ids) {
                    if (token != revision.get()) return;
                    Bundle options = manager.getAppWidgetOptions(id);
                    int pw = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH,220), ph = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT,164);
                    int lw = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH,pw), lh = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT,110);
                    RemoteViews portrait = render(app,month,dark,pw,ph);
                    RemoteViews views = pw == lw && ph == lh ? portrait : new RemoteViews(render(app,month,dark,lw,lh),portrait);
                    if (token == revision.get()) manager.updateAppWidget(id,views);
                }
            } catch (Exception ex) {Log.w("HeatmapWidget", "Keeping last widget view after refresh failure", ex);}
            finally {result.finish();}
        });
    }
    private static PendingIntent openDay(Context context, LocalDate date) {
        Intent intent = new Intent(context, FocusActivity.class)
            .setData(Uri.parse("shiguang://heatmap/" + date))
            .setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        return PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
    }
    static int color(int level, boolean dark) {
        if (level == 0) return dark ? 0xff2a2f39 : 0xffefedf0;
        int foreground = dark ? 0xff409aff : 0xff087dff, background = dark ? 0xff20242c : 0xfffffcfd;
        int alpha = ALPHA[level], value = 0xff000000;
        for (int shift : new int[]{0,8,16}) value |= ((((foreground >> shift) & 255) * alpha + ((background >> shift) & 255) * (255-alpha) + 127) / 255) << shift;
        return value;
    }
    private static int px(Context context, float dp) {return Math.round(dp*context.getResources().getDisplayMetrics().density);}
    private static void textSize(RemoteViews view, int id, float dp) {view.setTextViewTextSize(id,TypedValue.COMPLEX_UNIT_DIP,dp);}
    static RemoteViews render(Context context, HeatmapModel.Month month, boolean dark, int width, int height) {
        HeatmapReferenceLayout layout = new HeatmapReferenceLayout(width,height,month.weeks);
        int ink = dark ? 0xfff3f4f8 : 0xff191c22, muted = dark ? 0xff9ba2af : 0xff9b9b9b;
        RemoteViews views = new RemoteViews(context.getPackageName(),R.layout.widget_heatmap_reference);
        int background = dark ? R.drawable.widget_reference_dark : R.drawable.widget_reference_light;
        views.setInt(R.id.widget_root,"setBackgroundResource",background);
        views.setViewPadding(R.id.widget_root,px(context,layout.padX),px(context,layout.padTop),px(context,layout.padX),px(context,layout.padBottom));
        views.setTextColor(R.id.widget_title,dark ? 0xfff3f4f8 : 0xff000000);
        views.setTextViewText(R.id.widget_title,"本月专注");
        textSize(views,R.id.widget_title,layout.title);
        views.setTextViewText(R.id.widget_hours,Long.toString(month.total/3600000));
        views.setTextViewText(R.id.widget_minutes,Long.toString(month.total/60000%60));
        for (int value : new int[]{R.id.widget_hours,R.id.widget_minutes}) {views.setTextColor(value,dark ? 0xfff3f4f8 : 0xff000000);textSize(views,value,layout.number);}
        for (int unit : new int[]{R.id.widget_hours_unit,R.id.widget_minutes_unit}) {views.setTextColor(unit,muted);textSize(views,unit,layout.unit);}
        views.setViewPadding(R.id.widget_stats,0,0,px(context,layout.gapX),0);
        views.setContentDescription(R.id.widget_stats,String.format(Locale.CHINA,"本月专注 %d 小时 %d 分钟",month.total/3600000,month.total/60000%60));
        views.setOnClickPendingIntent(R.id.widget_root,openDay(context,month.today));
        views.removeAllViews(R.id.widget_weekdays);
        String[] labels = {"一","二","三","四","五","六","日"};
        for (String label : labels) {
            RemoteViews day = new RemoteViews(context.getPackageName(),R.layout.widget_heatmap_weekday);
            day.setTextViewText(R.id.widget_weekday_label,label);day.setTextColor(R.id.widget_weekday_label,muted);
            textSize(day,R.id.widget_weekday_label,layout.weekday);views.addView(R.id.widget_weekdays,day);
        }
        views.removeAllViews(R.id.widget_weeks);
        for (int week = 0; week < month.weeks; week++) {
            RemoteViews weekRow = new RemoteViews(context.getPackageName(),R.layout.widget_heatmap_week);
            for (int row = 0; row < 7; row++) {
                LocalDate date = month.date(week,row);
                RemoteViews cell = new RemoteViews(context.getPackageName(),R.layout.widget_heatmap_cell_reference);
                cell.setViewPadding(R.id.widget_cell,px(context,layout.gapX),px(context,layout.gapY),px(context,layout.gapX),px(context,layout.gapY));
                if (!month.contains(date)) cell.setViewVisibility(R.id.widget_cell,View.INVISIBLE);
                else {
                    boolean future = date.isAfter(month.today), today = date.equals(month.today);
                    long duration = month.duration(date);
                    int level = future ? 0 : HeatmapModel.level(duration);
                    cell.setInt(R.id.widget_cell_surface,"setBackgroundResource",HeatmapTiles.background(level,dark,today,layout.compact));
                    cell.setTextViewText(R.id.widget_cell_day,Integer.toString(date.getDayOfMonth()));
                    cell.setTextColor(R.id.widget_cell_day,future ? muted : level >= 3 ? 0xffffffff : ink);
                    textSize(cell,R.id.widget_cell_day,layout.day);
                    cell.setContentDescription(R.id.widget_cell,String.format(Locale.CHINA,"%d月%d日，%s",date.getMonthValue(),date.getDayOfMonth(),future ? "尚未到来" : "专注 " + duration/3600000 + " 小时 " + duration/60000%60 + " 分钟"));
                    if (!future) cell.setOnClickPendingIntent(R.id.widget_cell,openDay(context,date));
                }
                weekRow.addView(R.id.widget_week_cells,cell);
            }
            views.addView(R.id.widget_weeks,weekRow);
        }
        return views;
    }
}
