# Duruha - Agricultural Supply Chain Platform

## Executive Summary

**Duruha** is a Flutter-based mobile application designed to bridge the gap between farmers and consumers in the agricultural supply chain. The platform enables farmers to pledge their harvests, manage their crops, track planting progress, and connect with market opportunities, while providing tools for consumers to express demand and access fresh produce directly from farmers.

The application follows a **feature-first architecture** with clean separation between domain, data, and presentation layers. It implements **Material 3 design** with a custom theme system featuring earthy tones (parchment and goblin color palettes) that reflect the agricultural nature of the platform.

### Purpose

- **For Farmers**: Manage crop pledges, track planting cycles, access agricultural programs, and connect with buyers
- **For Consumers**: Express produce demand, browse available crops, and connect with local farmers
- **Platform Goal**: Create transparency and efficiency in the agricultural supply chain through real-time pledge tracking and market matching

### Tech Stack

| Technology | Purpose |
|------------|---------|
| **Flutter** | Cross-platform mobile framework |
| **Dart SDK** | v3.10.7+ |
| **Material 3** | Design system and UI components |
| **SharedPreferences** | Local session management |
| **URL Launcher** | External link handling |
| **Intl** | Internationalization and formatting |

---

## Project Architecture

### Structure Overview

```
lib/
├── core/                    # Shared utilities, theme, widgets
│   ├── data/               # Core data services
│   ├── helpers/            # Utility functions
│   ├── services/           # Core services (session management)
│   ├── theme/              # Theme configuration
│   └── widgets/            # Reusable UI components (15 widgets)
├── features/               # Feature modules
│   ├── auth/              # Authentication
│   ├── farmer/            # Farmer-specific features
│   ├── consumer/          # Consumer-specific features
│   ├── landing/           # Landing page
│   └── onboarding/        # User onboarding flow
├── shared/                # Shared domain models
│   ├── produce/           # Produce data models
│   └── user/              # User profile models
└── main.dart              # Application entry point
```

### Architectural Patterns

1. **Feature-First Organization**: Features are self-contained modules with their own presentation, domain, and data layers
2. **Repository Pattern**: Data access abstracted through repository classes
3. **Session-Based Auth**: Local session management using SharedPreferences
4. **Route-Based Navigation**: Declarative routing with dynamic route generation
5. **Stateful Widgets**: State management using Flutter's built-in StatefulWidget

---

## Module Breakdown

### 1. Core Module (`lib/core/`)

The core module provides foundational services and reusable components used across the entire application.

#### 1.1 Theme (`core/theme/`)

**Responsibility**: Define application-wide design tokens, color schemes, and theme configurations.

