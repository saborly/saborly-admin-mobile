# Firebase Setup Instructions for Admin App

## ✅ Configuration Complete!

The admin app has been fully configured to use the same Firebase project (`saborly-397b6`) as the customer app and backend.

### Files Updated:
1. ✅ `lib/firebase_options.dart` - **Configured with correct admin app ID**
2. ✅ `android/app/google-services.json` - **Updated with correct Firebase project configuration**

### Current Configuration:
- **Project ID**: `saborly-397b6` ✅
- **Project Number**: `420029681993` ✅
- **Admin App ID**: `1:420029681993:android:a5cf60729f9758d0d68a98` ✅
- **Package Name**: `com.saborly.saborly_admin` ✅

## ✅ Verification

All configuration files are now correctly set up! You can verify:

- ✅ `google-services.json` contains:
  - `project_id`: `"saborly-397b6"`
  - `project_number`: `"420029681993"`
  - `package_name`: `"com.saborly.saborly_admin"`
  - `mobilesdk_app_id`: `"1:420029681993:android:a5cf60729f9758d0d68a98"`

- ✅ `firebase_options.dart` contains:
  - `projectId`: `"saborly-397b6"`
  - `messagingSenderId`: `"420029681993"`
  - `appId`: `"1:420029681993:android:a5cf60729f9758d0d68a98"`

### Next Step: Clean and Rebuild

```bash
cd soleyadinoe
flutter clean
flutter pub get
flutter build apk
```

## ✅ Verification

After setup, all three components will use the same Firebase project:
- ✅ **Backend**: `saborly-397b6` (configured in `.env`)
- ✅ **Customer App**: `saborly-397b6` (already configured)
- ✅ **Admin App**: `saborly-397b6` (after completing steps above)

## 🎯 Benefits

1. **No more SenderId mismatch errors** - All apps use the same Firebase project
2. **Unified notifications** - Backend can send notifications to both customer and admin apps
3. **Simplified management** - One Firebase project to manage instead of two

## ⚠️ Important Notes

- ✅ All configuration files are now correctly set up!
- Users with existing FCM tokens from the old project will automatically get new tokens on next app open
- The automatic token cleanup we implemented will handle any mismatched tokens gracefully
- After rebuilding, the admin app will use the same Firebase project as the customer app and backend

