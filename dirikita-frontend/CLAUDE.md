# Dirikita Frontend — CLAUDE.md

## Project Overview

Flutter app named **Duruha** (package: `duruha`) — an agricultural marketplace connecting farmers and consumers. Backend is Supabase; payments via HitPay.

## Architecture

### Feature-based folder structure
```
lib/
  core/           # Shared widgets, helpers, theme, constants, services
  features/
    admin/        # Admin dashboard, produce management, price calculator, settings
    auth/         # Login, signup, OTP verification, password reset
    consumer/     # Shop, manage orders, subscriptions, profile, transactions
    farmer/       # Main dashboard, sales, manage pledges, biz analytics, programs, subscriptions, profile
    landing/      # Landing/splash screens
    onboarding/   # Role selection, profile setup, terms
  shared/
    produce/      # Produce varieties, dialects — shared across roles
    user/         # Location, dialect repositories; FAQ screen
  supabase_config.dart  # Exports `supabase` client singleton
  main.dart             # App entry point, routing, role-based auth
```

### User Roles
Three roles: `farmer`, `consumer`, `admin` — stored in `UserProfile.role` (`UserRole` enum).

`ProtectedScreen` wraps every authenticated route; `SessionService` manages session persistence via `shared_preferences`.

## Key Conventions

### Custom Widget Library
All reusable widgets are prefixed `duruha_` in `lib/core/widgets/`:
- `DuruhaScaffold`, `DuruhaAppBar`, `DuruhaButton`, `DuruhaInput`, `DuruhaDropdown`
- `DuruhaSnackbar`, `DuruhaBottomSheet`, `DuruhaDateInput`, `DuruhaWheelPicker`
- `DuruhaSectionSliver`, `DuruhaSliverAppBar`, `DuruhaGridView`

### Custom Helpers in `lib/core/helpers/`
- `duruha_formatter.dart` — number/date formatting
- `duruha_status_helper.dart` — status label/color mapping
- `duruha_color_helper.dart` — color utilities
- `duruha_responsive.dart` — responsive breakpoints
- `duruha_helpers.dart` — misc utilities

### Navigation
Named routes defined in `main.dart` using `onGenerateRoute`. Route prefixes:
- `/consumer/...` — consumer screens
- `/farmer/...` — farmer screens
- `/admin/...` — admin screens
- `/home` — role-based redirect after login

No transitions: `transitionDuration: Duration.zero`.

### Supabase
```dart
import 'package:duruha/supabase_config.dart';
// Use: supabase.from('table').select(...)
```

Credentials loaded from `.env` via `flutter_dotenv`.

### Theming
Light/dark themes in `lib/core/theme/app_theme.dart` (`DuruhaTheme.lightTheme` / `DuruhaTheme.darkTheme`). Theme persisted via `SessionService.getThemePreference()`.

## Dependencies (key)
- `supabase_flutter` — backend/auth
- `flutter_dotenv` — env config (`.env` file at root)
- `google_fonts` — typography
- `geolocator` — location
- `image_picker` — photo uploads
- `shared_preferences` — local session storage
- `uuid` — ID generation
- `intl` — date/number formatting
- `http` — HTTP calls (e.g., HitPay)
- `app_links` — deep links (HitPay payment callbacks)

## Subscription Types (Consumer)
- **Price Lock** (`/consumer/subscriptions/pricelock`) — lock in produce prices
- **Future Plan** (`/consumer/subscriptions/cfp`) — forward purchase plans
- **Quality** (`/consumer/subscriptions/quality`) — quality-based subscriptions

## Running the App
```bash
flutter pub get
flutter run
```

Requires a `.env` file at project root with:
```
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
```

## SQL
Database schema/functions are in `sql_functions/` at the repo root (one level up from this frontend).
