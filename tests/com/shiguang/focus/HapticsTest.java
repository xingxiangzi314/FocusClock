package com.shiguang.focus;

import android.content.Context;
import android.os.*;
import android.media.AudioAttributes;

public class HapticsTest {
    static int checks;
    static void ok(boolean value,String label){if(!value)throw new AssertionError(label);checks++;System.out.println("PASS "+label);}
    static void play(Context c,int strength){Haptics.perform(c,true,strength,"click");}
    public static void main(String[] args){
        Context c=new Context();Vibrator v=new Vibrator();c.manager=new VibratorManager(v);c.legacy=new Vibrator();
        Haptics.perform(c,false,35,"click");ok(c.calls==0,"disabled feedback does not touch hardware");
        Haptics.perform(c,true,35,"unknown");ok(c.calls==0,"unknown feedback is rejected");
        play(c,35);ok(v.effect.primitive==8,"supported hardware uses calibrated low tick");
        ok(v.effect.scale>0&&v.effect.scale<0.4,"default tick is light");
        ok(((VibrationAttributes)v.attributes).usage==VibrationAttributes.USAGE_MEDIA,"independent modern media category");
        play(c,1);float soft=v.effect.scale;play(c,35);float normal=v.effect.scale;play(c,100);
        ok(soft<normal&&normal<v.effect.scale&&v.effect.scale<=1,"strength scales monotonically across range");
        Haptics.perform(c,true,35,"confirm");ok(v.effect.primitive==8&&v.effect.scale>normal&&v.effect.scale<0.5,"confirmation stays a light tick");
        v.low=false;play(c,35);ok(v.effect.primitive==7,"unsupported low tick falls back to supported tick");
        v.low=true;Build.VERSION.SDK_INT=30;play(c,35);ok(c.legacy.effect.primitive==7,"API 30 never requests API 31 low tick");
        ok(c.legacy.attributes instanceof AudioAttributes&&((AudioAttributes)c.legacy.attributes).usage==AudioAttributes.USAGE_MEDIA,"compatible media attributes before API 33");
        Build.VERSION.SDK_INT=35;v.low=false;v.tick=false;play(c,35);
        ok(v.effect.timings!=null&&v.effect.duration<=10&&v.effect.repeat==-1,"unsupported primitives use a single short non-repeating envelope");
        int defaultPeak=v.effect.amplitudes[1];ok(defaultPeak>0&&defaultPeak<60,"default fallback amplitude is gentle");
        play(c,100);int strong=v.effect.amplitudes[1];play(c,1);
        ok(v.effect.amplitudes[1]<defaultPeak&&defaultPeak<strong,"fallback amplitude is adjustable");
        play(c,-100);ok(v.effect.amplitudes[1]>=1,"negative strength clamps safely");
        play(c,1000);ok(v.effect.amplitudes[1]<=255,"excessive strength clamps safely");
        Haptics.perform(c,true,100,"confirm");ok(v.effect.duration<=10,"confirmation fallback never returns to a long buzz");
        v.low=true;v.tick=true;VibrationEffect.failComposition=true;play(c,35);
        ok(v.effect.timings!=null,"OEM composition failure retains short fallback");VibrationEffect.failComposition=false;
        v.probeFails=true;play(c,35);ok(v.effect.timings!=null,"OEM support query failure retains short fallback");v.probeFails=false;
        Build.VERSION.SDK_INT=29;int probes=c.legacy.probes;play(c,35);
        ok(c.legacy.effect.timings!=null&&c.legacy.probes==probes,"API 29 uses waveform without primitive APIs");
        c.legacy.amplitudeControl=false;play(c,1);long shorter=c.legacy.effect.duration;play(c,100);
        ok(shorter<c.legacy.effect.duration&&c.legacy.effect.duration<=8,"legacy unscalable motors use 3 to 8ms pulses");
        ok(c.legacy.effect.amplitude==VibrationEffect.DEFAULT_AMPLITUDE,"legacy motor uses supported default amplitude");
        Build.VERSION.SDK_INT=26;play(c,35);ok(c.legacy.effect.duration<=8,"API 26 retains short compatible feedback");
        Build.VERSION.SDK_INT=35;c.manager=null;c.legacy.amplitudeControl=true;play(c,35);
        ok(c.legacy.effect.primitive==8,"missing manager falls back to vibrator service");
        c.legacy.present=false;int before=c.legacy.count;play(c,35);ok(c.legacy.count==before,"missing motor is a no-op");
        c.legacy.present=true;c.legacy.playFails=true;play(c,35);ok(android.util.Log.warnings==1,"OEM playback denial never breaks an action");
        c.legacy=null;play(c,35);ok(true,"missing vibration service never crashes");
        System.out.println("ALL "+checks+" NATIVE HAPTICS CHECKS PASSED (physical motor untested)");
    }
}
