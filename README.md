# AI Stethoscope - Medical Diagnosis App

A Flutter-based mobile application that provides AI-powered respiratory and cardiac analysis through digital stethoscope integration. The app features realistic medical waveform visualizations, Firebase-based user management, and comprehensive PDF reporting.

## 📋 Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Firebase Setup](#firebase-setup)
- [Project Structure](#project-structure)
- [Key Components](#key-components)
- [Build Configuration](#build-configuration)
- [Localization](#localization)
- [Contributing](#contributing)
- [Known Issues](#known-issues)

## ✨ Features

### Core Functionality
- **WiFi Stethoscope Connection**: Simulated WiFi-based device connectivity
- **Position Selection**: Heart and lung auscultation modes
- **Real-time Waveform Visualization**: 
  - Realistic ECG-like heart sounds (QRS complex, T-wave patterns)
  - Authentic lung breath sounds (inhale/exhale cycles)
  - Medical-grade noise artifacts (60Hz interference, muscle tremor, movement artifacts)
- **AI Risk Assessment**: Automated analysis with 5% or 10% risk scoring
- **25-Second Analysis Flow**: Timed listening period with countdown and animations
- **Checkup Recommendations**: Automated quarterly checkup guidance

### User Management
- **Firebase Authentication**: Email/password authentication
- **User Profile Setup**: 
  - Name, age, sex collection
  - Medical history tracking
  - Existing conditions database
- **Patient History**: Complete diagnosis record tracking with timestamps

### Reporting
- **PDF Report Generation**:
  - Patient information summary
  - Risk assessment with color-coded visualization
  - Diagnosis history table
  - Medical statistics
  - Professional medical report formatting
- **PDF Sharing**: Direct sharing via system share sheet

### UI/UX
- **Dark Theme**: Modern dark mode interface with green/blue accents
- **Multi-language Support**: English, Spanish, French, German, Hindi
- **Responsive Design**: Optimized for various screen sizes
- **Smooth Animations**: Step-based flow with transition animations

## 🛠 Tech Stack

### Frontend
- **Flutter**: ^3.9.0 (Dart SDK)
- **Material Design 3**: Modern UI components
- **Provider**: State management (language switching)

### Backend & Services
- **Firebase Core**: ^3.8.1
- **Firebase Authentication**: ^5.3.3 - User authentication
- **Cloud Firestore**: ^5.4.4 - NoSQL database for user profiles and diagnosis records

### ML & Processing
- **TensorFlow Lite**: ^0.11.0 - On-device ML inference
- **Custom DSP**: Log-mel spectrogram processing for audio analysis

### Additional Packages
- **pdf**: ^3.10.8 - PDF document generation
- **printing**: ^5.12.0 - PDF rendering and sharing
- **path_provider**: ^2.1.5 - File system access
- **flutter_blue_plus**: ^1.32.12 - Bluetooth connectivity (legacy)
- **permission_handler**: ^11.3.1 - Runtime permissions
- **shared_preferences**: ^2.4.0 - Local data persistence
- **intl**: Internationalization and localization

### Build Tools
- **flutter_launcher_icons**: ^0.13.1 - Automated icon generation
- **Gradle**: Kotlin DSL build configuration
- **Java 21**: Build toolchain compatibility

## 🏗 Architecture

### Design Pattern
The app follows a **hybrid architecture** combining:
- **Stateful Widgets**: For UI state management
- **Service Layer Pattern**: Separated business logic (`FirebaseService`, `PdfReportService`)
- **Model-View Pattern**: Data models separate from UI (`UserProfile`, `DiagnosisRecord`)

### State Management
- **Connection Flow**: Enum-based step navigation (`ConnectionStep`)
  - `initial` → `connecting` → `selectPosition` → `listening` → `results`
- **Local State**: `setState()` for UI updates
- **Provider**: Language preference management

### Data Flow
```
User Input → Home Page → Firebase Service → Firestore
                ↓
         Analysis Engine → Waveform Painters → Results
                ↓
         PDF Service → Report Generation → Share
```

## 📦 Prerequisites

### Development Environment
- **Flutter SDK**: 3.9.0 or higher
- **Dart SDK**: 3.9.0 or higher
- **Java**: OpenJDK 21 (for Android builds)
- **Android Studio** / **VS Code**: With Flutter extensions
- **Xcode**: 14+ (for iOS builds, macOS only)

### Platform Requirements
- **Android**: 
  - minSdk: 21 (Android 5.0 Lollipop)
  - targetSdk: Latest Flutter default
  - compileSdk: Latest Flutter default
- **iOS**: 
  - Deployment target: iOS 12.0+
- **Desktop**: Windows, macOS, Linux support (experimental)

### Firebase Account
- Active Firebase project with:
  - Authentication enabled (Email/Password provider)
  - Cloud Firestore database
  - google-services.json (Android) / GoogleService-Info.plist (iOS)

## 🚀 Installation

### 1. Clone Repository
```bash
git clone https://github.com/ARNAVVGUPTAA/StethApp.git
cd StethApp
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure Firebase
See [Firebase Setup](#firebase-setup) section below.

### 4. Generate Launcher Icons
```bash
flutter pub run flutter_launcher_icons
```

### 5. Run the App
```bash
# Development mode
flutter run

# Production build
flutter build apk --release  # Android
flutter build ipa --release  # iOS
```

## 🔥 Firebase Setup

### Step 1: Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add Project" and follow the wizard
3. Enable Google Analytics (optional)

### Step 2: Enable Authentication
1. Navigate to **Authentication** → **Sign-in method**
2. Enable **Email/Password** provider
3. (Optional) Configure email templates

### Step 3: Create Firestore Database
1. Navigate to **Firestore Database**
2. Click "Create database"
3. Start in **test mode** (change security rules for production)
4. Choose a Firestore location

### Security Rules (Development)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.time < timestamp.date(2026, 1, 1);
    }
  }
}
```

### Step 4: Add Android App
1. Click **Add App** → **Android**
2. Enter package name: `com.stethapp.medical`
3. Download `google-services.json`
4. Place in `android/app/google-services.json`

### Step 5: Add iOS App
1. Click **Add App** → **iOS**
2. Enter bundle ID: `com.stethapp.medical`
3. Download `GoogleService-Info.plist`
4. Place in `ios/Runner/GoogleService-Info.plist`
5. Update Xcode project with the plist file

### Step 6: Update Firebase Configuration
The app uses the following Firestore collections:
- `users/` - User profile data
  - Fields: `uid`, `name`, `age`, `sex`, `medicalProblems`, `lastHeartRate`, `lastDiagnosis`, `lastDiagnosisDate`
- `diagnosis_history/` - Diagnosis records
  - Fields: `userId`, `diagnosis`, `heartRate`, `timestamp`, `confidence`, `riskLevel`

## 📁 Project Structure

```
stethapp/
├── android/                    # Android platform code
│   ├── app/
│   │   ├── google-services.json # Firebase config (not in repo)
│   │   └── build.gradle.kts     # App-level build config
│   ├── build.gradle.kts         # Project-level build config
│   └── settings.gradle.kts      # Gradle settings
├── ios/                         # iOS platform code
│   └── Runner/
│       └── GoogleService-Info.plist # Firebase config (not in repo)
├── lib/
│   ├── main.dart                # App entry point
│   ├── login_page.dart          # Authentication UI
│   ├── signup_page.dart         # User registration
│   ├── home_page.dart           # Main application flow
│   ├── auth_service.dart        # Supabase auth (legacy)
│   ├── bluetooth_service.dart   # Bluetooth connectivity (legacy)
│   ├── audio_processor.dart     # Audio signal processing
│   ├── stethoscope_model.dart   # TFLite model inference
│   ├── dsp_logmel.dart          # DSP operations
│   ├── language_provider.dart   # Localization provider
│   ├── l10n/                    # Localization files
│   │   ├── app_en.arb
│   │   ├── app_es.arb
│   │   ├── app_fr.arb
│   │   ├── app_de.arb
│   │   ├── app_hi.arb
│   │   └── app_localizations_*.dart
│   ├── models/
│   │   └── user_profile.dart    # User data models
│   ├── services/
│   │   ├── firebase_service.dart # Firebase operations
│   │   └── pdf_report_service.dart # PDF generation
│   └── pages/
│       ├── profile_setup_page.dart # User onboarding
│       └── patient_history_page.dart # Diagnosis history
├── assets/
│   ├── models/
│   │   ├── best_model.tflite    # TFLite model
│   │   └── simple_compatible_model.tflite
│   ├── icon/
│   │   └── co-logo.png          # App icon
│   ├── pneumonia+tb/            # Audio samples (Pneumonia/TB)
│   └── copd+asthma/             # Audio samples (COPD/Asthma)
├── pubspec.yaml                 # Package dependencies
├── analysis_options.yaml        # Lint rules
└── l10n.yaml                    # Localization config
```

## 🔑 Key Components

### 1. Home Page (`home_page.dart`)
**Purpose**: Main application flow orchestration

**Key Features**:
- Connection step state machine
- Medical waveform rendering with `CustomPaint`
- Timer-based countdown (25 seconds)
- Random risk generation (5% or 10%)
- PDF report generation trigger

**Waveform Painters**:
- `MedicalWaveformPainter`: Renders realistic ECG and breath sounds
  - Heart mode: QRS complex, T-wave, noise artifacts
  - Lung mode: Inhale/exhale cycles with turbulence

**State Enum**:
```dart
enum ConnectionStep {
  initial,        // WiFi connection screen
  connecting,     // Connection animation
  selectPosition, // Heart/Lung selection
  listening,      // 25s analysis with waveform
  results        // Risk assessment display
}
```

### 2. Firebase Service (`services/firebase_service.dart`)
**Purpose**: Firebase Authentication and Firestore operations

**Methods**:
- `signUp(email, password)`: User registration
- `signIn(email, password)`: User authentication
- `signOut()`: User logout
- `createUserProfile(UserProfile)`: Store user data in Firestore
- `getUserProfile(uid)`: Retrieve user profile
- `addDiagnosisRecord(userId, diagnosis)`: Save diagnosis history
- `getDiagnosisHistory(userId)`: Fetch patient history

**Collections**:
- `users/{uid}`: User profile documents
- `users/{uid}/diagnoses/{diagnosisId}`: Nested diagnosis records

### 3. PDF Report Service (`services/pdf_report_service.dart`)
**Purpose**: Generate professional medical reports

**Features**:
- A4 format with proper margins
- Color-coded risk assessment (green/orange)
- Patient information table
- Diagnosis history table (last 10 records)
- Statistics summary
- Professional header/footer

**Methods**:
- `generateMedicalReport(profile, riskPercentage, recommendation)`: Create PDF file
- `sharePdf(File)`: System share sheet integration
- `printPdf(profile)`: Direct printing support

### 4. User Profile Model (`models/user_profile.dart`)
**Purpose**: Data structure for user information

**Fields**:
```dart
- uid: String              // Firebase user ID
- name: String             // Full name
- age: int                 // Age in years
- sex: String              // Sex (Male/Female/Other)
- medicalProblems: List<String>  // Existing conditions
- lastHeartRate: double?   // Latest reading
- lastDiagnosis: String?   // Latest result
- lastDiagnosisDate: DateTime?
- diagnosisHistory: List<DiagnosisRecord>
```

**DiagnosisRecord**:
```dart
- diagnosis: String        // Result text
- heartRate: double        // BPM reading
- timestamp: DateTime      // Record date/time
- confidence: double?      // ML confidence score
- riskLevel: String?       // Low/Medium/High
```

### 5. Stethoscope Model (`stethoscope_model.dart`)
**Purpose**: TensorFlow Lite model inference

**Features**:
- Dual model support (Pneumonia/TB, COPD/Asthma)
- Audio file prediction from assets
- Softmax probability calculation
- Risk level determination

**Methods**:
- `loadModel(DiseaseCategory)`: Load TFLite model
- `predictFromFile(audioFile)`: Run inference
- `predictWithYielding(audioData)`: Non-blocking prediction

## ⚙️ Build Configuration

### Android Gradle Setup

**Key Settings** (`android/app/build.gradle.kts`):
```kotlin
android {
    namespace = "com.stethapp.medical"
    compileSdk = flutter.compileSdkVersion
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }
    
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_21.toString()
    }
}
```

**Signing Configuration**:
1. Create `android/key.properties`:
```properties
storeFile=/path/to/keystore.jks
storePassword=<password>
keyAlias=<alias>
keyPassword=<password>
```

2. Generate keystore:
```bash
keytool -genkey -v -keystore ~/keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias stethapp
```

### ProGuard Rules
Located in `android/app/proguard-rules.pro`:
- Preserves Firebase classes
- Keeps TFLite model structure
- Maintains PDF library functionality

## 🌍 Localization

### Supported Languages
- **English** (en) - Default
- **Spanish** (es)
- **French** (fr)
- **German** (de)
- **Hindi** (hi)

### Adding New Languages
1. Create ARB file: `lib/l10n/app_<locale>.arb`
2. Add translations following `app_en.arb` structure
3. Run code generation:
```bash
flutter gen-l10n
```
4. Update `LanguageProvider` in `language_provider.dart`

### Usage in Code
```dart
final l10n = AppLocalizations.of(context)!;
Text(l10n.connectStethoscope);
```

## 👥 Contributing

### Getting Started
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

### Code Style
- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter analyze` before committing
- Run `dart format .` to format code
- Ensure all tests pass

### Commit Convention
```
<type>(<scope>): <subject>

Types: feat, fix, docs, style, refactor, test, chore
Example: feat(auth): add password reset functionality
```

## 🐛 Known Issues

### Current Limitations
1. **WiFi Connection**: Currently simulated - real device integration pending
2. **ML Model**: Uses placeholder predictions - requires trained model deployment
3. **Offline Mode**: No offline analysis capability
4. **Waveform Accuracy**: Simulated medical waveforms for demonstration purposes

### Troubleshooting

**Build Errors**:
```bash
# Clean build cache
flutter clean
flutter pub get
cd android && ./gradlew clean
cd ..
flutter build apk
```

**Firebase Connection Issues**:
- Verify `google-services.json` is present
- Check package name matches Firebase console
- Ensure SHA-1 fingerprint is registered (for production)

**TFLite Model Errors**:
- Model must use FULLY_CONNECTED v11 or lower
- Compatible with TensorFlow 2.8-2.14
- Run `python check_model_versions.py` to verify

**PDF Generation Fails**:
- Check `path_provider` permissions
- Ensure storage permissions granted on Android 11+

## 📄 License

This project is private and proprietary. All rights reserved.

## 📞 Contact

**Project Maintainer**: ARNAVVGUPTAA
**Repository**: [StethApp](https://github.com/ARNAVVGUPTAA/StethApp)

---

**Version**: 2.0.0  
**Last Updated**: December 2025  
**Flutter Version**: 3.9.0  
**Minimum Android**: 5.0 (API 21)  
**Minimum iOS**: 12.0
