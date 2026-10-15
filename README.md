# 🎵 ForgeMusic

**A listening room for your music and videos on Android.**

ForgeMusic is a Flutter-powered Android media player designed to bring local music, video playback, and YouTube listening together in one place. Enjoy media stored on your device, manage music metadata, and keep playback controls accessible through Android notifications.

[![Flutter](https://img.shields.io/badge/Flutter-Powered-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)](https://www.android.com/)
[![Language](https://img.shields.io/badge/Language-Dart-0175C2?logo=dart&logoColor=white)](https://dart.dev/)
[![Status](https://img.shields.io/badge/Status-In%20Development-orange)](https://github.com/Ibrahist/Forgemusic)

## ✨ Features

- 🎧 **Local Music Playback** — Listen to music stored on your Android device.
- 🎬 **Video Playback** — Enjoy video content alongside your music library.
- ▶️ **YouTube Listening** — Access YouTube playback for personal listening.
- 📚 **Media Library Scanning** — Scan your device for supported music and video files.
- 🏷️ **Metadata Editing** — Edit supported audio file tags, including files outside the app directory when the required Android permission is granted.
- 🔔 **Notification Playback Controls** — Access playback controls from the Android notification shade.
- 📱 **Android-Focused Experience** — Built with Flutter for Android devices.

## 🛠️ Built With

| Technology | Purpose |
|---|---|
| [Flutter](https://flutter.dev/) | Cross-platform application framework |
| [Dart](https://dart.dev/) | Application programming language |
| Android SDK | Android platform integration |
| YouTube | Online media playback |

## 🚀 Getting Started

Follow these instructions to run ForgeMusic locally.

### Prerequisites

Make sure you have installed:

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Dart SDK](https://dart.dev/get-dart) (included with Flutter)
- [Android Studio](https://developer.android.com/studio) or another supported development environment
- Android SDK and an Android emulator or physical Android device
- [Git](https://git-scm.com/)

Verify your Flutter installation:

```bash
flutter doctor
```

### Installation

**1. Clone the repository**

```bash
git clone https://github.com/Ibrahist/Forgemusic.git
```

**2. Navigate to the project directory**

```bash
cd Forgemusic
```

**3. Install dependencies**

```bash
flutter pub get
```

**4. Run the application**

Connect an Android device or start an emulator, then run:

```bash
flutter run
```

### Build an APK

To generate a debug APK for testing:

```bash
flutter build apk --debug
```

The generated APK is typically available at:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

For a release build, run:

```bash
flutter build apk --release
```

Configure any required Android signing settings before distributing a production release.

## 📂 Project Structure

```text
Forgemusic/
├── android/               # Android platform configuration
├── assets/
│   └── fonts/             # Application fonts
├── lib/                   # Main Flutter application source
├── test/                  # Application tests
├── .gitignore             # Git ignore rules
├── .metadata              # Flutter project metadata
├── analysis_options.yaml  # Dart analysis configuration
├── pubspec.yaml            # Dependencies and project configuration
├── pubspec.lock            # Resolved dependency versions
└── README.md               # Project documentation
```

## 🔐 Permissions

ForgeMusic may request Android permissions to support its media features.

- **Media access:** Allows the app to scan and play supported local media.
- **Notification access:** Supports playback controls displayed in the notification shade.
- **All-files access:** Required for tag editing on supported files outside the application's own directory. Enable this permission through Android Settings when needed.

Grant only the permissions required for the features you use.

## 🧪 Testing

Run the Flutter test suite with:

```bash
flutter test
```

Check the project for Dart and Flutter issues with:

```bash
flutter analyze
```

## ⚠️ Responsible Use

- YouTube playback is intended for personal listening.
- Respect copyright laws and YouTube's applicable Terms of Service.
- Make sure you have permission to access, modify, or use media files.
- Downloaded media remains on the device, as described by the project.

## 🗺️ Roadmap

Potential areas for future development include:

- [ ] Improve music library organization and browsing.
- [ ] Enhance playback controls and user experience.
- [ ] Expand media metadata management.
- [ ] Improve application testing and reliability.
- [ ] Refine the Android user interface.

*Roadmap items are suggestions for future development, not a statement that these features are currently implemented.*

## 🤝 Contributing

Contributions, suggestions, and bug reports are welcome.

1. Fork the repository.
2. Create a feature branch:

   ```bash
   git checkout -b feature/your-feature
   ```

3. Commit your changes:

   ```bash
   git commit -m "Add your feature"
   ```

4. Push your branch:

   ```bash
   git push origin feature/your-feature
   ```

5. Open a pull request describing your changes.

For significant changes, consider opening an issue first to discuss the proposed improvement.

## 🐛 Reporting Issues

If you encounter a bug or have a feature request, visit the [GitHub Issues](https://github.com/Ibrahist/Forgemusic/issues) page.

Include relevant error messages, reproduction steps, and your Android and Flutter versions where possible.

## 👨‍💻 Author

**Ibrahist**

- GitHub: [@Ibrahist](https://github.com/Ibrahist)
- Project: [ForgeMusic](https://github.com/Ibrahist/Forgemusic)

## 📄 License

Please refer to the repository for licensing information. No specific license is stated in this README.
