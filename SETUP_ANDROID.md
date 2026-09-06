# Setup FlixyGo for Android - Step by Step

## ✅ What's Already Done

I've made the following changes to make your app Android-compatible:

1. ✅ Added `media_kit_libs_android_video` for Android video support
2. ✅ Added `flutter_launcher_icons` for custom app icon
3. ✅ Updated AndroidManifest.xml with:
   - Internet permissions
   - Network state permissions
   - Wake lock for video playback
   - Screen orientation support
   - App name changed to "FlixyGo"
4. ✅ Video player already has cross-platform support
5. ✅ Orientation handling already compatible with Android

## 📋 Steps You Need to Complete

### Step 1: Install Dependencies
Open terminal in `c:\nitip\FlixyGo\flixygo` and run:

```bash
flutter clean
flutter pub get
```

### Step 2: Generate App Icon
Run this command to generate Android launcher icons from your logo:

```bash
flutter pub run flutter_launcher_icons
```

This will create all the required icon sizes in the Android drawable folders.

### Step 3: Check Android Setup
Verify Flutter can detect your Android device/emulator:

```bash
flutter devices
```

You should see your Android device or emulator listed.

### Step 4: Build APK
Try building the Android APK:

```bash
flutter build apk --debug --dart-define-from-file=supabase-keys.json
```

**Note:** The `--dart-define-from-file=supabase-keys.json` is required for Supabase to work.

### Step 5: Install on Android Device
If the build succeeds, install it on your device:

```bash
flutter install --dart-define-from-file=supabase-keys.json
```

Or run it directly:

```bash
flutter run --dart-define-from-file=supabase-keys.json
```

## 🔧 If You Encounter Errors

### Error: "flutter_launcher_icons command not found"
Try:
```bash
dart run flutter_launcher_icons
```

### Error: "No Android devices found"
1. Enable USB debugging on your phone (Settings → Developer Options → USB Debugging)
2. Or start an emulator from Android Studio
3. Verify with `flutter devices`

### Error: "Gradle build failed"
1. Update Android SDK: Open Android Studio → SDK Manager → Update all
2. Accept Android licenses: `flutter doctor --android-licenses`

### Error: Media kit related errors on Android
The app should work, but if you see media_kit errors:
1. Make sure `media_kit_libs_android_video` is installed
2. Check that `MediaKit.ensureInitialized()` is called in main.dart (already done)

## 🎯 What to Test on Android

Once the app is running on Android:

### Basic Functionality:
- [ ] App launches without crash
- [ ] Logo appears correctly (after icon generation)
- [ ] Login screen works
- [ ] Sign up works (username + password only)

### Main Features:
- [ ] Home page loads movies/anime/kdrama
- [ ] Can navigate between tabs (Movies, Anime, Kdrama)
- [ ] Detail pages open correctly
- [ ] Favorite page works
- [ ] Profile page works

### Video Player (Most Important!):
- [ ] Video player page opens
- [ ] Video loads and starts playing
- [ ] Play/pause button works
- [ ] Seek bar works (can drag to change position)
- [ ] Lock icon works (locks all controls except itself)
- [ ] Fullscreen button works
- [ ] **In fullscreen:**
  - [ ] Screen rotates to landscape automatically
  - [ ] Large play/pause button in center works
  - [ ] Rewind (<<) and Forward (>>) buttons work
  - [ ] Next episode button works (if applicable)
  - [ ] Progress bar shows and updates
  - [ ] Exit fullscreen returns to portrait
- [ ] Back button returns to detail page
- [ ] Episode selection works (for anime/kdrama)
- [ ] Comments load and display

### Network Features:
- [ ] Internet connection works (permissions OK)
- [ ] Video streams load (even over mobile data)
- [ ] Images load correctly

## 📱 Platform Differences to Expect

### Windows vs Android:

**Screen Size:**
- Windows: Large desktop window
- Android: Smaller phone/tablet screen
- Solution: App should adapt automatically (responsive design)

**Video Playback:**
- Both use media_kit but with different codec libraries
- Android may take slightly longer to buffer
- Should work the same otherwise

**Orientation:**
- Windows: Stays in one orientation (window-based)
- Android: Rotates to landscape in fullscreen
- Portrait mode for normal browsing

**Performance:**
- Android may be slower on older devices
- Video quality may auto-adjust based on network

## 🚀 Building Release APK

Once everything works in debug mode, create a release APK:

```bash
flutter build apk --release --dart-define-from-file=supabase-keys.json
```

The APK will be at:
```
build/app/outputs/flutter-apk/app-release.apk
```

You can share this APK file to install on other Android devices!

## 📂 Summary of Modified Files

1. **pubspec.yaml**
   - Added `media_kit_libs_android_video: ^1.3.6`
   - Added `flutter_launcher_icons: ^0.14.4`
   - Added launcher icon configuration

2. **android/app/src/main/AndroidManifest.xml**
   - Added INTERNET permission
   - Added ACCESS_NETWORK_STATE permission
   - Added WAKE_LOCK permission
   - App name: "FlixyGo"
   - Added sensor orientation support

3. **ANDROID_MIGRATION.md** (NEW)
   - Complete documentation of changes

4. **SETUP_ANDROID.md** (THIS FILE)
   - Step-by-step setup guide

## ❓ Need Help?

If you encounter any issues:
1. Check `ANDROID_MIGRATION.md` for troubleshooting
2. Run `flutter doctor` to check setup
3. Check Android Studio for SDK issues
4. Look at error messages in terminal

The app is now ready for Android! Just follow the steps above. 🎉
