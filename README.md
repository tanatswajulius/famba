# Famba

A motorcycle ride-hailing and food delivery platform built with Flutter and FastAPI, designed for Harare, Zimbabwe.

## Features

### Ride Hailing
- **Instant Quotes** — corridor-based pricing with surge multiplier support
- **Multi-Stop Rides** — add intermediate stops to any trip
- **Scheduled Rides** — book rides in advance
- **Live Tracking** — real-time job status updates over WebSocket
- **OSRM Routing** — server-side route geometry and ETA via Project OSRM
- **Geofencing** — service-area validation for the Harare metro

### Food Delivery
- **Restaurant Browsing** — search, filter, and view menus
- **Cart & Ordering** — full cart flow with scheduled order support
- **Order Tracking** — real-time status updates for food orders
- **Restaurant Portal** — owner dashboard with order management, menu CRUD, and stats

### Driver App
- **Ride Requests** — accept/reject incoming jobs
- **Turn-by-Turn Navigation** — map-based route to pickup and drop-off
- **Delivery Mode** — separate flow for food delivery jobs
- **Earnings Dashboard** — per-ride breakdown and leaderboard
- **Live Location** — GPS broadcast to riders via WebSocket

### Payments & Wallet
- **In-App Wallet** — top-up, pay, and view transaction history
- **Promo Codes** — validation and discount application
- **Referral Program** — generate codes, track sign-ups, earn credit
- **Driver Withdrawals** — request and admin-process payouts

### Trust & Safety
- **SOS Emergency Button** — one-tap alert on the tracking screen
- **Issue Reporting** — structured safety reports submitted to the backend
- **Helmet Check Badge** — driver safety indicator on the quote screen
- **Dispute System** — raise and resolve ride/order disputes

### Offline Reliability
- **Offline Queue** — failed requests are queued automatically when connectivity drops
- **Auto-Retry** — queued requests replay when the network returns
- **Persistent Storage** — local state backed by SharedPreferences

### Platform
- **JWT Authentication** — register, login, refresh, logout with token rotation
- **In-App Chat** — REST + WebSocket messaging between rider and driver
- **Receipts** — HTML ride and food-order receipts
- **Admin Panel** — user management, stats, CSV exports, role assignment, app version config
- **Rate Limiting** — in-memory middleware with stricter limits on auth/OTP routes
- **Email Service** — SMTP-based transactional emails (OTP, receipts, alerts)

## Tech Stack

| Layer | Technology |
|-------|------------|
| Rider App | Flutter (Dart >= 3.5), Provider, flutter\_map, connectivity\_plus |
| Driver App | Flutter (Dart >= 3.5), Provider, geolocator, permission\_handler |
| Backend | FastAPI, Uvicorn, Pydantic v2 |
| Database | SQLAlchemy 2.x — SQLite (dev) / PostgreSQL (prod) |
| Auth | JWT (python-jose), passlib, HTTP Basic fallback |
| Realtime | WebSockets (tracking, driver location, chat, dispatch) |
| Routing | OSRM via httpx |
| Cache | Redis (optional) |
| CI/CD | GitHub Actions — pytest, flutter analyze/test, web deploy to GitHub Pages |
| Hosting | Render (API), GitHub Pages (Flutter web builds) |
| Container | Docker + docker-compose (Postgres, Redis, API, Nginx admin) |

## Setup

### Backend

```bash
cd backend
pip install -r requirements.txt
cp env.example .env          # defaults: BASIC_USER=demo, BASIC_PASS=demo123
./run_local.sh               # or: uvicorn app.main:app --reload
```

API available at `http://localhost:8000`. Interactive docs at `/docs`.

For production configuration see `env.production.example`.

### Rider App

```bash
cd mobile
flutter pub get
flutter pub run flutter_native_splash:create
./run_web.sh
# or manually:
flutter run -d chrome \
  --dart-define=API_BASE=http://localhost:8000 \
  --dart-define=API_USER=demo \
  --dart-define=API_PASS=demo123
```

### Driver App

```bash
cd driver
flutter pub get
flutter run -d chrome --dart-define=API_BASE=http://localhost:8000
```

### Docker (full stack)

```bash
docker-compose up --build
```

Starts PostgreSQL, Redis, and the API. The backend is exposed on port `8000`.

## API Overview

### Auth & Users
`POST /auth/register` · `POST /auth/login` · `POST /auth/refresh` · `POST /auth/logout` · `GET /auth/me` · `PUT /users/me`

