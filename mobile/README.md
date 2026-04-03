# Famba Rider

Flutter app for riders — request motorcycle rides and order food delivery in Harare.

## Quick Start

```bash
flutter pub get
flutter pub run flutter_native_splash:create

# Run on web (with local backend)
./run_web.sh

# Or manually
flutter run -d chrome \
  --dart-define=API_BASE=http://localhost:8000 \
  --dart-define=API_USER=demo \
  --dart-define=API_PASS=demo123
```

## Environment

Copy the example env file for web builds:

```bash
cp env.web.example .env.web
```

| Variable | Default | Description |
|----------|---------|-------------|
| `API_BASE` | `http://localhost:8000` | Backend URL |
| `API_USER` | `demo` | Basic auth username |
| `API_PASS` | `demo123` | Basic auth password |

## Structure

```
lib/
├── core/           # API client, app state, offline queue, WebSocket, routing
├── models/         # Data models
├── screens/        # All app screens (home, quote, tracking, wallet, food, chat…)
└── widgets/        # Reusable components (SOS button, location search…)
```

See the [root README](../README.md) for full project documentation.
