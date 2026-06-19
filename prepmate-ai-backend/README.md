# PrepMate AI — Backend

> **AI-powered study platform backend** built with FastAPI, Firebase, and Gemini AI.

---

## Architecture Overview

```
prepmate/
├── app/
│   ├── main.py                  # FastAPI app, middleware, router registration
│   ├── core/
│   │   ├── config.py            # Pydantic settings (env vars)
│   │   ├── firebase.py          # Firebase Admin SDK initialization
│   │   ├── gemini.py            # Gemini AI client + retry logic
│   │   └── dependencies.py      # Auth dependency (Firebase token verification)
│   ├── middleware/
│   │   └── rate_limiter.py      # Sliding-window rate limiter
│   ├── models/
│   │   └── schemas.py           # All Pydantic request/response models
│   ├── routers/
│   │   ├── auth.py              # GET/PUT /api/v1/auth/me
│   │   ├── chatbot.py           # POST /api/v1/chat/send + sessions
│   │   ├── pdf_processing.py    # POST /api/v1/pdf/upload
│   │   ├── notes_generator.py   # POST /api/v1/notes/generate
│   │   ├── mcq_generator.py     # POST /api/v1/mcq/generate + submit
│   │   ├── study_planner.py     # POST /api/v1/planner/generate
│   │   └── analytics.py        # GET  /api/v1/analytics/dashboard
│   └── services/
│       ├── auth_service.py      # User profile CRUD
│       ├── chatbot_service.py   # Chat sessions + Gemini history
│       ├── pdf_service.py       # PDF text extraction + OCR
│       ├── notes_service.py     # Summaries, flashcards, questions
│       ├── mcq_service.py       # MCQ generation (batched) + scoring
│       ├── planner_service.py   # Study plan generation + streaks
│       └── analytics_service.py # Dashboard aggregation + badges
├── tests/
│   └── test_api.py
├── .env.example
├── Dockerfile
├── render.yaml                  # Render.com deployment
├── railway.toml                 # Railway.app deployment
└── requirements.txt
```

---

## Quick Start (Local)

### Prerequisites
- Python 3.11+
- [Tesseract OCR](https://github.com/tesseract-ocr/tesseract) installed on system
- Firebase project with Firestore + Auth enabled
- Google AI Studio API key (Gemini)

### 1. Install system dependencies

```bash
# Ubuntu/Debian
sudo apt-get install tesseract-ocr tesseract-ocr-eng

# macOS
brew install tesseract

# Windows
# Download installer from: https://github.com/UB-Mannheim/tesseract/wiki
```

### 2. Clone and install

```bash
git clone https://github.com/your-org/prepmate-backend.git
cd prepmate-backend
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 3. Configure environment

```bash
cp .env.example .env
# Edit .env with your Firebase and Gemini credentials
```

### 4. Firebase setup

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a project → Enable **Firestore** and **Authentication**
3. Go to Project Settings → Service Accounts → Generate new private key
4. Save as `firebase-service-account.json` in project root
5. Set `FIREBASE_CREDENTIALS_PATH=./firebase-service-account.json` in `.env`

### 5. Run the server

```bash
uvicorn app.main:app --reload --port 8000
```

Open **http://localhost:8000/docs** for interactive Swagger UI.

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Service info |
| GET | `/health` | Health check |
| GET | `/api/v1/auth/me` | Get user profile |
| PUT | `/api/v1/auth/me` | Update profile |
| POST | `/api/v1/chat/send` | Send chat message |
| GET | `/api/v1/chat/sessions` | List chat sessions |
| GET | `/api/v1/chat/sessions/{id}` | Get session history |
| DELETE | `/api/v1/chat/sessions/{id}` | Delete session |
| POST | `/api/v1/pdf/upload` | Upload PDF/image |
| GET | `/api/v1/pdf/` | List documents |
| GET | `/api/v1/pdf/{id}` | Get document + text |
| DELETE | `/api/v1/pdf/{id}` | Delete document |
| POST | `/api/v1/notes/generate` | Generate notes |
| GET | `/api/v1/notes/{id}` | Get notes |
| POST | `/api/v1/mcq/generate` | Generate MCQ set |
| POST | `/api/v1/mcq/submit` | Submit answers |
| GET | `/api/v1/mcq/sets` | List MCQ sets |
| GET | `/api/v1/mcq/sets/{id}` | Get MCQ set |
| POST | `/api/v1/planner/generate` | Generate study plan |
| GET | `/api/v1/planner/` | List plans |
| GET | `/api/v1/planner/{id}` | Get plan |
| PATCH | `/api/v1/planner/task/complete` | Mark task complete |
| GET | `/api/v1/analytics/dashboard` | Analytics dashboard |

---

## Authentication

All endpoints (except `/` and `/health`) require a Firebase ID token:

```bash
Authorization: Bearer <firebase-id-token>
```

Get the token from your frontend using Firebase Auth SDK:
```javascript
const token = await firebase.auth().currentUser.getIdToken();
```

---

## Firestore Collections

| Collection | Description |
|-----------|-------------|
| `users` | User profiles |
| `chat_sessions` | Chat session history (keyed: `{uid}_{session_id}`) |
| `pdf_documents` | PDF metadata + extracted text |
| `generated_notes` | Notes, flashcards, questions |
| `mcq_sets` | MCQ questions + answer keys |
| `mcq_attempts` | Submitted attempts + scores |
| `study_plans` | Multi-day study plans |
| `user_analytics` | Aggregated stats, streaks, badges |

---

## Deployment

### Render.com

1. Push code to GitHub
2. Go to [render.com](https://render.com) → New Web Service → Connect repo
3. Render auto-detects `render.yaml`
4. Add environment variables in Render dashboard
5. Deploy!

### Railway.app

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login and deploy
railway login
railway init
railway up
```

Set environment variables in Railway dashboard → Variables tab.

### Docker

```bash
docker build -t prepmate-backend .
docker run -p 8000:8000 --env-file .env prepmate-backend
```

---

## Testing

```bash
pytest tests/ -v
```

---

## Environment Variables Reference

| Variable | Required | Description |
|----------|----------|-------------|
| `FIREBASE_PROJECT_ID` | ✅ | Firebase project ID |
| `FIREBASE_CREDENTIALS_JSON` | ✅* | Service account JSON (Render/Railway) |
| `FIREBASE_CREDENTIALS_PATH` | ✅* | Path to service account file (local) |
| `FIREBASE_STORAGE_BUCKET` | ✅ | Firebase Storage bucket name |
| `GEMINI_API_KEY` | ✅ | Google AI Studio API key |
| `SECRET_KEY` | ✅ | App secret (auto-generated on Render) |
| `ALLOWED_ORIGINS` | ✅ | Comma-separated CORS origins |
| `ENVIRONMENT` | ➖ | development / production |
| `UPLOAD_DIR` | ➖ | Temp upload directory (default: /tmp) |
| `MAX_UPLOAD_SIZE_MB` | ➖ | Max PDF size (default: 50) |
| `RATE_LIMIT_REQUESTS` | ➖ | Requests per window (default: 100) |
| `GEMINI_MODEL` | ➖ | Fast model (default: gemini-1.5-flash) |
| `GEMINI_PRO_MODEL` | ➖ | Quality model (default: gemini-1.5-pro) |

*One of `FIREBASE_CREDENTIALS_JSON` or `FIREBASE_CREDENTIALS_PATH` required.
