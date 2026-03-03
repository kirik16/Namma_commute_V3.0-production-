# 🚗 Namma Commute — Bengaluru Traffic & Commute App

A Flutter app addressing Bengaluru's most pressing urban mobility crisis.

## 🏙️ Problem Statement

Bengaluru loses **$6 billion/year** in productivity due to traffic congestion.
- Average commuter wastes **243 hours/year** stuck in traffic
- Silk Board, Marathahalli, and Hebbal are among Asia's worst junctions
- 12 million+ daily commuters lack a single unified real-time platform
- No centralized citizen-incident reporting system exists

## 📱 App Features

| Screen | Features |
|--------|----------|
| 🏠 Home | Real-time City Traffic Index, Top 5 Hotspots, Weather Alerts |
| 🚦 Live Traffic | All incidents mapped by type, severity filter, avoid-route suggestion |
| 🚇 Namma Metro | Purple/Green line schedules, next train times, station map |
| ⚠️ Report | Citizen incident reporting with upvoting community feed |
| 🆘 SOS | Emergency alert button, emergency helplines, accident guidance |

## 🛠️ Build APK Instructions

### Prerequisites
```bash
# 1. Install Flutter SDK
# https://docs.flutter.dev/get-started/install

flutter --version   # Confirm ≥ 3.0.0

# 2. Install Android Studio + Android SDK
# Set ANDROID_HOME environment variable

# 3. Accept licenses
flutter doctor --android-licenses
```

### Steps to Build APK
```bash
# Clone / unzip the project
cd namma_commute

# Get dependencies
flutter pub get

# Build debug APK (quick test)
flutter build apk --debug

# Build release APK (optimized)
flutter build apk --release

# APK location after build:
# build/app/outputs/flutter-apk/app-release.apk
```

### Install on Device
```bash
# Connect Android device with USB debugging ON
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Build App Bundle (for Play Store)
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

## 🎨 Design Language

- **Primary:** `#E8581C` — Bengaluru bus orange
- **Accent:** `#00C9A7` — Namma Metro teal
- **Emergency:** `#FF2D55` — Alert red
- **Background:** `#0F0F1A` — Deep midnight
- **Font:** Plus Jakarta Sans (Google Fonts)
- **Style:** Dark UI with glassmorphism cards, animated live indicators

## 📁 Project Structure

```
lib/
├── main.dart                    # App entry, theme, navigation shell
└── screens/
    ├── home_screen.dart         # Dashboard, traffic index, hotspots
    ├── live_traffic_screen.dart # Real-time incident feed
    ├── namma_metro_screen.dart  # Metro line viewer & schedules
    ├── report_screen.dart       # Citizen issue reporting
    └── sos_screen.dart          # Emergency SOS + contacts
```

## 🔮 Roadmap (Future)

- [ ] Google Maps integration with live route overlay
- [ ] Push notifications for hotspot alerts
- [ ] BMTC real-time bus tracking (GTFS feed)
- [ ] Carpooling match system
- [ ] BBMP API integration for pothole grievances
- [ ] Kannada / Tamil language support
