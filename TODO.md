# TODO: Change Package Name from com.requrr.mobile to com.requrr.app

## Completed Steps

1. ✅ **Update android/app/build.gradle.kts**
   - Changed `namespace = "com.requrr.mobile"` to `namespace = "com.requrr.app"`
   - Changed `applicationId = "com.requrr.mobile"` to `applicationId = "com.requrr.app"`

2. ✅ **Update android/app/src/main/AndroidManifest.xml**
   - Changed `android:name="com.requrr.mobile.MainActivity"` to `android:name="com.requrr.app.MainActivity"`

3. ✅ **Rename directory**
   - Renamed `android/app/src/main/kotlin/com/requrr/mobile/` to `android/app/src/main/kotlin/com/requrr/app/`

4. ✅ **Update MainActivity.kt**
   - Changed package declaration from `package com.requrr.mobile` to `package com.requrr.app`

5. ✅ **Update android/app/google-services.json**
   - Changed `"package_name": "com.requrr.mobile"` to `"package_name": "com.requrr.app"`

6. ✅ **Clean build artifacts**
   - Attempted to delete build directories (none existed)

7. ✅ **Rebuild the app**
   - Ran `flutter clean`
   - Ran `flutter pub get` (in progress)

## Next Steps
- Build the app to verify changes: `flutter build apk` or `flutter build appbundle`
- Test the app on a device/emulator to ensure functionality is intact
- Update Firebase project settings if necessary to match the new package name
- Update any other configurations or documentation that reference the old package name

## Notes
- Ensure Firebase configuration is updated accordingly if needed.
- Test the app after changes to confirm functionality.
