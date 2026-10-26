"""Compile the actual widget model and color code against the Android SDK.

No device is needed. Android views aren't instantiated here; installation and
layout behavior on a vendor launcher still require an Android device.
"""
from pathlib import Path
import os
import subprocess
import xml.etree.ElementTree as ET

project = Path(__file__).resolve().parent.parent
workspace = project.parent.parent
root = project/'build/heatmap-checks'
src, classes = root/'src', root/'classes'
native = project/'android/app/src/main/java/com/shiguang/focus'
package = src/'com/shiguang/focus'
package.mkdir(parents=True,exist_ok=True)
for name in ['HeatmapModel.java','HeatmapWidget.java','HeatmapTiles.java','HeatmapReferenceLayout.java']:
    (package/name).write_bytes((native/name).read_bytes())
(package/'Repository.java').write_text('package com.shiguang.focus; public class Repository {public static Repository get(android.content.Context c){return null;}public String widgetSnapshot(){return "";}}',encoding='utf-8')
(package/'FocusActivity.java').write_text('package com.shiguang.focus; public class FocusActivity {}',encoding='utf-8')
res = project/'android/app/src/main/res'
a = '{http://schemas.android.com/apk/res/android}'
names = set()
for path in (res/'layout').glob('widget*.xml'):
    for item in ET.parse(path).iter():
        value = item.get(a+'id','')
        if value.startswith('@+id/'):
            names.add(value.split('/')[1])
r = ['package com.shiguang.focus; public final class R {']
for kind, values in [('id',sorted(names)),('layout',[p.stem for p in (res/'layout').glob('widget*.xml')]),('drawable',[p.stem for p in (res/'drawable').glob('widget*.xml')])]:
    r.append('public static final class '+kind+' {')
    for i, name in enumerate(values):r.append(f'public static final int {name}={i+1};')
    r.append('}')
