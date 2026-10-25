"""Reproducible vector artwork based on the supplied light/dark clock reference.

Android uses the native adaptive mask; SVGs provide editable design previews.
No runtime image decoding or external artwork dependency is needed.
"""
from pathlib import Path

project = Path(__file__).resolve().parent.parent
res = project / 'android/app/src/main/res'
design = project / 'design'
design.mkdir(exist_ok=True)

def write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding='utf-8')

def circle(x, y, r):
    return f'M{x-r},{y} a{r},{r} 0 1,0 {2*r},0 a{r},{r} 0 1,0 {-2*r},0'

for dark in (False, True):
    name = 'dark' if dark else 'light'
    bg = ['#262829', '#191b1d', '#0f1113'] if dark else ['#ffffff', '#fcfcfd', '#f1f3f6']
    ring_a = ['#171d24', '#56b9fa', '#203363'] if dark else ['#edf7ff', '#a5cfff', '#e6f4ff']
    ring_b = ['#24bffa', '#0755ff', '#47cefa'] if dark else ['#86d8ff', '#0561ff', '#9bdcff']
    hand = '#fafafa' if dark else '#242627'
    paths = [
        ('M32.15,69.87 A27,27 0 0,1 67.5,30.62', ring_a, (31, 70, 68, 30)),
        ('M78.27,42.16 A27,27 0 0,1 38.52,76.12', ring_b, (79, 42, 40, 79)),
    ]
    vector = ['<vector xmlns:android="http://schemas.android.com/apk/res/android" xmlns:aapt="http://schemas.android.com/aapt" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">']
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="18 18 72 72"><defs><linearGradient id="bg" x2=".8" y2="1"><stop stop-color="{bg[0]}"/><stop offset=".5" stop-color="{bg[1]}"/><stop offset="1" stop-color="{bg[2]}"/></linearGradient><linearGradient id="sphere" x1="0" y1="0" x2=".7" y2="1"><stop stop-color="#45e5f6"/><stop offset=".5" stop-color="#16abff"/><stop offset="1" stop-color="#0754f2"/></linearGradient></defs><rect x="18" y="18" width="72" height="72" rx="17" fill="url(#bg)"/>']
    for i, (path, colors, coords) in enumerate(paths):
        x1, y1, x2, y2 = coords
        vector.append(f'<path android:pathData="{path}" android:fillColor="@android:color/transparent" android:strokeWidth="2.8" android:strokeLineCap="round"><aapt:attr name="android:strokeColor"><gradient android:startX="{x1}" android:startY="{y1}" android:endX="{x2}" android:endY="{y2}" android:type="linear"><item android:offset="0" android:color="{colors[0]}"/><item android:offset="0.5" android:color="{colors[1]}"/><item android:offset="1" android:color="{colors[2]}"/></gradient></aapt:attr></path>')
        svg.append(f'<defs><linearGradient id="r{i}" gradientUnits="userSpaceOnUse" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}"><stop stop-color="{colors[0]}"/><stop offset=".5" stop-color="{colors[1]}"/><stop offset="1" stop-color="{colors[2]}"/></linearGradient></defs><path d="{path}" fill="none" stroke="url(#r{i})" stroke-width="2.8" stroke-linecap="round"/>')
    vector.append('<path android:pathData="M42,45 L54,55 L70,43" android:fillColor="@android:color/transparent" android:strokeColor="#18000000" android:strokeWidth="4" android:strokeLineCap="round" android:strokeLineJoin="round"/>')
    vector.append(f'<path android:pathData="M42,44 L54,54 L70,42" android:fillColor="@android:color/transparent" android:strokeColor="{hand}" android:strokeWidth="3" android:strokeLineCap="round" android:strokeLineJoin="round"/>')
    svg.append(f'<path d="M42,45 L54,55 L70,43" fill="none" stroke="#000" stroke-opacity=".09" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/><path d="M42,44 L54,54 L70,42" fill="none" stroke="{hand}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>')
    for x, y, radius in [(73.1, 34.9, 3.2), (54, 54, 3.1)]:
        vector.append(f'<path android:pathData="{circle(x, y+1, radius+0.6)}" android:fillColor="#16076af7"/>')
        vector.append(f'<path android:pathData="{circle(x, y, radius)}"><aapt:attr name="android:fillColor"><gradient android:startX="{x-radius}" android:startY="{y-radius}" android:endX="{x+radius*.7}" android:endY="{y+radius}" android:type="linear"><item android:offset="0" android:color="#45e5f6"/><item android:offset="0.5" android:color="#16abff"/><item android:offset="1" android:color="#0754f2"/></gradient></aapt:attr></path>')
        svg.append(f'<circle cx="{x}" cy="{y+1}" r="{radius+.6}" fill="#076af7" opacity=".09"/><circle cx="{x}" cy="{y}" r="{radius}" fill="url(#sphere)"/>')
    vector.append('</vector>')
    svg.append('</svg>')
    write(res/f'drawable/ic_clock_{name}.xml', '\n'.join(vector)+'\n')
    write(res/f'drawable/ic_clock_background_{name}.xml', f'<shape xmlns:android="http://schemas.android.com/apk/res/android"><gradient android:angle="315" android:startColor="{bg[0]}" android:centerColor="{bg[1]}" android:endColor="{bg[2]}"/></shape>\n')
    write(design/f'app_icon_{name}.svg', '\n'.join(svg)+'\n')
    adaptive = f'<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@drawable/ic_clock_background_{name}"/><foreground android:drawable="@drawable/ic_clock_{name}"/></adaptive-icon>\n'
    write(res/f'mipmap-anydpi-v26/ic_launcher_{name}.xml', adaptive)
    write(res/('mipmap-night-anydpi-v26' if dark else 'mipmap-anydpi-v26')/'ic_launcher.xml', adaptive)

print('Light/dark Android adaptive vectors and SVG design sources generated.')
