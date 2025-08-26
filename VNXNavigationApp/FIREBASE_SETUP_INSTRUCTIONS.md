# Firebase Setup Instructions

## Prerequisites
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select an existing one

## Step 1: Add iOS App to Firebase
1. Click "Add app" → iOS
2. Enter your Bundle ID (found in Xcode project settings)
3. Download the `GoogleService-Info.plist` file

## Step 2: Add GoogleService-Info.plist to Your Project
1. Drag the downloaded `GoogleService-Info.plist` file into the Xcode project navigator
2. Make sure to:
   - Select "Copy items if needed"
   - Add to target: VNXNavigationApp
   - Place it in the root folder (same level as Info.plist)

## Step 3: Enable Authentication
1. In Firebase Console, go to Authentication → Sign-in method
2. Enable "Email/Password" provider

## Step 4: Set up Firestore Database
1. Go to Firestore Database in Firebase Console
2. Click "Create database"
3. Choose production mode or test mode (test mode for development)
4. Select your preferred location

## Step 5: Add Firebase SDK Dependencies in Xcode
1. In Xcode, go to File → Add Package Dependencies
2. Enter the Firebase SDK URL: `https://github.com/firebase/firebase-ios-sdk`
3. Choose the latest version
4. Add these packages:
   - FirebaseAuth
   - FirebaseFirestore
   - FirebaseFirestoreSwift

## Step 6: Security Rules for Firestore
Add these rules in Firestore Database → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow users to read and write their own user document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Step 7: Build and Run
1. Clean build folder (Cmd+Shift+K)
2. Build the project (Cmd+B)
3. Run on simulator or device

## Testing the App
1. Sign up with a new account selecting either Anchor or Navigator role
2. Check Firebase Console → Authentication to see the new user
3. Check Firestore Database → users collection to see user data with role
4. Sign out and sign back in to verify persistence
5. Test password reset functionality

## Troubleshooting
- If build fails with "No such module 'FirebaseCore'", make sure packages are properly added
- If authentication fails, check that Email/Password is enabled in Firebase Console
- If Firestore writes fail, check security rules and that database is created