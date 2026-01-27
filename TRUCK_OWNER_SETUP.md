# Truck Owner Setup Instructions

## Step 1: Create a Truck Owner User in Firestore

1. Go to Firebase Console → Firestore Database
2. Navigate to the `users` collection
3. Find or create a user document (you can use an existing user or create a new one)
4. Edit the user document and set the `role` field to: `"truck owner"` (exactly as shown, with a space)

## Step 2: Create the Sushi Food Truck in Firestore

1. In Firestore, create a new collection called `food_trucks`
2. Create a new document with ID `truck4` (or any ID you prefer)
3. Add the following fields:
   ```json
   {
     "id": "truck4",
     "name": "Sushi Roll",
     "cuisine": "Japanese",
     "rating": 4.7,
     "imageUrl": "https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=400",
     "description": "Fresh sushi and Japanese cuisine",
     "isOpen": true,
     "ownerId": "YOUR_TRUCK_OWNER_USER_ID"
   }
   ```
   Replace `YOUR_TRUCK_OWNER_USER_ID` with the actual user ID from Step 1.

## Step 3: Create Menu Items for Sushi Roll

1. In Firestore, navigate to `food_trucks` → `truck4` → `menu_items` (subcollection)
2. Create menu items with the following structure:
   ```json
   {
     "name": "Salmon Sushi Roll",
     "description": "Fresh salmon with rice and seaweed",
     "price": 85.0,
     "imageUrl": "https://example.com/sushi.jpg" // optional
   }
   ```

   Example menu items you can create:
   - Salmon Sushi Roll (EGP 85)
   - Tuna Sashimi (EGP 95)
   - California Roll (EGP 70)
   - Miso Soup (EGP 25)
   - Edamame (EGP 30)

## Step 4: Test the Setup

1. Log in with the truck owner account
2. You should see the Truck Owner Dashboard with 3 tabs:
   - **Orders**: View all orders for your food truck
   - **Menu**: Manage menu items (add, edit, delete, adjust prices)
   - **Profile**: View truck and account information

## Notes

- The truck owner can only see orders for their assigned food truck
- Menu items are stored in a subcollection: `food_trucks/{truckId}/menu_items`
- Orders are automatically linked to the food truck via the `truckId` field
- Only users with `role: "truck owner"` will see the truck owner dashboard




