#!/usr/bin/env python3
"""flutter create ke baad Android project me internet + background play ke badlav lagata hai.

Repo ke root se chalao:  python3 tools/patch_android.py
"""
import glob
import re
import sys

MANIFEST = 'android/app/src/main/AndroidManifest.xml'

PERMISSIONS = [
    'INTERNET',
    'WAKE_LOCK',
    'FOREGROUND_SERVICE',
    'FOREGROUND_SERVICE_MEDIA_PLAYBACK',
    'POST_NOTIFICATIONS',
]

AUDIO_BLOCK = '''
        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>
'''


def patch_manifest():
    with open(MANIFEST, encoding='utf-8') as f:
        s = f.read()

    if 'xmlns:tools=' not in s:
        s = re.sub(r'<manifest\b', '<manifest xmlns:tools="http://schemas.android.com/tools"', s, count=1)

    add = ''.join(
        '    <uses-permission android:name="android.permission.%s"/>\n' % p
        for p in PERMISSIONS
        if 'android.permission.%s"' % p not in s
    )
    if add:
        m = re.search(r'^[ \t]*<application\b', s, re.M)
        if not m:
            sys.exit('ERROR: AndroidManifest.xml me <application> nahi mila')
        s = s[:m.start()] + add + s[m.start():]

    if 'com.ryanheise.audioservice.AudioService' not in s:
        i = s.rfind('</application>')
        if i < 0:
            sys.exit('ERROR: AndroidManifest.xml me </application> nahi mila')
        line_start = s.rfind('\n', 0, i) + 1
        s = s[:line_start] + AUDIO_BLOCK.lstrip('\n') + s[line_start:]

    with open(MANIFEST, 'w', encoding='utf-8') as f:
        f.write(s)
    print('OK: AndroidManifest.xml patch ho gaya')


def patch_activity():
    files = glob.glob('android/app/src/main/**/MainActivity.*', recursive=True)
    if not files:
        print('WARNING: MainActivity nahi mili: background play kaam na kare to yeh wajah hai')
        return
    for path in files:
        with open(path, encoding='utf-8') as f:
            t = f.read()
        n = (t.replace('io.flutter.embedding.android.FlutterActivity',
                       'com.ryanheise.audioservice.AudioServiceActivity')
              .replace('FlutterActivity', 'AudioServiceActivity'))
        if n == t and 'AudioServiceActivity' not in t:
            print('WARNING: %s me FlutterActivity nahi mila, badla nahi' % path)
            continue
        with open(path, 'w', encoding='utf-8') as f:
            f.write(n)
        print('OK: %s ab AudioServiceActivity use karti hai' % path)


if __name__ == '__main__':
    patch_manifest()
    patch_activity()
