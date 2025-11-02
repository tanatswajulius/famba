# Famba Prototype

A ride-hailing mobile app prototype built with Flutter and FastAPI.

## Features

### 1. Trust & Safety
- **SOS Emergency Button**: Available on tracking screen for rider safety
- **Issue Reporting**: Backend endpoint to handle safety reports

### 2. Offline Reliability
- **Offline Queue**: Automatically queues failed requests when offline
- **Auto-Retry**: Reconnects and retries queued requests when back online
- **Persistent Storage**: Uses SharedPreferences for local data persistence

### 3. Driver Matching
- **Smart Recommendations**: Driver recommendations based on corridor
- **Top Driver Display**: Shows best-matched driver on quote screen

### 4. Full-Screen Splash
- **Native Splash Screen**: Displays Famba logo on app launch
- **Cross-Platform**: Supports iOS, Android, and Web

### 5. UX Polish
- **Modern UI**: Clean design with Famba green theme
- **Responsive Buttons**: Disabled states and loading indicators
- **Safety Indicators**: Helmet check badge on driver profile
- **Error Handling**: User-friendly error messages with retry options
- **Consistent Styling**: Rounded corners, proper spacing, Material 3

## Setup Instructions

### Backend

1. Navigate to the backend directory:
```bash
cd backend
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Run the backend:
```bash
./run.sh
# or
uvicorn app.main:app --reload
```

The API will be available at `http://localhost:8000`

### Mobile App

1. Navigate to the mobile directory:
```bash
cd mobile
```

2. Install Flutter dependencies:
```bash
flutter pub get
```

3. Generate splash screen assets:
```bash
flutter pub run flutter_native_splash:create
```

4. Run the app:
```bash
flutter run
# or for web
flutter run -d chrome
```

## API Endpoints

- `GET /health` - Health check
- `POST /quote` - Get price quote for a ride
- `POST /jobs` - Create a new ride job
- `GET /jobs/{job_id}` - Get job status
- `GET /jobs` - List all jobs
- `POST /issues` - Report a safety issue
- `POST /recommend` - Get recommended drivers for a corridor

## Project Structure

```
famba-prototype/
├── backend/
│   ├── app/
│   │   ├── main.py          # FastAPI app & routes
│   │   ├── schemas.py       # Pydantic models
│   │   ├── recommend.py     # Pricing & corridor logic
│   │   ├── store.py         # In-memory data store
│   │   └── simulator.py     # Job status simulation
│   └── requirements.txt
└── mobile/
    ├── lib/
    │   ├── core/
    │   │   ├── api.dart           # API client
    │   │   ├── app_state.dart     # App state management
    │   │   └── offline_queue.dart # Offline request queue
    │   ├── models/
    │   │   └── job.dart           # Job model
    │   ├── screens/
    │   │   ├── home_screen.dart    # Home screen
    │   │   ├── login_screen.dart   # Login/splash screen
    │   │   ├── quote_screen.dart   # Quote display
    │   │   ├── tracking_screen.dart # Live tracking
    │   │   └── wallet_screen.dart  # Wallet placeholder
    │   ├── widgets/
    │   │   └── sos_button.dart    # SOS emergency button
    │   └── main.dart
    └── pubspec.yaml
```

## Color Scheme

The app uses **Famba Green** (#8BD17C / Color(0xFF8BD17C)) as the primary color with Material 3 theming.

## Notes

- This is a **prototype** with mock data and in-memory storage
- No actual payment processing or real-time GPS tracking
- The offline queue persists requests locally until connectivity returns
- Splash screen configuration is in `pubspec.yaml` under `flutter_native_splash`

## Future Enhancements

- Real-time GPS tracking with maps API
- Payment integration with Famba Card
- Push notifications for ride updates
- Driver app counterpart
- Production database (PostgreSQL/MongoDB)
- Authentication & authorization
- End-to-end encryption for sensitive data

