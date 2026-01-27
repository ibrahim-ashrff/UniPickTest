# Firestore Security Rules for Orders

If you can't see orders in Firestore, you likely need to update your Firestore security rules.

## Current Issue
The app is trying to write to the `orders` collection, but Firestore security rules might be blocking it.

## Solution

Go to Firebase Console → Firestore Database → Rules tab and update your rules to:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own user document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Orders collection - users can create orders and read their own orders
    match /orders/{orderId} {
      // Allow authenticated users to create orders
      allow create: if request.auth != null 
                    && request.resource.data.userId == request.auth.uid;
      
      // Allow users to read their own orders
      allow read: if request.auth != null 
                 && resource.data.userId == request.auth.uid;
      
      // Allow users to update their own orders (for status changes)
      allow update: if request.auth != null 
                   && resource.data.userId == request.auth.uid;
    }
    
    // For testing, you can temporarily allow all writes (NOT RECOMMENDED FOR PRODUCTION)
    // match /orders/{document=**} {
    //   allow read, write: if request.auth != null;
    // }
  }
}
```

## Testing Rules

For development/testing, you can use these more permissive rules (REMOVE BEFORE PRODUCTION):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## How to Update Rules

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Firestore Database** → **Rules** tab
4. Paste the rules above
5. Click **Publish**

## Verify

After updating rules, try making a payment again and check:
1. Terminal logs for any error messages
2. Firestore Console → `orders` collection should show new documents




