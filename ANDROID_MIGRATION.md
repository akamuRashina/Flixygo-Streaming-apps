# Android Migration Guide

## Changes Made for Android Compatibility

### 1. **App Icon Configuration**
- Added `flutter_launcher_icons` package to dev_dependencies
- Configured launcher icon using `assets/images/icon.png`
- Background color: `#18120C` (app theme color)

**To generate the icons, run:**
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

### 2. **Android Manifest Updates**
File: `android/app/src/main/AndroidManifest.xml`

**Permissions Added:**
- `INTERNET` - Required for video streaming
- `ACCESS_NETWORK_STATE` - Check network connectivity
- `WAKE_LOCK` - Keep screen on during video playback
- `USE_BIOMETRIC` - Already present for authentication

**Configuration Changes:**
- App label changed to "FlixyGo"
- Added `usesCleartextTraffic="true"` for HTTP video sources
- Added `screenOrientation="sensor"` for automatic rotation
- Added `requestLegacyExternalStorage="true"` for file access
- Added queries for HTTP/HTTPS intents

### 3. **Video Player Dependencies**
File: `pubspec.yaml`

**Added:**
- `media_kit_libs_android_video: ^1.3.6` - Android video codec support

**Existing (cross-platform):**
- `media_kit: ^1.1.10` - Core video player
- `media_kit_video: ^1.2.4` - Video rendering
- `media_kit_libs_windows_video: ^1.0.9` - Windows codecs
- `webview_flutter: ^4.9.0` - WebView for Android/iOS
- `webview_windows: ^0.4.0` - WebView for Windows (conditional)

### 4. **Video Player Implementation**
File: `lib/pages/video_player_page.dart`

**Features Already Implemented:**
- ✅ Cross-platform video playback using `media_kit`
- ✅ Landscape orientation for fullscreen (Android compatible)
- ✅ SystemChrome orientation handling with try-catch for safety
- ✅ Immersive mode for fullscreen video
- ✅ Platform detection for WebView (Windows vs Android)
- ✅ Lock screen functionality
- ✅ Custom video controls with play/pause/seek/fullscreen

### 5. **Platform-Specific Code**
The app already has proper platform detection:
- `Platform.isWindows` checks for Windows-specific features
- `kIsWeb` checks for web platform
- Try-catch blocks handle unsupported features gracefully

## Building for Android

### Prerequisites
1. Android SDK installed
2. Android device or emulator connected
3. Flutter configured for Android development

### Build Commands

**Debug APK:**
```bash
flutter build apk --debug
```

**Release APK:**
```bash
flutter build apk --release
```

**Install on device:**
```bash
flutter install
```

**Run on device:**
```bash
flutter run
```

### Build with Supabase Keys
```bash
flutter run --dart-define-from-file=supabase-keys.json
flutter build apk --release --dart-define-from-file=supabase-keys.json
```

## Testing Checklist

- [ ] App launches on Android device
- [ ] Login/signup works
- [ ] Home page loads movies/anime/kdrama
- [ ] Video player opens and plays video
- [ ] Landscape orientation works in fullscreen
- [ ] Lock screen feature works
- [ ] Controls (play/pause/seek) respond correctly
- [ ] Back button navigation works
- [ ] Profile page loads
- [ ] Comments section works
- [ ] Network requests succeed (check permissions)

## Known Platform Differences

### Windows vs Android:
1. **Video Player**: Both use `media_kit` but with platform-specific codec libraries
2. **WebView**: 
   - Windows: Uses `webview_windows` (WebView2)
   - Android: Uses `webview_flutter` (native WebView)
3. **Orientation**: Android supports forced orientation, Windows doesn't need it
4. **System UI**: Android can hide system bars, Windows uses standard windowing

## Troubleshooting

### Issue: Video not playing
- Check INTERNET permission in AndroidManifest.xml
- Verify `media_kit_libs_android_video` is installed
- Check video URL is accessible

### Issue: App crashes on start
- Ensure `MediaKit.ensureInitialized()` is called in main.dart
- Check Supabase keys are provided

### Issue: Orientation not changing
- Verify `screenOrientation="sensor"` in AndroidManifest.xml
- Check SystemChrome.setPreferredOrientations is called

### Issue: Icon not updating
- Run `flutter pub run flutter_launcher_icons`
- Clean and rebuild: `flutter clean && flutter build apk`

## Next Steps

1. Test on physical Android device
2. Optimize video buffering for mobile networks
3. Add adaptive UI for different screen sizes
4. Test on various Android versions (API 21+)
5. Consider adding offline download feature
6. Optimize app size with split APKs
