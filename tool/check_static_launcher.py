"""Check upgrades retain a launcher regardless of the 2.0.8 saved icon choice.

Component enabled overrides survive APK replacement. Removing aliases would
strand existing light/dark installs; toggling them at runtime reintroduces the
vendor launcher behavior that this release deliberately removes.
"""
from pathlib import Path
import xml.etree.ElementTree as ET

project = Path(__file__).resolve().parent.parent
res = project/'android/app/src/main/res'
namespace = '{http://schemas.android.com/apk/res/android}'
app = ET.parse(project/'android/app/src/main/AndroidManifest.xml').getroot().find('application')
aliases = {entry.get(namespace+'name'): entry for entry in app.findall('activity-alias')}
activities = {entry.get(namespace+'name'): entry for entry in app.findall('activity')}
names = ['.MainActivity', '.LauncherLight', '.LauncherDark']
checks = 0
for previous in [None, *names]:
    # None: fresh install / original 2.0.7; otherwise PM override from 2.0.8.
    enabled = [name for name, entry in aliases.items()
               if (name == previous if previous else entry.get(namespace+'enabled','true') == 'true')]
    assert len(enabled) == 1, (previous, enabled)
    chosen = aliases[enabled[0]]
    assert chosen.get(namespace+'targetActivity') in activities
    target = activities[chosen.get(namespace+'targetActivity')]
    assert target.get(namespace+'enabled','true') == 'true'
    assert chosen.get(namespace+'icon') == '@mipmap/ic_launcher'
    actions = {item.get(namespace+'name') for item in chosen.findall('intent-filter/action')}
    categories = {item.get(namespace+'name') for item in chosen.findall('intent-filter/category')}
    assert 'android.intent.action.MAIN' in actions
    assert 'android.intent.category.LAUNCHER' in categories
    checks += 1
    print('PASS upgrade launcher:', previous or 'fresh / 2.0.7')
for name in names:
    assert name in aliases, 'A persisted enabled entry would be lost: '+name
assert app.get(namespace+'icon') == app.get(namespace+'roundIcon') == '@mipmap/ic_launcher'
assert '@drawable/ic_launcher_foreground' in (res/'mipmap-anydpi-v26/ic_launcher.xml').read_text(encoding='utf-8')
assert '#087DFF' in (res/'values/colors.xml').read_text(encoding='utf-8')
assert not list(res.glob('mipmap*night*/ic_launcher.xml')), 'Old icon must be identical in dark mode'
for source in (project/'android/app/src/main/java').rglob('*.java'):
    text = source.read_text(encoding='utf-8')
    for forbidden in ['setComponentEnabledSetting', 'setTaskDescription', 'LauncherIcons']:
        assert forbidden not in text, (source, 'Runtime icon mutation remains: '+forbidden)
assert 'new Intent(this,FocusActivity.class)' in (project/'android/app/src/main/java/com/shiguang/focus/FocusService.java').read_text(encoding='utf-8')
print(f'ALL {checks} UPGRADE LAUNCHER STATES VERIFIED; original static icon; no runtime component or task-icon mutation.')
