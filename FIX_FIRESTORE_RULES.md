# 🔧 Fix Firestore Permission Error

## Problem
You're seeing this error:
```
PERMISSION_DENIED: Missing or insufficient permissions
Write failed at orders/order_1769275816421
```

## Solution: Update Firestore Security Rules

### Step 1: Go to Firebase Console
1. Open [Firebase Console](https://console.firebase.google.com/)
2. Select your project (`test_app2` or your project name)
3. Click on **Firestore Database** in the left sidebar
4. Click on the **Rules** tab at the top

### Step 2: Copy and Paste These Rules

**For Development/Testing (Recommended to start):**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read/write orders
    match /orders/{orderId} {
      allow read, write: if request.auth != null;
    }
    
    // Allow users to manage their own user document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

**For Production (More Secure):**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Orders collection - users can only create/read their own orders
    match /orders/{orderId} {
      // Allow creating orders where userId matches authenticated user
      allow create: if request.auth != null 
                    && request.resource.data.userId == request.auth.uid;
      
      // Allow reading own orders
      allow read: if request.auth != null 
                 && resource.data.userId == request.auth.uid;
      
      // Allow updating own orders
      allow update: if request.auth != null 
                   && resource.data.userId == request.auth.uid;
    }
  }
}
```

### Step 3: Publish the Rules
1. Click the **Publish** button
2. Wait for confirmation that rules are published

### Step 4: Test Again
1. Go back to your Flutter app
2. Make a payment and wait for it to be confirmed as "PAID"
3. Check the terminal - you should now see:
   ```
   ✅✅✅ Order successfully saved to Firestore 'orders' collection! ✅✅✅
   ```
4. Go to Firebase Console → Firestore Database → Data tab
5. You should now see an `orders` collection with your order documents!

## Quick Test
You can also use the "Test Firestore Connection" button on the home screen to verify the rules are working.

## Notes
- The development rules allow any authenticated user to write to orders (good for testing)
- The production rules only allow users to create orders with their own userId (more secure)
- Make sure you're logged in to the app when testing




