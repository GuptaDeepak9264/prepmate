# 🎓 PrepMate AI — Flutter Study App

A production-ready Flutter application for AI-powered study preparation with Firebase backend integration.

---

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry point
├── firebase_options.dart              # Firebase config (replace with yours)
├── core/
│   ├── constants/
│   │   └── app_constants.dart         # App-wide constants & strings
│   ├── navigation/
│   │   └── app_router.dart            # GoRouter configuration
│   ├── theme/
│   │   └── app_theme.dart             # Material 3 theme, colors, typography
│   └── widgets/
│       ├── common_widgets.dart        # Reusable UI components
│       └── main_scaffold.dart         # Bottom nav shell
└── features/
    ├── auth/                          # Authentication
    │   ├── data/repositories/
    │   ├── domain/entities/
    │   └── presentation/
    │       ├── providers/auth_provider.dart
    │       └── screens/ (login, signup, forgot_password)
    ├── dashboard/                     # Home dashboard
    │   ├── domain/entities/
    │   └── presentation/
    │       ├── providers/dashboard_provider.dart
    │       └── screens/dashboard_screen.dart
    ├── pdf_library/                   # PDF management
    │   ├── data/repositories/
    │   ├── domain/entities/
    │   └── presentation/
    │       ├── providers/pdf_provider.dart
    │       └── screens/ (library, viewer, upload)
    ├── ai_chat/                       # AI tutor chat
    │   ├── data/repositories/
    │   ├── domain/entities/
    │   └── presentation/
    │       ├── providers/chat_provider.dart
    │       └── screens/ (chat, history)
    ├── mcq/                           # MCQ practice
    │   ├── domain/entities/
    │   └── presentation/
    │       ├── providers/mcq_provider.dart
    │       └── screens/ (topic, question, result)
    ├── planner/                       # Daily task planner
    │   ├── data/repositories/
    │   ├── domain/entities/
    │   └── presentation/
    │       ├── providers/planner_provider.dart
    │       └── screens/planner_screen.dart
    └── profile/                       # User profile
        └── presentation/
            ├── providers/profile_provider.dart
            └── screens/profile_screen.dart
```

---

## 🚀 Quick Start

### 1. Prerequisites
- Flutter SDK ≥ 3.0.0
- Dart SDK ≥ 3.0.0
- Firebase CLI
- FlutterFire CLI

### 2. Clone & Install

```bash
git clone <repo>
cd prepmate_ai
flutter pub get
```

### 3. Firebase Setup

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase (creates firebase_options.dart automatically)
flutterfire configure
```

Then place your `google-services.json` in `android/app/`.

Enable in Firebase Console:
- ✅ Authentication → Email/Password
- ✅ Firestore Database
- ✅ Storage

### 4. AI Service Configuration

In `lib/features/ai_chat/presentation/providers/chat_provider.dart`:

```dart
final aiServiceProvider = Provider<AiService>((ref) {
  return OpenAiService(
    apiKey: 'YOUR_OPENAI_API_KEY',  // ← Add your key
    model: 'gpt-4o-mini',
  );
});
```

Or pass via `--dart-define`:
```bash
flutter run --dart-define=OPENAI_API_KEY=sk-xxx
```

### 5. Run the App

```bash
flutter run
```

---

## 🔧 Tech Stack

| Layer | Technology |
|-------|-----------|
| UI Framework | Flutter + Material 3 |
| State Management | Riverpod 2.x |
| Navigation | GoRouter |
| Auth | Firebase Auth |
| Database | Cloud Firestore |
| Storage | Firebase Storage |
| PDF Viewing | flutter_pdfview |
| Animations | flutter_animate |
| AI | OpenAI-compatible REST API |

---

## 🏗️ Architecture

Clean Architecture with feature-first folder organization:

- **Domain Layer**: Entities, repository interfaces
- **Data Layer**: Firebase repository implementations
- **Presentation Layer**: Riverpod providers, screens, widgets

### State Management Pattern
- `StreamProvider` — Real-time Firestore streams
- `StateNotifierProvider` — Complex mutable state (auth, upload, MCQ)
- `FutureProvider` — One-shot async operations
- `Provider` — Dependencies (repositories, services)

---

## 📋 Firestore Schema

```
users/{uid}
  ├── name, email, photoUrl, createdAt, studyStreak, ...
  ├── pdfs/{pdfId}
  │     ├── name, url, category, sizeBytes, pageCount, lastReadPage, uploadedAt
  ├── chats/{chatId}
  │     ├── title, messages[], createdAt, updatedAt
  ├── mcq_sessions/{sessionId}
  │     ├── topic, difficulty, score, total, questions[], createdAt
  ├── tasks/{taskId}
  │     ├── title, description, isCompleted, dueDate, priority, createdAt
  └── streaks/current
        ├── currentStreak, longestStreak, activeDays[], lastStudyDate
```

---

## 🔐 Security

- Firestore rules: Users can only access their own data
- Storage rules: 50MB PDF limit, image type validation
- Auth: Email/password with Firebase Auth
- API keys: Use `--dart-define` or secure storage for production

---

## 📦 Release Build

```bash
# Generate keystore (first time)
keytool -genkey -v -keystore prepmate.jks -alias prepmate -keyalg RSA -keysize 2048 -validity 10000

# Build release APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release
```

---

## 🧩 Extending the AI

The `AiService` abstract class makes it trivial to swap providers:

```dart
// Anthropic Claude
class ClaudeService implements AiService { ... }

// Google Gemini  
class GeminiService implements AiService { ... }

// Local model (Ollama)
class OllamaService implements AiService { ... }
```

Just implement `sendMessage()` and update `aiServiceProvider`.

---

## 📝 License

MIT © PrepMate AI
