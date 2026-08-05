# Info.plist additions

After `flutter create .` generates `mobile/ios/Runner/Info.plist`, merge in the following key
inside the top-level `<dict>`:

```xml
<key>NSCameraUsageDescription</key>
<string>お題に応じた写真をその場で撮影するために使用します。</string>
```

**Do NOT add** `NSPhotoLibraryUsageDescription` or `NSPhotoLibraryAddUsageDescription`. Their
absence is intentional — without those keys, iOS will not let the app even prompt for photo
library access, which is how "in-app camera only, no gallery import" is enforced at the OS
permission layer (not just in app logic). See docs/DATA_MODEL.md / the design spec.

Also confirm `UIBackgroundModes` includes `remote-notification` (needed for reliable background
push delivery — Flutter's default template may already include this depending on version; add it
if missing):

```xml
<key>UIBackgroundModes</key>
<array>
  <string>remote-notification</string>
</array>
```
