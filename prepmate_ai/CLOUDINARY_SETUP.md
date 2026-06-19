# ☁️ Cloudinary Setup Guide — PrepMate AI

PrepMate AI uses **Cloudinary** for all file storage (PDFs + avatars).
Firebase Auth and Firestore are still used for authentication and metadata.

---

## 1. Create a Cloudinary Account

Sign up at → https://cloudinary.com/users/register_free

---

## 2. Get Your Cloud Name

Dashboard → top-left → copy **Cloud name** (e.g. `dxyz1234`)

---

## 3. Create an Unsigned Upload Preset

> Settings → Upload → **Upload Presets** → Add upload preset

| Field              | Value                        |
|--------------------|------------------------------|
| Preset name        | `prepmate_unsigned`          |
| Signing mode       | **Unsigned**                 |
| Folder             | `prepmate`                   |
| Allowed formats    | `pdf, jpg, jpeg, png, webp`  |
| Max file size      | `52428800` (50 MB)           |
| Unique filename    | ✅ ON                        |
| Overwrite          | ✅ ON (for avatars)          |

Click **Save**.

---

## 4. Inject Credentials into Flutter

### Option A — dart-define (recommended for CI/CD)

```bash
flutter run \
  --dart-define=CLOUDINARY_CLOUD_NAME=dxyz1234 \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=prepmate_unsigned
```

For release builds:

```bash
flutter build apk --release \
  --dart-define=CLOUDINARY_CLOUD_NAME=dxyz1234 \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=prepmate_unsigned
```

### Option B — Hard-code (quick local dev only)

Open `lib/core/constants/app_constants.dart` and replace the defaultValues:

```dart
static const String cloudinaryCloudName = String.fromEnvironment(
  'CLOUDINARY_CLOUD_NAME',
  defaultValue: 'dxyz1234',           // ← your cloud name
);
static const String cloudinaryUploadPreset = String.fromEnvironment(
  'CLOUDINARY_UPLOAD_PRESET',
  defaultValue: 'prepmate_unsigned',  // ← your preset name
);
```

⚠️ Never commit real credentials to source control.

---

## 5. Folder Structure in Cloudinary

```
prepmate/
├── pdfs/
│   └── {userId}/
│       └── {uuid}.pdf      ← uploaded PDFs
└── avatars/
    └── {userId}.jpg        ← profile pictures
```

---

## 6. PDF Deletion (Server-Side Required)

Cloudinary deletion from a mobile client requires your **API Secret**, which
must never be shipped in the app binary.

The recommended pattern is a **Firebase Cloud Function**:

```javascript
// functions/index.js
const { onCall } = require("firebase-functions/v2/https");
const cloudinary = require("cloudinary").v2;

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

exports.deleteCloudinaryAsset = onCall(async (request) => {
  const { publicId, resourceType = "raw" } = request.data;
  if (!request.auth) throw new Error("Unauthenticated");
  return cloudinary.uploader.destroy(publicId, { resource_type: resourceType });
});
```

Deploy:

```bash
firebase functions:config:set \
  cloudinary.cloud_name="dxyz1234" \
  cloudinary.api_key="YOUR_KEY" \
  cloudinary.api_secret="YOUR_SECRET"

firebase deploy --only functions
```

Then in `pdf_repository.dart`, uncomment and call the Cloud Function via
`cloud_functions` package instead of the stub.

---

## 7. Cloudinary Free Tier Limits

| Resource        | Free Tier      |
|-----------------|----------------|
| Storage         | 25 GB          |
| Bandwidth       | 25 GB / month  |
| Transformations | 25 credits/mo  |

Sufficient for development and small-scale production.

---

## 8. Architecture Summary

```
Mobile App
    │
    ├─► Firebase Auth        ← login / signup / persistent session
    ├─► Cloud Firestore      ← PDF metadata, chat history, tasks, MCQ sessions
    │
    └─► Cloudinary REST API  ← PDF & avatar binary storage
            │
            └─ Returns secure_url  ─► stored in Firestore pdf.url field
```

The `CloudinaryService` in `lib/core/services/cloudinary_service.dart`
is the single integration point. To switch storage providers, implement
the same upload/delete interface and update `PdfRepository` and
`ProfileNotifier` accordingly.
