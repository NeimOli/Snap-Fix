# Social Login Setup

This document explains how to set up Google and Facebook sign-in for the SnapFix app.

## Google Sign-In Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the Google Sign-In API
4. Create OAuth 2.0 credentials:
   - Application type: Android app
   - Package name: `prototype_ui` (from pubspec.yaml)
   - SHA-1 fingerprint: Get from your debug keystore
5. Download the `google-services.json` file and place it in `android/app/`

## Facebook Sign-In Setup

1. Go to [Facebook Developers](https://developers.facebook.com/)
2. Create a new app or select an existing one
3. Add Facebook Login product
4. Configure Android platform:
   - Package name: `prototype_ui`
   - Default Activity class name: `com.example.prototype_ui.MainActivity`
5. Add your key hash to Facebook app settings
6. Download the Facebook SDK and add to your Android project

## Backend Configuration

The backend has a basic social login endpoint at `/api/auth/social-login` that:
- Accepts provider, token, email, and fullName
- Creates a new user if they don't exist
- Returns a JWT token

## Current Implementation

The Flutter app now includes:
- Google Sign-In button with Google icon
- Facebook Sign-In button with Facebook icon
- Basic authentication flow that sends social tokens to backend
- Error handling for cancelled or failed sign-ins

## Notes

- The backend currently doesn't verify the social tokens (for simplicity)
- In production, you should verify tokens with Google/Facebook APIs
- The app will show fallback icons if logo assets are not found