r.append('}')
(package/'R.java').write_text('\n'.join(r),encoding='utf-8')
(package/'HeatmapTest.java').write_text(r'''package com.shiguang.focus;
import org.json.*;import java.time.*;import java.nio.file.*;
public class HeatmapTest {
 static int checks;
 static void ok(boolean value,String label){if(!value)throw new AssertionError(label);checks++;System.out.println("PASS "+label);}
 static long at(String date,ZoneId zone){return LocalDateTime.parse(date).atZone(zone).toInstant().toEpochMilli();}
 static JSONArray records(long... times)throws Exception{
   JSONArray segments=new JSONArray();for(int i=0;i<times.length;i+=2)segments.put(new JSONObject().put("start",times[i]).put("end",times[i+1]));
   return new JSONArray().put(new JSONObject().put("segments",segments));
 }
 public static void main(String[] args)throws Exception{
  long[] boundary={-1,0,1,3599999,3600000,10799999,10800000,21599999,21600000,28799999,28800000,86400000};
  int[] expected={0,0,1,1,2,2,3,3,4,4,5,5};
  for(int i=0;i<boundary.length;i++)ok(HeatmapModel.level(boundary[i])==expected[i],"threshold "+boundary[i]);
  ZoneId zone=ZoneId.of("Asia/Shanghai");LocalDate today=LocalDate.of(2026,10,26);
  HeatmapModel.Month month=HeatmapModel.month(records(at("2026-10-25T23:00",zone),at("2026-10-26T02:00",zone)),today);
  ok(month.days[24]==3600000&&month.days[25]==7200000&&month.total==10800000,"cross-midnight split");
  ok(month.focusedDays==2,"focused days counts calendar days");
  month=HeatmapModel.month(records(at("2026-09-30T23:00",zone),at("2026-10-01T02:00",zone),at("2026-10-31T23:00",zone),at("2026-11-01T02:00",zone)),today);
  ok(month.days[0]==7200000&&month.days[30]==3600000&&month.total==10800000,"month clipping");
  month=HeatmapModel.month(records(at("2026-10-26T00:00",zone),at("2026-10-26T01:00",zone),at("2026-10-26T05:00",zone),at("2026-10-26T06:00",zone)),today);
  ok(month.total==7200000,"paused gaps excluded");
  month=HeatmapModel.month(new JSONArray(),LocalDate.of(2021,2,28));
  ok(month.weeks==4&&month.days.length==28,"28 day month can span four weeks");
  month=HeatmapModel.month(new JSONArray(),LocalDate.of(2024,2,29));
  ok(month.days.length==29&&month.weeks==5,"leap February");
  month=HeatmapModel.month(new JSONArray(),LocalDate.of(2026,3,31));
  ok(month.weeks==6&&month.date(0,0).equals(LocalDate.of(2026,2,23))&&month.date(5,6).equals(LocalDate.of(2026,4,5)),"six week month and Monday-first dates");
  java.util.TimeZone originalZone=java.util.TimeZone.getDefault();
  try {
    java.util.TimeZone.setDefault(java.util.TimeZone.getTimeZone("America/New_York"));
    long begin=Instant.parse("2026-03-07T16:00:00Z").toEpochMilli();
    month=HeatmapModel.month(records(begin,begin+86400000),LocalDate.of(2026,3,9));
    ok(month.days[7]==86400000&&month.total==86400000,"Beijing days remain 24 hours with foreign system timezone");
    java.util.TimeZone.setDefault(java.util.TimeZone.getTimeZone("UTC"));
    HeatmapModel.Month same=HeatmapModel.month(records(begin,begin+86400000),LocalDate.of(2026,3,9));
    ok(java.util.Arrays.equals(month.days,same.days),"system timezone cannot change widget totals");
  } finally {java.util.TimeZone.setDefault(originalZone);}
  ok(HeatmapModel.todayAt(Instant.parse("2026-10-31T15:59:59Z")).equals(LocalDate.of(2026,10,31)),"before Beijing month boundary");
  ok(HeatmapModel.todayAt(Instant.parse("2026-10-31T16:00:00Z")).equals(LocalDate.of(2026,11,1)),"Beijing midnight changes month");
  ok(new HeatmapModel.Month(LocalDate.of(2026,10,26)).title().equals("10月热力"),"specific month title");
  ok(new HeatmapModel.Month(LocalDate.of(2027,1,1)).title().equals("1月热力"),"title updates across year boundary");
  for(String bad:new String[]{"shiguang://heatmap/2026-02-30","shiguang://heatmap/2026-10-27","shiguang://heatmap/2026-10-26?x=1","evil://heatmap/2026-10-26",null})
   ok(HeatmapModel.launchDate(bad,today)==null,"reject invalid widget URI "+bad);
  ok(HeatmapModel.launchDate("shiguang://heatmap/2024-02-29",today).equals(LocalDate.of(2024,2,29)),"valid date deep link");
  ok(HeatmapModel.dark("dark",false)&&!HeatmapModel.dark("light",true)&&HeatmapModel.dark("system",true)&&!HeatmapModel.dark("system",false),"app theme precedes system theme");
  for(boolean dark:new boolean[]{false,true}){
   java.util.HashSet<Integer> colors=new java.util.HashSet<>();
   for(int i=0;i<=5;i++)colors.add(HeatmapWidget.color(i,dark));
   ok(colors.size()==6,"six distinct shades, dark="+dark);
   ok(HeatmapWidget.color(5,dark)==(dark?0xff409aff:0xff087dff),"top band equals app blue, dark="+dark);
  }
  HeatmapReferenceLayout normal=new HeatmapReferenceLayout(220,164,5);
  ok(!normal.compact,"standard reference card uses regular cells");
  ok(new HeatmapReferenceLayout(220,140,6).compact,"six week small card adapts cell corners");
  ok(!new HeatmapReferenceLayout(180,110,4).compact,"short February keeps regular cells");
  ok(new HeatmapReferenceLayout(180,110,5).compact,"minimum five week card adapts cell corners");
  ok(Math.abs((normal.padX+normal.gapX)/normal.width-58f/906)<0.0001,"calendar horizontal inset follows reference");
  boolean readable=true;for(int weeks=4;weeks<=6;weeks++){HeatmapReferenceLayout m=new HeatmapReferenceLayout(180,110,weeks);readable&=m.day>0&&m.day<m.cellHeight;}
  ok(readable,"minimum card retains room for date numbers across four to six weeks");
  JSONArray demo=new JSONArray();int[] demoDays={5,9,10,11,12,13,15,16,17,20,21,22,23};int[] demoMinutes={120,180,180,480,180,54,360,360,360,360,360,180,360};
  for(int i=0;i<demoDays.length;i++){long begin=LocalDate.of(2026,10,demoDays[i]).atStartOfDay(zone).toInstant().toEpochMilli();demo.put(records(begin,begin+demoMinutes[i]*60000L).getJSONObject(0));}
  ok(HeatmapModel.month(demo,today).total==3534*60000L,"month summary uses the same records as blue heatmap");
  java.util.HashSet<Integer> backgroundIds=new java.util.HashSet<>();
  for(boolean compact:new boolean[]{false,true})for(boolean dark:new boolean[]{false,true})for(boolean selected:new boolean[]{false,true})for(int level=0;level<=5;level++)backgroundIds.add(HeatmapTiles.background(level,dark,selected,compact));
  ok(backgroundIds.size()==48,"all theme and density background states have explicit resources");
  // A design fixture for the preview, using actual native bucket and palette code.
  JSONObject preview=new JSONObject();JSONArray colors=new JSONArray();
  for(boolean dark:new boolean[]{false,true}){JSONArray row=new JSONArray();for(int i=0;i<=5;i++)row.put(String.format("#%06x",HeatmapWidget.color(i,dark)&0xffffff));colors.put(row);}
  preview.put("colors",colors);
  Files.writeString(Path.of(args[0]),preview.toString());
  System.out.println("ALL "+checks+" NATIVE HEATMAP CHECKS PASSED");
 }
}''',encoding='utf-8')
classes.mkdir(parents=True,exist_ok=True)
java = Path(os.environ.get('JAVA_HOME','C:/Program Files/Java/jdk-17'))/'bin'
jar = workspace/'work/json.jar'
android = workspace/'work/android-sdk/platforms/android-36/android.jar'
classpath = str(jar)+';'+str(android)
subprocess.run([str(java/'javac.exe'),'-encoding','UTF-8','-classpath',classpath,'-d',str(classes),*map(str,src.rglob('*.java'))],check=True)
subprocess.run([str(java/'java.exe'),'-classpath',str(classes)+';'+classpath,'com.shiguang.focus.HeatmapTest',str(root/'preview.json')],check=True,timeout=30)
manifest = ET.parse(project/'android/app/src/main/AndroidManifest.xml').getroot()
receiver = next(item for item in manifest.find('application').findall('receiver') if item.get(a+'name')=='.HeatmapWidget')
assert receiver.get(a+'exported') == 'false'
info = ET.parse(res/'xml/widget_heatmap_info.xml').getroot()
assert info.get(a+'targetCellWidth') == '3' and info.get(a+'targetCellHeight') == '2'
assert info.get(a+'minWidth') == info.get(a+'minResizeWidth') == '180dp'
assert info.get(a+'minHeight') == info.get(a+'minResizeHeight') == '110dp'
assert int(info.get(a+'updatePeriodMillis'))>=1800000
assert 'PendingIntent.getActivity' in (native/'HeatmapWidget.java').read_text(encoding='utf-8')
print('Private widget provider, 3x2 metadata, periodic update and direct activity launch verified.')