**Key Files**:
- [`app_theme.dart`](file:///Users/ellymartamayor/Documents/dirikita/dirikita-frontend/lib/core/theme/app_theme.dart) - Material 3 theme definitions with custom color palettes

**Color Palettes**:

| Palette | Usage | Shades |
|---------|-------|--------|
| **Parchment** | Primary brand, backgrounds, neutrals | 50-950 (beige/cream tones) |
| **Goblin** | Accents, success states, agricultural theme | 50-950 (green tones) |

**Theme Features**:
- Light and dark mode support
- Material 3 semantic color roles
- Custom DatePicker theming
- Consistent elevation and spacing

#### 1.2 Widgets (`core/widgets/`)

**Responsibility**: Provide reusable, themed UI components following the Duruha design system.

**Components** (15 total):

| Widget | Purpose |
|--------|---------|
| `duruha_button.dart` | Primary action buttons |
| `duruha_text_field.dart` | Form input fields |
| `duruha_dropdown.dart` | Dropdown selection menus |
| `duruha_selection_chip_group.dart` | Multi-select chip groups |
| `duruha_selection_card.dart` | Selectable card components |
| `duruha_modal_bottom_sheet.dart` | Bottom sheet modals |
| `duruha_popup_menu.dart` | Context menus |
| `duruha_progress_bar.dart` | Progress indicators |
| `duruha_inkwell.dart` | Custom tap/ripple effects |
| `duruha_section_container.dart` | Section grouping container |
| `duruha_responsive_grid.dart` | Responsive grid layouts |
| `duruha_snackbar.dart` | Toast notifications |
| `duruha_theme_toggle_button.dart` | Light/dark mode toggle |
| `duruha_input.dart` | Input wrapper utilities |
| `duruha_widgets.dart` | Widget barrel file |

#### 1.3 Services (`core/services/`)

**Responsibility**: Manage application-wide services like session management.

**Key Service**: `SessionService`

Handles user authentication persistence and session lifecycle.

**Methods**:
- `saveUser(UserProfile)` - Persist user data
- `getSavedUser()` - Retrieve stored user
- `isLoggedIn()` - Check authentication status
- `clearSession()` - Logout user
- `clearIfExpired()` - Auto-expire sessions after 7 days
- `updateLastActive()` - Update session timestamp

#### 1.4 Helpers (`core/helpers/`)

**Responsibility**: Utility functions for common operations.

**Helpers Available**:
- Date formatting
- Money formatting
- Status conversions
- Data transformations
- Validation utilities

---

### 2. Features Module (`lib/features/`)

The features module contains all user-facing features organized by domain.

#### 2.1 Authentication (`features/auth/`)

**Responsibility**: Handle user login, signup, and profile management.

**Structure**:
```
auth/
├── data/
│   └── auth_repository.dart      # Auth API layer (mock)
├── domain/
│   └── auth_models.dart           # Auth DTOs
└── presentation/
    ├── login_screen.dart          # Login UI
    └── signup_screen.dart         # Registration UI
```

**Repository**: `AuthRepository`

**Methods**:

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `login()` | `LoginRequest` | `Future<AuthResponse>` | Authenticate user with credentials |
| `signup()` | `SignupRequest` | `Future<AuthResponse>` | Register new user account |
| `logout()` | - | `Future<void>` | Clear user session |
| `updateProfile()` | `String userId, Map<String, dynamic> data` | `Future<UserProfile>` | Update user profile after onboarding |
| `submitKyc()` | `String userId, Map<String, dynamic> data` | `Future<void>` | Submit KYC/onboarding data |

**Note**: Currently uses mock data with 2-second simulated network delay.

#### 2.2 Farmer Features (`features/farmer/`)

**Responsibility**: Farmer-specific functionality for crop management, pledges, and business tools.

**Sub-Features**:

##### 2.2.1 Farm Dashboard (`farmer/features/farm/`)

**Screens**:
- `farmer_dashboard_screen.dart` - Main farmer home screen
- `crop_study_screen.dart` - Detailed crop information

**Repositories**:
- `recommendation_repository.dart` - Crop recommendations
- `study_repository.dart` - Crop study data

##### 2.2.2 Crops Management (`farmer/features/crops/`)

**Screens**:
- `farmer_crops_screen.dart` - List of farmer's crops with search & sort
- `crop_detail_screen.dart` - Individual crop details

**Repositories**:
- `crop_details_repository.dart` - Crop metadata
- `selected_crops_repository.dart` - User's selected crops

**Features**:
- Search crops by name
- Sort by rank or alphabetically
- View crop details and variants

##### 2.2.3 Pledge Monitor (`farmer/features/monitor/`)

**Screens**:
- `pledge_monitor_screen.dart` - Historical pledge list
- `pledge_detail_screen.dart` - Individual pledge tracker

**Features**:
- Timeline visualization of planting cycle
- Days-until-harvest countdown
- Status tracking (Plant → Grow → Harvest → Sell)

##### 2.2.4 Business Tools (`farmer/features/biz/`)

**Screens**:
- `biz_screen.dart` - Business dashboard

**Repository**:
- `biz_repository.dart` - Business metrics and insights

##### 2.2.5 Programs (`farmer/features/programs/`)

**Screens**:
- `programs_screen.dart` - Agricultural support programs

**Programs Available**:
- Seed Capital
- Expert Consultations
- Logistics Pooling
- Insurance
- Group Buying
- Certification Assistance

##### 2.2.6 Profile (`farmer/features/profile/`)

**Screens**:
- `profile_screen.dart` - Farmer profile and settings
- `ratings_screen.dart` - Farmer ratings and reviews

**Repositories**:
- `profile_repository.dart` - Profile data management
- `ratings_repository.dart` - Ratings and reviews

##### 2.2.7 Shared Features (`farmer/shared/`)

**Screens**:
- `create_pledge_screen.dart` - Create new harvest pledge
- `navigation.dart` - Farmer navigation bar

**Repositories**:
- `pledge_repository.dart` - Pledge CRUD operations
- `farmer_shared_repository.dart` - Shared farmer utilities

**Domain Models**:
- `pledge_model.dart` - HarvestPledge data structure

#### 2.3 Consumer Features (`features/consumer/`)

**Responsibility**: Consumer-specific functionality for browsing and demanding produce.

**Structure**:
```
consumer/
├── features/
│   └── profile/
│       ├── data/profile_repository.dart
│       └── presentation/profile.dart
└── shared/
    └── presentation/consumer_navigation.dart
```

#### 2.4 Onboarding (`features/onboarding/`)

**Responsibility**: Multi-step user onboarding flow.

**Screens**:
- `onboarding_screen.dart` - Main onboarding coordinator

**Steps**:
1. Basic information (name, phone, location)
2. Role selection (Farmer/Consumer)
3. Role-specific profile setup

#### 2.5 Landing (`features/landing/`)

**Responsibility**: App entry point and marketing.

**Screens**:
- `landing_screen.dart` - Welcome screen with login/signup

---

### 3. Shared Module (`lib/shared/`)

The shared module contains domain models used across multiple features.

#### 3.1 User Models (`shared/user/domain/`)

**File**: [`user_models.dart`](file:///Users/ellymartamayor/Documents/dirikita/dirikita-frontend/lib/shared/user/domain/user_models.dart)

**Enums**:
```dart
enum UserRole { farmer, consumer }
```

**Classes**:

##### `UserProfile`

Represents a user account with role-specific fields.

**Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String` | Unique user identifier |
| `joinedAt` | `String` | ISO 8601 timestamp |
| `name` | `String` | Full name |
| `phone` | `String` | Contact phone |
| `barangay` | `String` | Barangay location |
| `city` | `String` | City |
| `province` | `String` | Province |
| `landmark` | `String` | Location landmark |
| `postalCode` | `String` | Postal code |
| `role` | `UserRole` | farmer or consumer |
| `dialect` | `String` | Preferred dialect |
| `farmAlias` | `String?` | **(Farmer)** Farm name |
| `landArea` | `double?` | **(Farmer)** Hectares |
| `accessibilityType` | `String?` | **(Farmer)** Farm access type |
| `waterSources` | `List<String>?` | **(Farmer)** Water sources |
| `pledgedCrops` | `List<ProduceItem>?` | **(Farmer)** Pledged crops |
| `consumerSegment` | `String?` | **(Consumer)** Household/Restaurant |
| `segmentSize` | `int?` | **(Consumer)** Household size |
| `cookingFrequency` | `String?` | **(Consumer)** Cooking frequency |
| `qualityPreferences` | `List<String>?` | **(Consumer)** Quality preferences |
| `demandCrops` | `List<ProduceItem>?` | **(Consumer)** Demanded crops |

**Getters**:
```dart
bool get isFarmer => role == UserRole.farmer;
```

##### `ProduceItem`

User-specific produce item with transactional context (extends base Produce model).

**Fields**:

| Category | Field | Type | Description |
|----------|-------|------|-------------|
| **Core** | `id` | `String` | Unique produce ID |
| | `nameEnglish` | `String` | English name |
| | `nameScientific` | `String` | Scientific name |
| | `category` | `ProduceCategory` | Crop category |
| | `namesByDialect` | `Map<String, String>` | Localized names |
| **Varieties** | `availableVarieties` | `List<String>` | Available varieties |
| **Visual** | `imageHeroUrl` | `String` | Hero image URL |
| | `imageThumbnailUrl` | `String` | Thumbnail URL |
| | `iconUrl` | `String` | Icon URL |
| | `gradeGuideUrl` | `String` | Quality guide URL |
| **Pricing** | `unitOfMeasure` | `String` | kg, bundles, etc. |
| | `priceMinHistorical` | `double` | Historical minimum price |
| | `priceMaxHistorical` | `double` | Historical maximum price |
| | `currentFairMarketGuideline` | `double` | Fair market price |
| **Logistics** | `perishabilityIndex` | `int` | 1-5 scale |
| | `shelfLifeDays` | `int` | Days until spoilage |
| | `requiresColdChain` | `bool` | Needs refrigeration |
| | `avgWeightPerUnitKg` | `double` | Average weight |
| **Agricultural** | `growingCycleDays` | `int` | Days to harvest |
| | `seasonalityStart` | `String` | Season start month |
| | `seasonalityEnd` | `String` | Season end month |
| | `isNativeToRegion` | `bool` | Regional native crop |
| **User Context** | `harvestDate` | `DateTime?` | Pledged harvest date |
| | `pledgedAmount` | `double?` | Pledged quantity |
| | `demandAmount` | `double?` | Demanded quantity |
| | `preferredQuality` | `String?` | Quality preference |
| | `selectedVariety` | `String?` | Selected variety |

**Methods**:
```dart
ProduceItem copyWith({
  DateTime? harvestDate,
  double? pledgedAmount,
  double? demandAmount,
  String? preferredQuality,
  String? selectedVariety,
})
```

Creates a copy with updated user context fields.

#### 3.2 Produce Models (`shared/produce/domain/`)

**File**: [`produce_model.dart`](file:///Users/ellymartamayor/Documents/dirikita/dirikita-frontend/lib/shared/produce/domain/produce_model.dart)

**Enums**:
```dart
enum ProduceCategory {
  leafy,      // Leafy greens
  fruitVeg,   // Fruit vegetables (eggplant, tomato)
  root,       // Root crops
  spice,      // Spices
  fruit,      // Fruits
  legume,     // Legumes
}
```

**Classes**:

##### `Produce`

Base produce model without user context.

**Fields**: Same as `ProduceItem` but excludes the 5 user context fields (harvestDate, pledgedAmount, demandAmount, preferredQuality, selectedVariety).

**Repository**: `ProduceRepository` - Manages produce catalog data

---

## API/Function Reference

### Core Services

#### SessionService

**Purpose**: Manage user authentication and session lifecycle.

**Location**: [`lib/core/services/session_service.dart`](file:///Users/ellymartamayor/Documents/dirikita/dirikita-frontend/lib/core/services/session_service.dart)

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `saveUser()` | `UserProfile user` | `Future<void>` | Saves user profile to SharedPreferences |
| `getSavedUser()` | - | `Future<UserProfile?>` | Retrieves saved user profile |
| `getUserId()` | - | `Future<String?>` | Gets current user ID |
| `getUserName()` | - | `Future<String?>` | Gets current user name |
| `getUserData()` | - | `Future<Map<String, dynamic>?>` | Gets raw user data map |
| `updateLastActive()` | - | `Future<void>` | Updates last active timestamp |
| `clearIfExpired()` | - | `Future<bool>` | Clears session if inactive for 7+ days |
| `clearSession()` | - | `Future<void>` | Logs out user |
| `isLoggedIn()` | - | `Future<bool>` | Checks if user is authenticated |

**Exceptions**: None explicitly thrown. Returns null for missing data.

---

### Repositories

#### AuthRepository

**Purpose**: Handle authentication operations.

**Location**: [`lib/features/auth/data/auth_repository.dart`](file:///Users/ellymartamayor/Documents/dirikita/dirikita-frontend/lib/features/auth/data/auth_repository.dart)

| Method | Parameters | Returns | Exceptions | Description |
|--------|-----------|---------|------------|-------------|
| `login()` | `LoginRequest request` | `Future<AuthResponse>` | - | Authenticates user (mock 2s delay) |
| `signup()` | `SignupRequest request` | `Future<AuthResponse>` | - | Registers new user (mock 2s delay) |
| `logout()` | - | `Future<void>` | - | Clears user session |
| `updateProfile()` | `String userId`<br>`Map<String, dynamic> data` | `Future<UserProfile>` | `Exception` if no session | Updates user profile after onboarding |
| `submitKyc()` | `String userId`<br>`Map<String, dynamic> data` | `Future<void>` | `Exception` if invalid user ID | Submits KYC/onboarding data |

**Request Models**:

```dart
class LoginRequest {
  final String email;     // Phone number or email
  final String password;
}

class SignupRequest {
  final String fullName;
  final String email;
  final String password;
}
```

**Response Model**:

```dart
class AuthResponse {
  final String token;      // JWT token (mock)
  final UserProfile user;  // User profile
}
```

---

#### PledgeRepository

**Purpose**: Manage harvest pledge operations.

**Location**: [`lib/features/farmer/shared/data/pledge_repository.dart`](file:///Users/ellymartamayor/Documents/dirikita/dirikita-frontend/lib/features/farmer/shared/data/pledge_repository.dart)

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `createPledge()` | `HarvestPledge pledge` | `Future<void>` | Create new harvest pledge |
| `fetchMyPledges()` | - | `Future<List<HarvestPledge>>` | Get all farmer pledges |
| `getDemandForecast()` | `String cropId`<br>`DateTime date` | `Future<Map<String, dynamic>>` | Get demand forecast for crop |
| `updatePledgeStatus()` | `String pledgeId`<br>`String newStatus`<br>`String? notes` | `Future<void>` | Update pledge status |
| `addExpense()` | `String pledgeId`<br>`Map<String, dynamic> expenseData` | `Future<void>` | Add expense to pledge |
| `updateExpense()` | `String pledgeId`<br>`Map<String, dynamic> expenseData` | `Future<void>` | Update existing expense |
| `deleteExpense()` | `String pledgeId`<br>`String expenseId` | `Future<void>` | Remove expense |
| `deleteStatusEntry()` | `String pledgeId`<br>`String statusId` | `Future<void>` | Remove status entry |

**Domain Model**: `HarvestPledge`

Key fields:
- `id`, `farmerId`, `cropId`
- `pledgedQuantity`, `unit`
- `estimatedHarvestDate`
- `selectedVarieties`, `targetMarket`
- `status` (Plant, Grow, Harvest, Sell)
- Timeline tracking and expenses

---

#### ProduceRepository

**Purpose**: Manage produce catalog.

**Location**: [`lib/shared/produce/data/produce_repository.dart`](file:///Users/ellymartamayor/Documents/dirikita/dirikita-frontend/lib/shared/produce/data/produce_repository.dart)

**Methods**: Provides access to produce catalog with filtering and search capabilities.

---

### Reusable Widgets

#### DuruhaButton

**Purpose**: Primary action button with theme integration.

**Location**: [`lib/core/widgets/duruha_button.dart`](file:///Users/ellymartamayor/Documents/dirikita/dirikita-frontend/lib/core/widgets/duruha_button.dart)

**Usage**:
```dart
DuruhaButton(
  label: 'Submit',
  onPressed: () { /* action */ },
  isLoading: false,
  isDisabled: false,
)
```

**Parameters**:

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `label` | `String` | Yes | - | Button text |
| `onPressed` | `VoidCallback?` | Yes | - | Tap handler |
| `isLoading` | `bool` | No | `false` | Show loading spinner |
| `isDisabled` | `bool` | No | `false` | Disable button |

---

#### DuruhaTextField

**Purpose**: Themed text input field.

**Location**: [`lib/core/widgets/duruha_text_field.dart`](file:///Users/ellymartamayor/Documents/dirikita/dirikita-frontend/lib/core/widgets/duruha_text_field.dart)

**Usage**:
```dart
DuruhaTextField(
  controller: _controller,
  label: 'Full Name',
  hint: 'Enter your name',
  isPassword: false,
)
```

**Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| `controller` | `TextEditingController` | Text controller |
| `label` | `String` | Field label |
| `hint` | `String?` | Placeholder text |
| `isPassword` | `bool` | Obscure text |
| `keyboardType` | `TextInputType?` | Keyboard type |
| `validator` | `String? Function(String?)?` | Validation function |

---

#### DuruhaDropdown

**Purpose**: Themed dropdown selector.

**Location**: [`lib/core/widgets/duruha_dropdown.dart`](file:///Users/ellymartamayor/Documents/dirikita/dirikita-frontend/lib/core/widgets/duruha_dropdown.dart)

**Usage**:
```dart
DuruhaDropdown<String>(
  value: selectedValue,
  items: ['Option 1', 'Option 2'],
  onChanged: (value) { setState(() => selectedValue = value); },
  label: 'Select Option',
)
```

**Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| `value` | `T?` | Current selected value |
| `items` | `List<T>` | List of options |
| `onChanged` | `Function(T?)` | Selection callback |
| `label` | `String` | Dropdown label |
| `prefixIcon` | `IconData?` | Leading icon |

---

#### DuruhaSelectionChipGroup

**Purpose**: Multi-select chip group with single/multi mode.

**Location**: [`lib/core/widgets/duruha_selection_chip_group.dart`](file:///Users/ellymartamayor/Documents/dirikita/dirikita-frontend/lib/core/widgets/duruha_selection_chip_group.dart)

**Usage**:
```dart
DuruhaSelectionChipGroup(
  label: 'Water Sources',
  options: ['Rain', 'River', 'Well', 'Irrigation'],
  selectedOptions: selectedSources,
  onSelectionChanged: (selected) {
    setState(() => selectedSources = selected);
  },
  isMultiSelect: true,
)
```

**Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| `label` | `String` | Group label |
| `options` | `List<String>` | Available options |
| `selectedOptions` | `List<String>` | Currently selected |
| `onSelectionChanged` | `Function(List<String>)` | Selection callback |
| `isMultiSelect` | `bool` | Allow multiple selections |

---

#### DuruhaModalBottomSheet

**Purpose**: Action sheet from bottom of screen.

**Location**: [`lib/core/widgets/duruha_modal_bottom_sheet.dart`](file:///Users/ellymartamayor/Documents/dirikita/dirikita-frontend/lib/core/widgets/duruha_modal_bottom_sheet.dart)

**Usage**:
```dart
DuruhaModalBottomSheet.show(
  context: context,
  title: 'More Options',
  child: Column(children: [...]),
)
```

**Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| `context` | `BuildContext` | Build context |
| `title` | `String` | Sheet title |
| `child` | `Widget` | Sheet content |
| `height` | `double?` | Custom height |

---

#### DuruhaProgressBar

**Purpose**: Visual progress indicator with percentage.

**Location**: [`lib/core/widgets/duruha_progress_bar.dart`](file:///Users/ellymartamayor/Documents/dirikita/dirikita-frontend/lib/core/widgets/duruha_progress_bar.dart)

**Usage**:
```dart
DuruhaProgressBar(
  progress: 0.65, // 65%
  label: 'Planting Progress',
  showPercentage: true,
)
```

**Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| `progress` | `double` | 0.0 to 1.0 |
| `label` | `String?` | Progress label |
| `showPercentage` | `bool` | Display percentage text |

---

## Usage Examples

### Example 1: User Authentication Flow

```dart
import 'package:duruha/features/auth/data/auth_repository.dart';
import 'package:duruha/features/auth/domain/auth_models.dart';
import 'package:duruha/core/services/session_service.dart';

class LoginExample {
  final AuthRepository _authRepo = AuthRepository();
  
  Future<void> loginUser(String email, String password) async {
    try {
      // Create login request
      final request = LoginRequest(
        email: email,
        password: password,
      );
      
      // Authenticate
      final response = await _authRepo.login(request);
      
      // Session is automatically saved by AuthRepository
      print('Logged in as: ${response.user.name}');
      print('Token: ${response.token}');
      
      // Check session
      final isLoggedIn = await SessionService.isLoggedIn();
      print('Session active: $isLoggedIn');
      
    } catch (e) {
      print('Login failed: $e');
    }
  }
  
  Future<void> checkCurrentUser() async {
    final user = await SessionService.getSavedUser();
    if (user != null) {
      print('Current user: ${user.name} (${user.role.name})');
    } else {
      print('No active session');
    }
  }
  
  Future<void> logout() async {
    await _authRepo.logout();
    print('User logged out');
  }
}
```

---

### Example 2: Creating a Harvest Pledge

```dart
import 'package:duruha/features/farmer/shared/data/pledge_repository.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';

class PledgeExample {
  final PledgeRepository _pledgeRepo = PledgeRepository();
  
  Future<void> createHarvestPledge() async {
    // Create a pledge for tomato harvest
    final pledge = HarvestPledge(
      id: 'pledge_${DateTime.now().millisecondsSinceEpoch}',
      farmerId: 'farmer_123',
      cropId: 'tomato',
      cropNameEnglish: 'Tomato',
      cropNameLocal: 'Kamatis',
      pledgedQuantity: 500.0,
      unit: 'kg',
      estimatedHarvestDate: DateTime.now().add(Duration(days: 90)),
      selectedVarieties: ['Cherry Tomato', 'Beefsteak'],
      targetMarket: 'Davao City Public Market',
      status: 'Plant', // Plant → Grow → Harvest → Sell
      timeline: [],
      expenses: [],
    );
    
    // Submit pledge
    await _pledgeRepo.createPledge(pledge);
    print('Pledge created: ${pledge.id}');
    
    // Update status when planting is complete
    await _pledgeRepo.updatePledgeStatus(
      pledge.id,
      'Grow',
      notes: 'Seedlings transplanted successfully',
    );
  }
  
  Future<void> viewMyPledges() async {
    final pledges = await _pledgeRepo.fetchMyPledges();
    
    for (var pledge in pledges) {
      final daysUntilHarvest = pledge.estimatedHarvestDate
          .difference(DateTime.now())
          .inDays;
      
      print('${pledge.cropNameEnglish}: ${pledge.pledgedQuantity} ${pledge.unit}');
      print('Status: ${pledge.status}');
      print('Days until harvest: $daysUntilHarvest');
      print('---');
    }
  }
  
  Future<void> trackExpenses(String pledgeId) async {
    // Add expense
    await _pledgeRepo.addExpense(pledgeId, {
      'id': 'exp_001',
      'category': 'Seeds',
      'amount': 2500.0,
      'date': DateTime.now().toIso8601String(),
      'notes': 'Hybrid tomato seeds',
    });
    
    print('Expense added to pledge');
  }
}
```

---

### Example 3: Using UI Components

```dart
import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_button.dart';
import 'package:duruha/core/widgets/duruha_text_field.dart';
import 'package:duruha/core/widgets/duruha_selection_chip_group.dart';

class FormExample extends StatefulWidget {
  @override
  State<FormExample> createState() => _FormExampleState();
}

class _FormExampleState extends State<FormExample> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  List<String> _selectedWaterSources = [];
  bool _isSubmitting = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Farmer Registration')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Text input
            DuruhaTextField(
              controller: _nameController,
              label: 'Farm Name',
              hint: 'e.g., Happy Harvest Farm',
            ),
            SizedBox(height: 16),
            
            // Phone input
            DuruhaTextField(
              controller: _phoneController,
              label: 'Contact Number',
              hint: '09171234567',
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 24),
            
            // Multi-select chips
            DuruhaSelectionChipGroup(
              label: 'Water Sources',
              options: ['Rain', 'River', 'Well', 'Irrigation'],
              selectedOptions: _selectedWaterSources,
              onSelectionChanged: (selected) {
                setState(() => _selectedWaterSources = selected);
              },
              isMultiSelect: true,
            ),
            SizedBox(height: 32),
            
            // Submit button
            DuruhaButton(
              label: 'Submit',
              onPressed: _handleSubmit,
              isLoading: _isSubmitting,
              isDisabled: _nameController.text.isEmpty,
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _handleSubmit() async {
    setState(() => _isSubmitting = true);
    
    // Simulate API call
    await Future.delayed(Duration(seconds: 2));
    
    print('Farm: ${_nameController.text}');
    print('Phone: ${_phoneController.text}');
    print('Water Sources: $_selectedWaterSources');
    
    setState(() => _isSubmitting = false);
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
```

---

## Navigation Structure

### Route Configuration

Routes are defined in [`main.dart`](file:///Users/ellymartamayor/Documents/dirikita/dirikita-frontend/lib/main.dart) using named routes.

**Static Routes**:

| Route | Screen | Access |
|-------|--------|--------|
| `/splash` | `SplashScreen` | Public |
| `/` | `LandingScreen` | Public |
| `/login` | `LoginScreen` | Public |
| `/signup` | `SignupScreen` | Public |
| `/onboarding` | `OnboardingScreen` | Protected |
| `/home` | Role-based (Farmer/Consumer Dashboard) | Protected |
| `/profile` | Role-based Profile | Protected |

**Dynamic Routes** (Farmer):

| Route Pattern | Screen | Purpose |
|---------------|--------|---------|
| `/farmer/farm` | `FarmerDashboardScreen` | Farm dashboard |
| `/farmer/crops` | `FarmerCropsScreen` | Crop list |
| `/farmer/crops/{cropId}` | `CropDetailScreen` | Crop details |
| `/farmer/pledge/create` | `FarmerCreatePledgeScreen` | Create pledge |
| `/farmer/pledge/study` | `CropStudyScreen` | Study crop |
| `/farmer/monitor` | `MonitorPledgeScreen` | Pledge history |
| `/farmer/monitor/{pledgeId}` | `PledgeDetailScreen` | Pledge details |
| `/farmer/biz` | `FarmerBizScreen` | Business tools |
| `/farmer/programs` | `FarmerProgramsScreen` | Support programs |
| `/farmer/profile/ratings` | `FarmerProfileRatingsScreen` | Ratings |

**Protected Routes**: Wrapped in `ProtectedScreen` widget that checks session via `SessionService.isLoggedIn()`.

---

## Data Flow

### Authentication Flow

```
1. User enters credentials (LoginScreen)
   ↓
2. LoginRequest → AuthRepository.login()
   ↓
3. Mock API delay (2s) + user creation
   ↓
4. SessionService.saveUser() → SharedPreferences
   ↓
5. Return AuthResponse with token + user
   ↓
6. Navigation to role-based home screen
```

### Pledge Creation Flow

```
1. Farmer selects crop (FarmerCreatePledgeScreen)
   ↓
2. Fills pledge form (quantity, date, varieties)
   ↓
3. Preview pledge details
   ↓
4. Confirm → PledgeRepository.createPledge()
   ↓
5. Mock data stored in memory
   ↓
6. Navigate to MonitorPledgeScreen
```

### Session Management

```
App Launch → SplashScreen
   ↓
SessionService.clearIfExpired() [7-day timeout]
   ↓
SessionService.getSavedUser()
   ↓
If user exists: Navigate to /home
If no user: Navigate to /landing
```

---

## Development Guidelines

### Adding a New Feature

1. Create feature directory under `lib/features/`
2. Structure: `data/`, `domain/`, `presentation/`
3. Create repository in `data/` layer
4. Define models in `domain/` layer
5. Build screens in `presentation/` layer
6. Register routes in `main.dart`
7. Update navigation components if needed

### Adding a Widget

1. Create widget file in `lib/core/widgets/`
2. Follow naming: `duruha_<widget_name>.dart`
3. Use theme colors from `DuruhaTheme`
4. Export in `duruha_widgets.dart`
5. Document parameters and usage

### Theme Customization

Edit [`lib/core/theme/app_theme.dart`](file:///Users/ellymartamayor/Documents/dirikita/dirikita-frontend/lib/core/theme/app_theme.dart):

- **Colors**: Modify `parchment` or `goblin` palette shades
- **Typography**: Change `fontFamily` in `ThemeData`
- **Component Themes**: Update widget-specific themes (e.g., `datePickerTheme`)

---

## Current Limitations

1. **Mock Data**: All repositories use hardcoded mock data with simulated network delays
2. **No Backend**: No API integration; session stored locally
3. **State Management**: Uses StatefulWidget; no global state solution (BLoC, Provider, Riverpod)
4. **No Real-Time**: No websockets or real-time updates
5. **Limited Validation**: Basic form validation only
6. **No Image Upload**: Image URLs are mock strings
7. **Single Language**: No full i18n implementation despite dialect field

---

## Future Enhancements

- [ ] Backend API integration with real endpoints
- [ ] Global state management (Riverpod/BLoC)
- [ ] Real-time pledge updates via WebSocket
- [ ] Image upload and storage
- [ ] Full internationalization (i18n)
- [ ] Push notifications
- [ ] Offline mode with local database (SQLite/Hive)
- [ ] Analytics and crash reporting
- [ ] Consumer features (marketplace, cart, orders)
- [ ] Payment integration
- [ ] Chat between farmers and buyers
- [ ] GPS integration for farm mapping

---

## Getting Started

### Prerequisites

- Flutter SDK 3.10.7 or higher
- Dart SDK 3.10.7 or higher
- iOS/Android development environment

### Installation

```bash
# Clone repository
git clone <repository-url>
cd dirikita-frontend

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Project Commands

```bash
# Run app
flutter run

# Build for production
flutter build apk       # Android
flutter build ios       # iOS

# Run tests
flutter test

# Clean build
flutter clean
flutter pub get

# Analyze code
flutter analyze
```

---

## Contact & Support

For questions or contributions, please refer to the project maintainers.

---

**Last Updated**: February 2, 2026  
**Version**: 1.0.0+1  
**License**: Private (not published to pub.dev)
