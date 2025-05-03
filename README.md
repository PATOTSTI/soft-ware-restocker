# ReStckr - Inventory Management App

## Firebase Setup Instructions

1. After cloning the repository, you need to set up Firebase configuration:

   a. Copy the template file:
   ```bash
   cp lib/firebase_options.template.dart lib/firebase_options.dart
   ```

   b. Replace the placeholder values in `firebase_options.dart` with the actual Firebase configuration values:
   - Web API Key
   - Android API Key
   - iOS API Key
   - Windows API Key
   - App IDs
   - Project ID
   - Other configuration values

2. Get the Firebase configuration values from your team lead or project administrator.

3. Make sure you have the following dependencies in your `pubspec.yaml`:
   ```yaml
   dependencies:
     firebase_core: ^latest_version
     firebase_auth: ^latest_version
     cloud_firestore: ^latest_version
   ```

4. Run `flutter pub get` to install dependencies

5. Initialize Firebase in your app (already done in `main.dart`)

## Important Notes
- Never commit `firebase_options.dart` to the repository
- Keep your Firebase configuration values secure
- If you need to regenerate Firebase configuration, use the FlutterFire CLI:
  ```bash
  flutterfire configure
  ```

## Troubleshooting
If you encounter Firebase initialization errors:
1. Verify that `firebase_options.dart` exists and contains correct values
2. Check that all Firebase dependencies are properly installed
3. Ensure you have the correct Firebase project selected
4. Verify that the Firebase project is properly set up in the Firebase Console
