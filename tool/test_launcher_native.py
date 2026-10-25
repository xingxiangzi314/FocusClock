"""Execute the production launcher switching code with recording Android doubles."""
from pathlib import Path
import os
import subprocess
import xml.etree.ElementTree as ET

project = Path(__file__).resolve().parent.parent
root = project / 'build/launcher-checks'
src, classes = root / 'src', root / 'classes'
files = {
'android/os/Build.java': 'package android.os; public class Build {public static class VERSION {public static int SDK_INT=35;}}',
'android/content/ComponentName.java': '''package android.content; public class ComponentName {
 public final String name; public ComponentName(String pkg,String cls){name=cls;}
 @Override public int hashCode(){return name.hashCode();}
 @Override public boolean equals(Object o){return o instanceof ComponentName && name.equals(((ComponentName)o).name);} }''',
'android/content/Context.java': '''package android.content; public class Context {
 public final android.content.pm.PackageManager pm=new android.content.pm.PackageManager();
 public String getPackageName(){return "com.shiguang.focus";}
 public android.content.pm.PackageManager getPackageManager(){return pm;} }''',
'android/content/pm/PackageManager.java': '''package android.content.pm;
 import android.content.ComponentName; import java.util.*;
 public class PackageManager {
 public static final int COMPONENT_ENABLED_STATE_DEFAULT=0, COMPONENT_ENABLED_STATE_ENABLED=1, COMPONENT_ENABLED_STATE_DISABLED=2,DONT_KILL_APP=1;
 public final Map<ComponentName,Integer> states=new HashMap<>(); public final List<String> calls=new ArrayList<>();
 public boolean failDisable,failBatch;
 public static class ComponentEnabledSetting {
 public ComponentName c; public int state,flags;
 public ComponentEnabledSetting(ComponentName c,int s,int f){this.c=c;state=s;flags=f;} }
 public int getComponentEnabledSetting(ComponentName c){return states.getOrDefault(c,0);}
 public void setComponentEnabledSetting(ComponentName c,int s,int flags){
 if(flags!=DONT_KILL_APP)throw new AssertionError("Process kill requested");
 calls.add(c.name+":"+s);
 if(s==2 && failDisable){failDisable=false;throw new SecurityException("OEM failure");}
 states.put(c,s);
 if(enabledCount()<1)throw new AssertionError("No launchable entry during legacy update"); }
 public void setComponentEnabledSettings(List<ComponentEnabledSetting> changes){
 calls.add("batch"); if(failBatch)throw new SecurityException("Batch failure");
 for(ComponentEnabledSetting c:changes){if(c.flags!=DONT_KILL_APP)throw new AssertionError();states.put(c.c,c.state);}
 if(enabledCount()!=1)throw new AssertionError("Invalid batch state"); }
 public int enabledCount(){int count=0;for(String n:new String[]{"MainActivity","LauncherLight","LauncherDark"}){
 int v=getComponentEnabledSetting(new ComponentName("com.shiguang.focus","com.shiguang.focus."+n));
 if(v==1 || (v==0 && n.equals("MainActivity"))) count++;}return count;} }''',
'com/shiguang/focus/LauncherIconsTest.java': '''package com.shiguang.focus;
import android.content.*; import android.content.pm.PackageManager; import android.os.Build;
public class LauncherIconsTest {
 static int checks; static void check(boolean value){checks++;if(!value)throw new AssertionError("Check "+checks);}
 public static void main(String[] args){
 check(LauncherIcons.selection("system")==0);check(LauncherIcons.selection("light")==1);check(LauncherIcons.selection("dark")==2);check(LauncherIcons.selection("unknown")==0);
 for(int api:new int[]{26,32,33,35}){
 Build.VERSION.SDK_INT=api; Context c=new Context();
 LauncherIcons.apply(c,"system");check(c.pm.calls.isEmpty());
 for(String preference:new String[]{"dark","light","system","light","dark"}){
 LauncherIcons.apply(c,preference);check(c.pm.enabledCount()==1);
 String name=new String[]{"MainActivity","LauncherLight","LauncherDark"}[LauncherIcons.selection(preference)];
 check(c.pm.getComponentEnabledSetting(new ComponentName(c.getPackageName(),c.getPackageName()+"."+name))==1);
 int before=c.pm.calls.size();LauncherIcons.apply(c,preference);check(c.pm.calls.size()==before);
 }
 if(api<33)check(c.pm.calls.get(0).endsWith("LauncherDark:1"));else check(c.pm.calls.get(0).equals("batch"));
 }
 Build.VERSION.SDK_INT=26;Context legacy=new Context();legacy.pm.failDisable=true;
 try{LauncherIcons.apply(legacy,"dark");throw new AssertionError();}catch(SecurityException expected){}
 check(legacy.pm.enabledCount()==1);check(legacy.pm.getComponentEnabledSetting(new ComponentName(legacy.getPackageName(),legacy.getPackageName()+".LauncherDark"))==0);
 LauncherIcons.apply(legacy,"dark");check(legacy.pm.enabledCount()==1);
 Build.VERSION.SDK_INT=35;Context modern=new Context();modern.pm.failBatch=true;
 try{LauncherIcons.apply(modern,"dark");throw new AssertionError();}catch(SecurityException expected){}
 check(modern.pm.enabledCount()==1);modern.pm.failBatch=false;LauncherIcons.apply(modern,"dark");check(modern.pm.enabledCount()==1);
 System.out.println("ALL "+checks+" NATIVE LAUNCHER CHECKS PASSED"); }
}''',
}
for name, text in files.items():
    path = src / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding='utf-8')
(src/'com/shiguang/focus/LauncherIcons.java').write_bytes((project/'android/app/src/main/java/com/shiguang/focus/LauncherIcons.java').read_bytes())
classes.mkdir(parents=True, exist_ok=True)
java = Path(os.environ.get('JAVA_HOME', 'C:/Program Files/Java/jdk-17')) / 'bin'
subprocess.run([str(java/'javac.exe'), '-encoding', 'UTF-8', '-d', str(classes), *map(str, src.rglob('*.java'))], check=True)
subprocess.run([str(java/'java.exe'), '-cp', str(classes), 'com.shiguang.focus.LauncherIconsTest'], check=True)

# Upgrade identity, always-enabled activity, and matching resource variants.
manifest = ET.parse(project/'android/app/src/main/AndroidManifest.xml').getroot()
a = '{http://schemas.android.com/apk/res/android}'
app = manifest.find('application')
target = app.find('activity')
assert target.get(a+'name') == '.FocusActivity' and target.get(a+'enabled', 'true') == 'true'
aliases = app.findall('activity-alias')
assert len(aliases) == 3 and aliases[0].get(a+'name') == '.MainActivity'
assert [e.get(a+'enabled') for e in aliases] == ['true','false','false']
assert all(e.get(a+'targetActivity') == '.FocusActivity' for e in aliases)
assert 'new Intent(this,FocusActivity.class)' in (project/'android/app/src/main/java/com/shiguang/focus/FocusService.java').read_text(encoding='utf-8')
for variant in ['light','dark']:
    assert (project/f'android/app/src/main/res/drawable/ic_clock_{variant}.xml').is_file()
    assert (project/f'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_{variant}.xml').is_file()
assert '@drawable/ic_clock_dark' in (project/'android/app/src/main/res/mipmap-night-anydpi-v26/ic_launcher.xml').read_text()
print('Launcher aliases, notification entry, upgrade identity and day/night resources verified.')
