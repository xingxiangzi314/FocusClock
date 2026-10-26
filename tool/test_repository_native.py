from pathlib import Path
import subprocess
import os

project=Path(__file__).resolve().parent.parent
root=project/'build/repository-checks'
src=root/'src'
files={
'com/shiguang/focus/HeatmapWidget.java': 'package com.shiguang.focus; public class HeatmapWidget { public static int updates; public static void requestUpdate(android.content.Context context){updates++;} }',
'android/content/Context.java': '''package android.content;
public class Context {
 public static final int MODE_PRIVATE=0;
 private final SharedPreferences prefs=new SharedPreferences();
 public Context getApplicationContext(){return this;}
 public SharedPreferences getSharedPreferences(String name,int mode){return prefs;}
 public Object getContentResolver(){return null;}
}''',
'android/content/SharedPreferences.java': '''package android.content;
public class SharedPreferences {
 private String stored="";
 public String getString(String key,String fallback){return stored.isEmpty()?fallback:stored;}
 public Editor edit(){return new Editor();}
 public class Editor { private String value; public Editor putString(String k,String v){value=v;return this;}public boolean commit(){stored=value;return true;} }
}''',
'android/os/SystemClock.java': '''package android.os;
public class SystemClock { public static long value=1000000; public static long elapsedRealtime(){return value;} }''',
'android/provider/Settings.java': '''package android.provider;
public class Settings {public static class Global {public static int boot=1;public static int getInt(Object resolver,String key,int fallback){return boot;}}}''',
'android/util/Log.java': '''package android.util;public class Log {public static int e(String t,String m,Throwable e){e.printStackTrace();return 0;}}''',
'com/shiguang/focus/TestClock.java': '''package com.shiguang.focus;
public class TestClock {public static long now=1792713600000L;public static long now(){return now;}public static void advance(long ms){now+=ms;android.os.SystemClock.value+=ms;}}''',
'com/shiguang/focus/RepositoryTest.java': r'''package com.shiguang.focus;
import org.json.*;import android.content.Context;
public class RepositoryTest {
 static int checks=0;
 static void ok(boolean b,String label){if(!b)throw new AssertionError(label);checks++;System.out.println("PASS "+label);}
 static JSONObject command(Repository r,String c,String p)throws Exception {JSONObject result=new JSONObject(r.command(c,new JSONObject(p)));if(result.has("error"))throw new AssertionError(result);return result;}
 static JSONObject snapshot(Repository r)throws Exception{return new JSONObject(r.snapshot());}
 static void fresh()throws Exception{java.lang.reflect.Field f=Repository.class.getDeclaredField("instance");f.setAccessible(true);f.set(null,null);}
 public static void main(String[]args)throws Exception {
  fresh();Context context=new Context();Repository r=Repository.get(context);
  ok(snapshot(r).getJSONArray("tasks").length()==3,"initial tasks; no fabricated records");
  JSONObject s=command(r,"saveTask","{\"title\":\"Algorithm <practice>\",\"color\":\"#087dff\",\"icon\":\"code\",\"mode\":\"down\",\"minutes\":1}");String id=s.getString("selectedTaskId");
  ok(s.getJSONArray("tasks").length()==4,"create task");
  command(r,"start","{}");TestClock.advance(20000);ok(r.elapsed()==20000,"countdown elapsed uses monotonic time");
  command(r,"pause","{}");TestClock.advance(10000);ok(r.elapsed()==20000,"pause excludes break");
  command(r,"start","{}");TestClock.advance(45000);r.tick();s=snapshot(r);
  JSONObject record=s.getJSONArray("sessions").getJSONObject(0);
  ok(r.active()==null&&record.getLong("durationMs")==60000,"countdown auto completes and clamps overshoot");
  ok(record.getJSONArray("segments").length()==2&&record.getLong("endAt")-record.getLong("startAt")==70000,"two focus intervals preserve paused gap");
  ok(r.consumeCompletion()&&!r.consumeCompletion(),"completion event delivered once");
  command(r,"taskMode","{\"mode\":\"up\"}");command(r,"start","{}");TestClock.advance(65000);command(r,"finish","{}");
  ok(snapshot(r).getJSONArray("sessions").getJSONObject(1).getLong("durationMs")==65000,"stopwatch manual finish");
  int count=snapshot(r).getJSONArray("sessions").length();command(r,"start","{}");TestClock.advance(500);command(r,"finish","{}");ok(snapshot(r).getJSONArray("sessions").length()==count,"subsecond focus not counted");
  command(r,"start","{}");String denied=r.command("start",new JSONObject("{\"id\":\"read\"}"));ok(new JSONObject(denied).has("error"),"simultaneous tasks rejected");
  denied=r.command("doneTask",new JSONObject().put("id",id));ok(new JSONObject(denied).has("error"),"active task cannot be completed");
  command(r,"discard","{}");String data=r.backup();JSONObject validated=Repository.validatedBackup(new JSONObject(data));
  ok(validated.getJSONArray("sessions").length()==2&&validated.isNull("active"),"backup round trip");
  JSONObject bad=new JSONObject(data);bad.getJSONArray("sessions").getJSONObject(0).put("durationMs",999999);
  denied=r.command("restore",new JSONObject().put("data",bad));ok(new JSONObject(denied).has("error")&&snapshot(r).getJSONArray("sessions").length()==2,"invalid backup cannot overwrite current data");
  command(r,"deleteTask",new JSONObject().put("id",id).toString());ok(snapshot(r).getJSONArray("sessions").length()==2,"deleting task retains historical sessions");
  command(r,"restore",new JSONObject().put("data",validated).toString());ok(snapshot(r).getJSONArray("tasks").length()==4,"valid restore replaces full data");
  command(r,"setting","{\"key\":\"goal\",\"value\":90}");fresh();r=Repository.get(context);ok(r.settings().getInt("goal")==90&&snapshot(r).getJSONArray("sessions").length()==2,"persistent settings and sessions survive process reload");
  command(r,"start","{}");TestClock.advance(40000);r.tick();android.provider.Settings.Global.boot++;
  fresh();r=Repository.get(context);ok(r.active()!=null&&!r.active().getBoolean("running")&&r.elapsed()==40000,"device reboot pauses at last checkpoint");
  command(r,"discard","{}");command(r,"select","{\"id\":\"read\"}");command(r,"start","{}");TestClock.advance(86405000);r.tick();ok(r.active()==null&&snapshot(r).getJSONArray("sessions").getJSONObject(2).getLong("durationMs")==86400000,"stopwatch safety limit at 24 hours");
  command(r,"saveTask","{\"title\":\"=SUM(A1)\",\"color\":\"#087dff\",\"icon\":\"book\",\"mode\":\"up\",\"minutes\":25}");command(r,"start","{}");TestClock.advance(60000);command(r,"finish","{}");ok(r.csv().contains("\"'=SUM(A1)\""),"CSV escapes spreadsheet formulas");
  command(r,"reset","{}");ok(snapshot(r).getJSONArray("sessions").length()==0&&snapshot(r).getJSONArray("tasks").length()==3,"reset to clean initial state");
  for(String mode:new String[]{"up","down"}) {
   command(r,"taskMode",new JSONObject().put("mode",mode).toString());
   for(long ms:new long[]{0,9999,10000,10001}) {
    int before=snapshot(r).getJSONArray("sessions").length();command(r,"start","{}");TestClock.advance(ms);command(r,"finish","{}");
    ok(snapshot(r).getJSONArray("sessions").length()==before+(ms>10000?1:0),mode+" threshold at "+ms+"ms");
   }
  }
  int beforePause=snapshot(r).getJSONArray("sessions").length();
  command(r,"start","{}");TestClock.advance(5000);command(r,"pause","{}");TestClock.advance(60000);command(r,"start","{}");TestClock.advance(5000);command(r,"finish","{}");
  ok(snapshot(r).getJSONArray("sessions").length()==beforePause,"threshold excludes paused time: 10s focus plus 60s pause is not counted");
  command(r,"start","{}");TestClock.advance(10001);command(r,"pause","{}");TestClock.advance(60000);command(r,"finish","{}");
  ok(snapshot(r).getJSONArray("sessions").getJSONObject(beforePause).getLong("durationMs")==10001,"paused finish saves over-10s effective focus only");
  JSONObject legacy=snapshot(r);long begin=TestClock.now()-60000;
  legacy.getJSONArray("sessions").put(new JSONObject().put("id","legacy-short").put("taskId","learn").put("title","Legacy").put("color","#087dff").put("mode","up").put("startAt",begin).put("endAt",begin+5000).put("durationMs",5000).put("segments",new JSONArray().put(new JSONObject().put("start",begin).put("end",begin+5000))));
  ok(Repository.validatedBackup(legacy).getJSONArray("sessions").length()==legacy.getJSONArray("sessions").length(),"legacy short records remain importable");

  ok(r.settings().getInt("hapticStrength")==35,"new and reset settings default to gentle strength");
  command(r,"setting","{\"key\":\"hapticStrength\",\"value\":72}");fresh();r=Repository.get(context);
  ok(r.settings().getInt("hapticStrength")==72,"strength survives process reload");
  JSONObject exported=snapshot(r);
  ok(Repository.validatedBackup(exported).getJSONObject("settings").getInt("hapticStrength")==72,"backup round trip preserves strength");
  JSONObject oldBackup=new JSONObject(exported.toString());oldBackup.getJSONObject("settings").remove("hapticStrength");
  ok(Repository.validatedBackup(oldBackup).getJSONObject("settings").getInt("hapticStrength")==35,"old backups gain default strength");
  for(Object invalid:new Object[]{0,101,35.5,"60"}){
   String failed=r.command("setting",new JSONObject().put("key","hapticStrength").put("value",invalid));
   ok(new JSONObject(failed).has("error")&&r.settings().getInt("hapticStrength")==72,"invalid strength rejected atomically: "+invalid);
   JSONObject badStrength=new JSONObject(exported.toString());badStrength.getJSONObject("settings").put("hapticStrength",invalid);
   boolean rejected=false;try{Repository.validatedBackup(badStrength);}catch(Exception expected){rejected=true;}
   ok(rejected,"malformed backup strength rejected: "+invalid);
  }
  int oldCount=oldBackup.getJSONArray("sessions").length();
  context.getSharedPreferences("focus",0).edit().putString("state",oldBackup.toString()).commit();fresh();r=Repository.get(context);
  ok(r.settings().getInt("hapticStrength")==35&&snapshot(r).getJSONArray("sessions").length()==oldCount,"old installation migration preserves records");
  command(r,"reset","{}");ok(r.settings().getInt("hapticStrength")==35,"reset restores default strength");

  HeatmapWidget.updates=0;
  command(r,"setting","{\"key\":\"theme\",\"value\":\"dark\"}");ok(HeatmapWidget.updates==1,"theme change refreshes widget");
  command(r,"setting","{\"key\":\"goal\",\"value\":60}");ok(HeatmapWidget.updates==1,"unrelated preference does not rebuild widget");
  command(r,"start","{}");TestClock.advance(1600000);
  JSONObject widget=new JSONObject(r.widgetSnapshot());
  ok(r.active()!=null&&widget.getJSONArray("sessions").length()==0&&!widget.has("tasks")&&widget.getString("theme").equals("dark"),"widget snapshot is passive and excludes task data");
  int widgetBefore=HeatmapWidget.updates;r.tick();ok(r.active()==null&&HeatmapWidget.updates==widgetBefore+1,"automatic countdown completion refreshes widget");
  String widgetRecord=snapshot(r).getJSONArray("sessions").getJSONObject(0).getString("id");widgetBefore=HeatmapWidget.updates;
  command(r,"deleteSession",new JSONObject().put("id",widgetRecord).toString());ok(HeatmapWidget.updates==widgetBefore+1,"deleting record refreshes widget");
  command(r,"start","{}");TestClock.advance(20000);widgetBefore=HeatmapWidget.updates;command(r,"finish","{}");ok(HeatmapWidget.updates==widgetBefore+1,"manual finish refreshes widget");
  JSONObject widgetBackup=new JSONObject(r.backup());widgetBefore=HeatmapWidget.updates;command(r,"restore",new JSONObject().put("data",widgetBackup).toString());ok(HeatmapWidget.updates==widgetBefore+1,"restore refreshes widget");
  widgetBefore=HeatmapWidget.updates;command(r,"reset","{}");ok(HeatmapWidget.updates==widgetBefore+1,"reset refreshes widget");
  System.out.println("ALL "+checks+" NATIVE REPOSITORY CHECKS PASSED");
 }
}'''
}
for name,code in files.items():
    p=src/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(code,encoding='utf-8')
repo=(project/'android/app/src/main/java/com/shiguang/focus/Repository.java').read_text(encoding='utf-8')
# Instrument only the platform wall clock; all repository behavior is the actual app source.
(src/'com/shiguang/focus/Repository.java').write_text(repo.replace('System.currentTimeMillis()','TestClock.now()'),encoding='utf-8')
classes=root/'classes';classes.mkdir(parents=True,exist_ok=True)
java=Path(os.environ.get('JAVA_HOME','C:/Program Files/Java/jdk-17'))/'bin'
jar=Path(os.environ.get('JSON_JAR',str(project.parent.parent/'work/json.jar'))).resolve()
subprocess.run([str(java/'javac.exe'),'-encoding','UTF-8','-classpath',str(jar),'-d',str(classes),*[str(p) for p in src.rglob('*.java')]],check=True)
result=subprocess.run([str(java/'java.exe'),'-classpath',str(classes)+';'+str(jar),'com.shiguang.focus.RepositoryTest'],capture_output=True,text=True)
print(result.stdout,result.stderr)
(root/'results.txt').write_text(result.stdout+result.stderr,encoding='utf-8')
raise SystemExit(result.returncode)
