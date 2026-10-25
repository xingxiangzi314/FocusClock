"""Compile the production haptics class against recording Android doubles."""
from pathlib import Path
import os
import subprocess

project = Path(__file__).resolve().parent.parent
root = project / 'build/haptics-checks'
src, classes = root / 'src', root / 'classes'
files = {
'android/content/Context.java': '''package android.content;
public class Context { public static final String VIBRATOR_SERVICE="vibrator";
 public android.os.Vibrator legacy; public android.os.VibratorManager manager; public int calls;
 public <T>T getSystemService(Class<T> c){calls++;return c.cast(manager);}
 public Object getSystemService(String key){calls++;return legacy;} }''',
'android/os/Build.java': 'package android.os; public class Build { public static class VERSION { public static int SDK_INT=35; } }',
'android/os/VibratorManager.java': '''package android.os; public class VibratorManager {
 public Vibrator vibrator; public VibratorManager(Vibrator v){vibrator=v;} public Vibrator getDefaultVibrator(){return vibrator;} }''',
'android/os/VibrationEffect.java': '''package android.os;
public class VibrationEffect { public static final int DEFAULT_AMPLITUDE=-1;
 public int primitive=-1,amplitude,repeat; public float scale; public long duration; public long[] timings; public int[] amplitudes;
 public static boolean failComposition;
 public static Composition startComposition(){return new Composition();}
 public static class Composition { public static final int PRIMITIVE_LOW_TICK=8,PRIMITIVE_TICK=7;
  VibrationEffect e=new VibrationEffect(); public Composition addPrimitive(int p,float s){e.primitive=p;e.scale=s;return this;}
  public VibrationEffect compose(){if(failComposition)throw new UnsupportedOperationException();return e;} }
 public static VibrationEffect createWaveform(long[] t,int[] a,int repeat){VibrationEffect e=new VibrationEffect();e.timings=t;e.amplitudes=a;e.repeat=repeat;for(long x:t)e.duration+=x;return e;}
 public static VibrationEffect createOneShot(long t,int a){VibrationEffect e=new VibrationEffect();e.duration=t;e.amplitude=a;return e;} }''',
'android/os/Vibrator.java': '''package android.os;
public class Vibrator { public boolean present=true,amplitudeControl=true,low=true,tick=true,probeFails=false,playFails=false;
 public int count,probes; public VibrationEffect effect; public Object attributes;
 public boolean hasVibrator(){return present;} public boolean hasAmplitudeControl(){return amplitudeControl;}
 public boolean[] arePrimitivesSupported(int... ids){probes++;if(probeFails)throw new UnsupportedOperationException();boolean[] r=new boolean[ids.length];for(int i=0;i<ids.length;i++)r[i]=ids[i]==8?low:tick;return r;}
 public void vibrate(VibrationEffect e,VibrationAttributes a){record(e,a);} public void vibrate(VibrationEffect e,android.media.AudioAttributes a){record(e,a);}
 private void record(VibrationEffect e,Object a){if(playFails)throw new SecurityException();effect=e;attributes=a;count++;} }''',
'android/os/VibrationAttributes.java': '''package android.os; public class VibrationAttributes {
 public static final int USAGE_MEDIA=19;public int usage; public static class Builder {int u;
 public Builder setUsage(int value){u=value;return this;} public VibrationAttributes build(){VibrationAttributes a=new VibrationAttributes();a.usage=u;return a;} } }''',
'android/media/AudioAttributes.java': '''package android.media; public class AudioAttributes {
 public static final int USAGE_MEDIA=1,CONTENT_TYPE_SONIFICATION=4;public int usage;
 public static class Builder {int u;public Builder setUsage(int v){u=v;return this;}public Builder setContentType(int v){return this;}
 public AudioAttributes build(){AudioAttributes a=new AudioAttributes();a.usage=u;return a;} } }''',
'android/util/Log.java': 'package android.util; public class Log { public static int warnings; public static int w(String t,String m,Throwable e){warnings++;return 0;} }',
}
for name, code in files.items():
    path = src / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(code, encoding='utf-8')
native = project / 'android/app/src/main/java/com/shiguang/focus/Haptics.java'
(src / 'com/shiguang/focus').mkdir(parents=True, exist_ok=True)
(src / 'com/shiguang/focus/Haptics.java').write_bytes(native.read_bytes())
(src / 'com/shiguang/focus/HapticsTest.java').write_bytes((project / 'tests/com/shiguang/focus/HapticsTest.java').read_bytes())
classes.mkdir(parents=True, exist_ok=True)
java = Path(os.environ.get('JAVA_HOME', 'C:/Program Files/Java/jdk-17')) / 'bin'
subprocess.run([str(java/'javac.exe'), '-encoding', 'UTF-8', '-d', str(classes), *map(str, src.rglob('*.java'))], check=True)
subprocess.run([str(java/'java.exe'), '-cp', str(classes), 'com.shiguang.focus.HapticsTest'], check=True)
