<div align="center">

# 🎬 FlixyGo

### Your Ultimate Streaming Platform for Movies, K-Dramas & Anime

<img src="assets/images/icon.png" alt="FlixyGo Logo" width="150" />

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
[![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com/)
[![Windows](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://www.android.com/)

<p align="center">
  <a href="#-features">Features</a> •
  <a href="#-screenshots">Screenshots</a> •
  <a href="#-installation">Installation</a> •
  <a href="#-tech-stack">Tech Stack</a> •
  <a href="#-team">Team</a>
</p>

---

**Experience seamless streaming with an elegant interface designed for movie lovers, K-Drama enthusiasts, and anime fans.**

[Download APK](https://github.com/yourusername/flixygo/releases) | [Report Bug](https://github.com/yourusername/flixygo/issues) | [Request Feature](https://github.com/yourusername/flixygo/issues)

</div>

---

## ✨ Features

### 🎥 **Content Library**
- **Movies** - Extensive collection of the latest and classic films
- **K-Dramas** - Popular Korean dramas with episode tracking
- **Anime** - Wide selection of anime series and movies
- **Multi-Episode Support** - Track and watch episodes seamlessly

### 📱 **User Experience**
- 🎨 **Beautiful UI** - Modern, intuitive interface with smooth animations
- 🌙 **Dark Theme** - Eye-friendly dark mode optimized for binge-watching
- 🔍 **Smart Search** - Find your favorite content quickly
- ⭐ **Favorites** - Save and organize your favorite shows
- 📝 **Comments** - Share your thoughts with the community
- 👤 **User Profiles** - Personalize your streaming experience

### 🎬 **Video Player**
- 📺 **Full HD Playback** - High-quality video streaming
- 🔄 **Landscape Mode** - Automatic rotation for fullscreen viewing
- 🔒 **Screen Lock** - Prevent accidental touches during playback
- ⏯️ **Playback Controls** - Play, pause, seek, rewind, and fast-forward
- ⏭️ **Next Episode** - Automatic navigation to next episode
- 🎚️ **Progress Tracking** - Resume watching from where you left off

### 🔐 **Authentication**
- 📧 **Secure Login** - Email and password authentication
- 🆕 **Sign Up** - Easy registration with username and password
- 🔄 **Password Recovery** - Reset forgotten passwords
- 👁️ **Biometric Login** - Fingerprint authentication support

### 💾 **Data Management**
- ☁️ **Cloud Sync** - Powered by Supabase for seamless data synchronization
- 📊 **Watch History** - Track your viewing progress
- 🔖 **Favorites List** - Quick access to saved content
- 💬 **Comment System** - Engage with other users

---

## 📸 Screenshots

<div align="center">

### 🏠 Home & Navigation
<img src="assets/design/home page.png" alt="Home Page" width="250" />
<img src="assets/design/navbar.png" alt="Navigation Bar" width="250" />
<img src="assets/design/favorite page.png" alt="Favorites" width="250" />

### 🎬 Content & Video Player
<img src="assets/design/movie detail page.png" alt="Movie Detail" width="250" />
<img src="assets/design/video player page.png" alt="Video Player" width="250" />
<img src="assets/design/video player detail page.png" alt="Player Controls" width="250" />

### 👤 User Interface
<img src="assets/design/Login and Sign up page.png" alt="Login" width="250" />
<img src="assets/design/profile page.png" alt="Profile" width="250" />
<img src="assets/design/anime dan kdrama detail page.png" alt="Anime Detail" width="250" />

</div>

---

## 🚀 Installation

### Prerequisites

- **Flutter SDK** >= 3.12.2
- **Dart SDK** >= 3.0.0
- **Android Studio** or **VS Code** with Flutter extensions
- **Android SDK** (for Android builds)
- **Git**

### 📦 Clone the Repository

```bash
git clone https://github.com/yourusername/flixygo.git
cd flixygo
```

### 🔧 Install Dependencies

```bash
flutter pub get
```

### 🔑 Configure Supabase

1. Create a `supabase-keys.json` file in the root directory:

```json
{
  "supabaseUrl": "your-supabase-url",
  "supabaseAnonKey": "your-supabase-anon-key"
}
```

2. Get your keys from [Supabase Dashboard](https://app.supabase.com/)

### 🎯 Run the App

#### For Android:
```bash
flutter run --dart-define-from-file=supabase-keys.json
```

#### For Windows:
```bash
flutter run -d windows --dart-define-from-file=supabase-keys.json
```

### 📱 Build APK (Android)

```bash
# Debug APK
flutter build apk --debug --dart-define-from-file=supabase-keys.json

# Release APK
flutter build apk --release --dart-define-from-file=supabase-keys.json
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### 🪟 Build Windows

```bash
flutter build windows --dart-define-from-file=supabase-keys.json
```

---

## 🛠️ Tech Stack

### **Frontend Framework**
- **Flutter** - Cross-platform UI framework
- **Dart** - Programming language

### **UI/UX**
- **Google Fonts** - Typography (Poppins)
- **Custom Animations** - Smooth transitions and effects
- **Material Design** - Modern design principles

### **Backend & Database**
- **Supabase** - Backend-as-a-Service
  - Authentication
  - PostgreSQL Database
  - Real-time subscriptions
  - Cloud Storage

### **Video Playback**
- **media_kit** - Cross-platform video player
- **media_kit_video** - Video rendering
- **media_kit_libs_windows_video** - Windows codec support
- **media_kit_libs_android_video** - Android codec support

### **Additional Libraries**
- **shared_preferences** - Local data persistence
- **path_provider** - File system access
- **url_launcher** - External link handling
- **webview_flutter** - In-app web views (Android)
- **webview_windows** - In-app web views (Windows)
- **file_picker** - File selection dialogs

---

## 🏗️ Project Structure

```
flixygo/
├── android/                    # Android-specific files
├── windows/                    # Windows-specific files
├── assets/
│   ├── images/                # App images and icons
│   └── design/                # Design mockups and screenshots
├── lib/
│   ├── models/                # Data models
│   ├── pages/                 # UI screens
│   │   ├── home_page.dart
│   │   ├── login_page.dart
│   │   ├── video_player_page.dart
│   │   ├── profile_page.dart
│   │   └── ...
│   ├── services/              # Business logic and API services
│   │   ├── auth_service.dart
│   │   ├── stream_service.dart
│   │   ├── comment_service.dart
│   │   └── ...
│   ├── theme/                 # App theming
│   │   └── app_theme.dart
│   ├── env.dart               # Environment configuration
│   └── main.dart              # App entry point
├── pubspec.yaml               # Dependencies
└── README.md                  # This file
```

---

## 🎨 Features in Detail

### 🔐 Authentication System
- Username/Password authentication
- Biometric login support
- Session management
- Secure password storage

### 📺 Video Streaming
- **Adaptive Streaming** - Adjusts quality based on connection
- **Multiple Sources** - Support for various streaming providers
- **Episode Management** - Track watched episodes
- **Auto-play Next** - Seamless episode transitions

### 💬 Community Features
- **Comment System** - Share thoughts on content
- **User Profiles** - Customizable profiles with avatars
- **Favorites** - Bookmark your favorite shows
- **Watch History** - Track viewing progress

### 🌐 Multi-Platform Support
- **Android** - Optimized for mobile devices (Android 14+)
- **Windows** - Full desktop experience (Windows 10/11)
- Responsive UI adapts to different screen sizes

---

## 🐛 Known Issues & Fixes

### Memory Issues (Low RAM Devices)
If you experience crashes on devices with 4GB RAM or less, the Gradle memory settings have been optimized:
- Max heap: 2GB (down from 8GB)
- Suitable for budget devices

### Icon Configuration
The app uses standard launcher icons for better compatibility across Android versions.

### Video Player
- Some streaming sources may require specific headers
- Embedded videos work with proper CORS configuration

For detailed troubleshooting, see our [docs](docs/) folder.

---

## 📝 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---

## 👥 Team

### **Digital Aegis Team**

<table align="center">
  <tr>
    <td align="center">
      <img src="https://ui-avatars.com/api/?name=Luthfi+Nur+Zaidan&background=DE903A&color=fff&size=100" alt="Luthfi Nur Zaidan" width="100" /><br />
      <b>Luthfi Nur Zaidan</b><br />
      <sub>Lead Developer</sub><br />
      <a href="https://instagram.com/lxthfyy_">
        <img src="https://img.shields.io/badge/Instagram-E4405F?style=flat&logo=instagram&logoColor=white" />
      </a>
    </td>
    <td align="center">
      <img src="https://ui-avatars.com/api/?name=Abhipraya+Samboga&background=DE903A&color=fff&size=100" alt="Abhipraya Samboga" width="100" /><br />
      <b>Abhipraya Samboga</b><br />
      <sub>UI/UX Designer</sub><br />
      <a href="https://instagram.com/_noctyr">
        <img src="https://img.shields.io/badge/Instagram-E4405F?style=flat&logo=instagram&logoColor=white" />
      </a>
    </td>
  </tr>
</table>

### 📧 Contact

- **Email:** Digitalaegis12@gmail.com
- **Instagram:** [@lxthfyy_](https://instagram.com/lxthfyy_) | [@_noctyr](https://instagram.com/_noctyr)

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## ⭐ Star History

If you like this project, please give it a ⭐ on GitHub!

[![Star History Chart](https://api.star-history.com/svg?repos=yourusername/flixygo&type=Date)](https://star-history.com/#yourusername/flixygo&Date)

---

## 🙏 Acknowledgments

- [Flutter Team](https://flutter.dev/) - Amazing cross-platform framework
- [Supabase](https://supabase.com/) - Backend infrastructure
- [Media Kit](https://github.com/alexmercerind/media_kit) - Video playback library
- [Google Fonts](https://fonts.google.com/) - Beautiful typography
- All content providers and sources

---

<div align="center">

### Made with ❤️ by Digital Aegis Team

**© 2024 FlixyGo. All Rights Reserved.**

[![Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?style=flat&logo=flutter)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Powered%20by-Dart-0175C2?style=flat&logo=dart)](https://dart.dev/)

[⬆ Back to Top](#-flixygo)

</div>
