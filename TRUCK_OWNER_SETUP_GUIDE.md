# Truck Owner Setup Guide

## How to Connect a Food Truck to a User

The system matches food trucks to users based on unique truck IDs and the `ownerId` field in Firestore.

### Step 1: Food Trucks (Already Created)

The food trucks are defined in `lib/data/mock_food_trucks.dart` with unique IDs:
- `truck1` - Burger Express
- `truck2` - Taco Fiesta  
- `truck3` - Pizza Corner
- `truck4` - Sushi Roll

### Step 2: Set Up User in Firestore

1. Go to **Firebase Console** → **Firestore Database**
2. Navigate to the `users` collection
3. Find or create the user document you want to make a truck owner
4. Set the following fields:
   - **`role`**: `"truck owner"` (must be exactly this, with a space)
   - **`ownerId`**: One of the truck IDs (`truck1`, `truck2`, `truck3`, or `truck4`)

### Example User Document in Firestore:

```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "role": "truck owner",
  "ownerId": "truck4"
}
```

### Step 3: How It Works

When a user logs in:
1. The system checks if `role == "truck owner"`
2. If yes, it gets the `ownerId` field from the user document
3. It searches `mockFoodTrucks` for a truck where `truck.id == ownerId`
4. If found, it shows the **Truck Owner Dashboard** for that specific truck

### Step 4: Test It

1. Log in with a user that has:
   - `role: "truck owner"`
   - `ownerId: "truck4"` (or any truck ID)
2. You should see the **Truck Owner Dashboard** with that truck's name
3. You'll be able to:
   - View orders for that truck
   - Manage menu items for that truck
   - Update order statuses

### Pre-Seeded Truck Owner Test Accounts

The following accounts are for **Taco Fiesta (truck2)** and **Pizza Corner (truck3)**. Run the seed script to create them:

| Email | Truck | ownerId | Password |
|-------|-------|---------|----------|
| test9@gmail.com | Taco Fiesta | truck2 | UniPick123! |
| test10@gmail.com | Pizza Corner | truck3 | UniPick123! |
| test11@gmail.com | Sushi Roll | truck4 | UniPick123! |

**Truck owner accounts do not require email verification** – they bypass the verification screen.

To create these accounts:

```bash
cd functions
# Option 1: Use Firebase default credentials (after firebase login)
npm run seed-truck-owners

# Option 2: Use a service account key
GOOGLE_APPLICATION_CREDENTIALS=path/to/serviceAccountKey.json npm run seed-truck-owners
```

Download a service account key from: Firebase Console → Project Settings → Service Accounts → Generate new private key.

### Important Notes

- The `ownerId` in the user document must **exactly match** one of the truck IDs in `mock_food_trucks.dart`
- If `ownerId` doesn't match any truck, the user will see "Truck not found"
- If the user doesn't have `role: "truck owner"`, they'll see the regular customer UI
- Orders are filtered by `truckId` when displayed to truck owners