layout=ET.parse(res/'layout/widget_heatmap_reference.xml').getroot()
container=next(item for item in layout if item.get(a+'id')=='@+id/widget_weeks')
assert container.get(a+'orientation')=='vertical'
week=ET.parse(res/'layout/widget_heatmap_week.xml').getroot()
assert week.get(a+'orientation')=='horizontal' and week.get(a+'layout_width')=='match_parent'
assert week.get(a+'layout_height')=='0dp' and week.get(a+'layout_weight')=='1'
cell=ET.parse(res/'layout/widget_heatmap_cell_reference.xml').getroot()
assert cell.get(a+'layout_width')=='0dp' and cell.get(a+'layout_weight')=='1'
ids={item.get(a+'id') for item in layout.iter()}
assert {'@+id/widget_title','@+id/widget_stats','@+id/widget_hours','@+id/widget_minutes','@+id/widget_weekdays'}.issubset(ids)
assert layout.get(a+'weightSum')=='572'
print('Reference title, live month summary, weekday header and calendar rows verified.')

import json
palette=json.loads((root/'preview.json').read_text(encoding='utf-8'))['colors']
for compact in [False,True]:
    for dark in [False,True]:
        for today in [False,True]:
            for level in range(6):
                name=f'widget_day_{"compact" if compact else "normal"}_{"dark" if dark else "light"}_{"today" if today else "plain"}_{level}.xml'
                shape=ET.parse(res/'drawable'/name).getroot()
                assert shape.find('solid').get(a+'color')==palette[int(dark)][level]
                assert shape.find('corners').get(a+'radius')==('3dp' if compact else '4dp')
                assert (shape.find('stroke') is not None)==today
                if today:assert shape.find('stroke').get(a+'color')=='#FFFFFF'
print('All 48 native backgrounds match the live palette and fixed corner radii.')
