#!/usr/bin/env python3
"""
Patch generated Android & iOS platform files to ensure the Riyo app has
the permissions/security settings it needs to talk to the backend.

Run this AFTER `flutter create` and BEFORE `flutter build` in CI.

Android
-------
- Ensures `<uses-permission android:name="android.permission.INTERNET"/>`
  in the MAIN AndroidManifest.xml (the generated debug/profile manifests
  already include it; we make the main one explicit so a future template
  change can't accidentally drop it).
- Sets `android:usesCleartextTraffic="true"` on the <application> tag,
  so the app can talk to http:// endpoints (InfinityFree's free host
  sometimes redirects to http and we want to be permissive for rf.gd).
- Adds `<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>`
  so the app can detect connectivity changes.

iOS
---
- Adds NSAppTransportSecurity to Info.plist allowing arbitrary loads
  (our backend is HTTPS, but the InfinityFree host's challenge flow
  occasionally serves mixed content, and being explicit avoids surprise
  ATS rejections).
- Adds a usage description for the network (good practice; required by
  some app review processes).
"""
import os
import re
import sys

ANDROID_MANIFEST = "android/app/src/main/AndroidManifest.xml"
IOS_INFO_PLIST = "ios/Runner/Info.plist"

def patch_android(path):
    if not os.path.exists(path):
        print(f"[android] {path} not found, skipping")
        return
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    # 1. Ensure <uses-permission ... INTERNET .../> in the main manifest.
    if "android.permission.INTERNET" not in text:
        # Insert as the first child of <manifest>.
        text = re.sub(
            r"(<manifest[^>]*>)",
            r'\1\n    <uses-permission android:name="android.permission.INTERNET"/>',
            text,
            count=1,
        )
        print("[android] added INTERNET permission")
    else:
        print("[android] INTERNET permission already present")

    # 2. Ensure ACCESS_NETWORK_STATE.
    if "android.permission.ACCESS_NETWORK_STATE" not in text:
        text = re.sub(
            r"(<manifest[^>]*>)",
            r'\1\n    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>',
            text,
            count=1,
        )
        print("[android] added ACCESS_NETWORK_STATE permission")
    else:
        print("[android] ACCESS_NETWORK_STATE already present")

    # 3. Ensure usesCleartextTraffic="true" on <application>.
    if "android:usesCleartextTraffic" not in text:
        # Add it as an attribute on the first <application ...> tag.
        text = re.sub(
            r"<application\b",
            '<application\n            android:usesCleartextTraffic="true"',
            text,
            count=1,
        )
        print("[android] set usesCleartextTraffic=true on <application>")
    else:
        print("[android] usesCleartextTraffic already set")

    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def patch_ios(path):
    if not os.path.exists(path):
        print(f"[ios] {path} not found, skipping")
        return
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    # Insert NSAppTransportSecurity before </dict> (the root one).
    # We add it after CFBundleName / CFBundleIdentifier if present, but
    # the safe simple insertion point is right before the final </dict>.
    if "NSAppTransportSecurity" in text:
        print("[ios] NSAppTransportSecurity already present")
    else:
        ats_block = """\t<key>NSAppTransportSecurity</key>
\t<dict>
\t\t<key>NSAllowsArbitraryLoads</key>
\t\t<true/>
\t</dict>
"""
        # Insert before the LAST </dict> in the file (root plist end).
        last_close = text.rfind("</dict>")
        if last_close == -1:
            print("[ios] could not find </dict> to insert ATS, skipping")
        else:
            text = text[:last_close] + ats_block + "\t" + text[last_close:]
            print("[ios] added NSAppTransportSecurity")

    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def main():
    targets = sys.argv[1:] if len(sys.argv) > 1 else ["android", "ios"]
    if "android" in targets:
        patch_android(ANDROID_MANIFEST)
    if "ios" in targets:
        patch_ios(IOS_INFO_PLIST)


if __name__ == "__main__":
    main()
