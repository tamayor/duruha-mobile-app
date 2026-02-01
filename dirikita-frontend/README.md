# Dirikita (Duruha) Frontend

A modern, role-driven mobile application for empowering farmers and connecting them directly with consumers. Built with Flutter.

## 📱 Features

### For Farmers
- **Dashboard**: Real-time overview of crops, recommendations, and local market trends.
- **Pledge Monitor**: Track crop pledges, view timelines, and manage harvest dates.
- **Business Hub**: Manage sales, track earnings, and view financial insights.
- **Crop Catalog**: Browse and manage pledged crops with advanced filtering and sorting.
- **Profile**: Verify identity, manage farm details, and earn badges.

### For Consumers
- **Marketplace**: Browse fresh, local produce directly from farmers.
- **Demand Board**: Post specific requirements for farmers to fulfill.
- **Profile**: Customize preferences for cooking frequency and quality.

## 🏗 Architecture

This project follows a **Feature-First** architecture with a strict separation of concerns (Clean Architecture).

### Folder Structure
```
lib/
├── core/               # App-wide utilities, widgets, and services
│   ├── widgets/        # Reusable Duruha* widgets
│   ├── services/       # SessionService, etc.
│   └── helpers/        # Formatters, constants
├── features/           # Feature-specific modules
│   ├── auth/           # Login, Signup, AuthRepository
│   ├── farmer/         # Farmer-specific screens & logic
│   ├── consumer/       # Consumer-specific screens & logic
│   └── onboarding/     # Unified onboarding flow
├── shared/             # Shared entities and logic (User, etc.)
└── main.dart           # App entry point & Routing
```

### Key Patterns
- **Repository Pattern**: Data fetching is handled by repositories (e.g., `AuthRepository`, `BizRepository`), keeping UI code clean.
- **Duruha Design System**: A custom widget set prefix with `Duruha` (e.g., `DuruhaButton`, `DuruhaInput`) ensures consistent branding.
- **Session Management**: User sessions are persisted locally using `SharedPreferences` via `SessionService`.

## 🛠 Design System (Duruha)

We use a set of custom widgets to maintain visual consistency:

- `DuruhaButton`: Primary/Secondary action buttons with loading states.
- `DuruhaInput`: Form fields with standardized validation and styling.
- `DuruhaCard`: Elevated containers for content grouping.
- `DuruhaBadge`: Status indicators (e.g., for crop stages).

## 🚀 Getting Started

1.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```

2.  **Run the App**:
    ```bash
    flutter run
    ```

## 🔐 Auth & Onboarding

- **Login**: Simulates authentication and saves the user session.
- **Onboarding**: A multi-step wizard for gathering user data. Upon completion, the profile is updated via `AuthRepository` and persisted locally.
- **Protection**: Routes are guarded by `ProtectedScreen`, ensuring only authenticated users can access internal features.
