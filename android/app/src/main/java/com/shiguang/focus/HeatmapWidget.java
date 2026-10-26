package com.shiguang.focus;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.RemoteViews;
import org.json.JSONObject;
import java.time.LocalDate;
import java.util.HashMap;
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
                RemoteViews views = render(app, month, HeatmapModel.dark(data.optString("theme"), systemDark));
                if (token == revision.get()) manager.updateAppWidget(ids, views);
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
    private static Bitmap tile(int color, boolean today, int blue) {
        Bitmap bitmap = Bitmap.createBitmap(48,48,Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);paint.setColor(color);
        canvas.drawRoundRect(new RectF(3,3,45,45),9,9,paint);
        if (today) {paint.setStyle(Paint.Style.STROKE);paint.setStrokeWidth(3);paint.setColor(blue);canvas.drawRoundRect(new RectF(3,3,45,45),9,9,paint);}
        return bitmap;
    }
    static RemoteViews render(Context context, HeatmapModel.Month month, boolean dark) {
        int ink = dark ? 0xfff3f4f8 : 0xff191c22, muted = dark ? 0xff9ba2af : 0xff7d808b, blue = dark ? 0xff409aff : 0xff087dff;
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget_heatmap);
        views.setInt(R.id.widget_root,"setBackgroundResource",dark ? R.drawable.widget_card_dark : R.drawable.widget_card_light);
        views.setTextColor(R.id.widget_title,ink);
        views.setTextViewText(R.id.widget_title,month.title());
        views.setOnClickPendingIntent(R.id.widget_root,openDay(context,month.today));
        views.removeAllViews(R.id.widget_weeks);
        HashMap<String,Bitmap> tiles = new HashMap<>();
        for (int week = 0; week < month.weeks; week++) {
            RemoteViews weekRow = new RemoteViews(context.getPackageName(),R.layout.widget_heatmap_week);
            for (int row = 0; row < 7; row++) {
                LocalDate date = month.date(week,row);
                RemoteViews cell = new RemoteViews(context.getPackageName(),R.layout.widget_heatmap_cell);
                if (!month.contains(date)) cell.setViewVisibility(R.id.widget_cell,View.INVISIBLE);
                else {
                    boolean future = date.isAfter(month.today), today = date.equals(month.today);
                    long duration = month.duration(date);
                    int level = future ? 0 : HeatmapModel.level(duration);
                    String key = level + ":" + today;
                    if (!tiles.containsKey(key)) tiles.put(key,tile(color(level,dark),today,blue));
                    cell.setImageViewBitmap(R.id.widget_cell_color,tiles.get(key));
                    cell.setTextViewText(R.id.widget_cell_day,Integer.toString(date.getDayOfMonth()));
                    cell.setTextColor(R.id.widget_cell_day,future ? muted : level >= 3 ? 0xffffffff : ink);
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