### Rides
`POST /quote` · `POST /jobs` · `GET /jobs` · `GET /jobs/{id}` · `POST /jobs/{id}/cancel` · `POST /jobs/schedule` · `POST /jobs/multi-stop` · `POST /estimate` · `GET /route`

### Food
`GET /restaurants` · `GET /restaurants/search` · `GET /restaurants/{id}` · `GET /restaurants/{id}/menu` · `POST /food-orders` · `GET /food-orders` · `GET /food-orders/{id}` · `POST /food-orders/{id}/cancel` · `POST /food-orders/schedule`

### Wallet
`GET /wallet/balance` · `POST /wallet/top-up` · `POST /wallet/pay` · `GET /wallet/transactions`

### Drivers
`GET /drivers` · `POST /drivers/{id}/location` · `GET /drivers/{id}/earnings` · `GET /drivers/earnings/leaderboard` · `POST /drivers/{id}/withdraw`

### Chat
`POST /chat/send` · `GET /chat/history`

### WebSockets
`WS /ws/track/{job_id}` · `WS /ws/driver/{driver_id}` · `WS /ws/chat/{room_id}` · `WS /ws/driver`

### Other
`POST /issues` · `POST /recommend` · `POST /ratings` · `POST /promo/validate` · `POST /referrals/create` · `GET /referrals/{code}` · `POST /otp/send` · `POST /otp/verify` · `GET /geofence/service-area` · `GET /receipts/ride/{id}` · `GET /receipts/food/{id}` · `POST /disputes` · `GET /history` · `GET /health`

### Admin
`GET /admin/stats` · `GET /admin/users` · `GET /admin/staff` · `POST /admin/users/{id}/role` · `GET /admin/export/rides` · `GET /admin/export/users` · `POST /admin/app/version`

Full interactive documentation is auto-generated at `/docs` when the backend is running.

## Project Structure

```
famba/
├── backend/
│   ├── app/
│   │   ├── main.py            # FastAPI routes & middleware
│   │   ├── auth.py            # JWT + Basic auth
│   │   ├── config.py          # pydantic-settings config
│   │   ├── database.py        # SQLAlchemy engine & session
│   │   ├── models.py          # ORM models
│   │   ├── schemas.py         # Pydantic request/response schemas
│   │   ├── recommend.py       # Pricing & corridor logic
│   │   ├── routing.py         # OSRM integration
│   │   ├── simulator.py       # Job status progression
│   │   ├── store.py           # In-memory helpers
│   │   ├── ratings.py         # Rating logic
│   │   ├── email_service.py   # SMTP email
│   │   └── rate_limit.py      # Rate-limiting middleware
│   ├── tests/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── env.example
│   └── env.production.example
├── mobile/                     # Rider Flutter app
│   ├── lib/
│   │   ├── core/              # API client, state, offline queue, WebSocket, routing
│   │   ├── models/            # Data models
│   │   ├── screens/           # Home, quote, tracking, wallet, food, chat, history…
│   │   └── widgets/           # SOS button, location search, ride preferences…
│   ├── pubspec.yaml
│   └── run_web.sh
├── driver/                     # Driver Flutter app
│   ├── lib/
│   │   ├── core/              # Driver API client & state
│   │   └── screens/           # Login, home, ride requests, navigation, earnings…
│   └── pubspec.yaml
├── docs/                       # GitHub Pages (auto-deployed web builds)
│   ├── app/                   # Rider web build
│   └── driver/                # Driver web build
├── docker-compose.yml
├── render.yaml                 # Render deploy config
└── .github/workflows/ci.yml
```

## CI/CD

The GitHub Actions workflow (`.github/workflows/ci.yml`) runs on every push and PR to `main`:

1. **Backend tests** — Python 3.11, `pytest`
2. **Flutter analyze & test** — both rider and driver apps
3. **Deploy** (main only) — builds Flutter web for both apps with `API_BASE=https://famba-api.onrender.com` and commits to `docs/`

## Color Scheme

Primary color: **Famba Green** `#8BD17C` / `Color(0xFF8BD17C)` with Material 3 theming.

## Notes

- This is a **prototype** — mock data is used for simulations and some external integrations are stubbed
- SQLite is the default database for local development; PostgreSQL is used in production
- The offline queue persists failed requests locally until connectivity returns
- WebSocket auth for job tracking uses a `token` query parameter (`user:pass` format)
- Refresh tokens are held in server memory and do not survive restarts
