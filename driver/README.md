# Famba Driver

Flutter app for drivers — accept rides, navigate to passengers, and manage earnings.

## Quick Start

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE=http://localhost:8000
```

## Structure

```
lib/
├── core/           # Driver API client & state management
└── screens/        # Login, home, ride requests, navigation, earnings, profile
```

See the [root README](../README.md) for full project documentation.
