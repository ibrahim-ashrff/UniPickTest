const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// Helper function to get truck name from truckId
async function getTruckName(truckId) {
  if (!truckId) return null;
  
  try {
    // Try to get from Firestore food_trucks collection
    const truckDoc = await db.collection("food_trucks").doc(truckId).get();
    if (truckDoc.exists) {
      const truckData = truckDoc.data();
      return truckData?.name || null;
    }
    
    // Fallback: Check mock trucks (hardcoded names)
    const mockTrucks = {
      truck1: "Burger Express",
      truck2: "Taco Fiesta",
      truck3: "Pizza Corner",
      truck4: "Sushi Roll",
    };
    
    return mockTrucks[truckId] || null;
  } catch (error) {
    console.error(`Error getting truck name for ${truckId}:`, error);
    return null;
  }
}

// Status messages for customer notifications
const STATUS_MESSAGES = {
  preparing: { body: "is being prepared!" },
  ready: { body: "is ready for pickup!" },
  completed: { body: "has been completed. Thank you!" },
  cancelled: { body: "has been cancelled." },
  paid: { body: "was successfully placed!" },
};

/**
 * When a new order is created, send a notification to the customer.
 */
exports.onOrderCreated = functions.firestore
  .document("orders/{orderId}")
  .onCreate(async (snapshot, context) => {
    const orderId = context.params.orderId;
    const orderData = snapshot.data();

    const status = (orderData.status || "").toLowerCase();
    
    // Only notify for paid orders (successful orders)
    if (status !== "paid") {
      console.log(`Order ${orderId}: Status is ${status}, skipping new order notification`);
      return null;
    }

    const userId = orderData.userId;
    if (!userId) {
      console.log(`Order ${orderId}: No userId, skipping notification`);
      return null;
    }

    // Get customer's FCM token
    const userDoc = await db.collection("users").doc(userId).get();
    const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;

    if (!fcmToken) {
      console.log(`Order ${orderId}: No FCM token for user ${userId}`);
      return null;
    }

    // Get truck name
    const truckName = await getTruckName(orderData.truckId);
    const restaurantName = truckName || "UniPick";

    const orderNumber = orderData.displayOrderNumber
      ? `#${orderData.displayOrderNumber}`
      : orderData.merchantRefNumber
        ? `#${String(orderData.merchantRefNumber).slice(0, 6)}`
        : "";

    const title = orderNumber
      ? `Order ${orderNumber} from ${restaurantName}`
      : `Order from ${restaurantName}`;

    const body = `Your order from ${restaurantName} was successfully placed!`;

    const message = {
      token: fcmToken,
      notification: {
        title,
        body,
        sound: "default",
      },
      data: {
        orderId,
        order_id: orderId,
        status: "paid",
        type: "order_created",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "order_updates",
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      await messaging.send(message);
      console.log(`✅ Sent new order notification to user ${userId} for order ${orderId}`);
      return null;
    } catch (error) {
      console.error(`❌ Error sending notification for order ${orderId}:`, error);
      if (error.code === "messaging/invalid-registration-token" ||
          error.code === "messaging/registration-token-not-registered") {
        // Token is invalid, remove it from Firestore
        await db.collection("users").doc(userId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
        console.log(`Removed invalid FCM token for user ${userId}`);
      }
      throw error;
    }
  });

/**
 * When an order document is updated, check if status changed and send
 * push notification to the customer.
 */
exports.onOrderUpdated = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const orderId = context.params.orderId;
    const before = change.before.data();
    const after = change.after.data();

    const previousStatus = (before.status || "").toLowerCase();
    const newStatus = (after.status || "").toLowerCase();

    // Only notify for meaningful status changes
    const notifyStatuses = ["preparing", "ready", "completed", "cancelled", "paid"];
    if (!notifyStatuses.includes(newStatus) || previousStatus === newStatus) {
      return null;
    }

    const userId = after.userId;
    if (!userId) {
      console.log(`Order ${orderId}: No userId, skipping notification`);
      return null;
    }

    // Get customer's FCM token
    const userDoc = await db.collection("users").doc(userId).get();
    const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;

    if (!fcmToken) {
      console.log(`Order ${orderId}: No FCM token for user ${userId}`);
      return null;
    }

    // Get truck name
    const truckName = await getTruckName(after.truckId);
    const restaurantName = truckName || "UniPick";

    const messageConfig = STATUS_MESSAGES[newStatus] || {
      body: `status is now ${newStatus}`,
    };

    const orderNumber = after.displayOrderNumber
      ? `#${after.displayOrderNumber}`
      : after.merchantRefNumber
        ? `#${String(after.merchantRefNumber).slice(0, 6)}`
        : "";

    const title = orderNumber
      ? `Order ${orderNumber} from ${restaurantName}`
      : `Order from ${restaurantName}`;

    const body = `Your order from ${restaurantName} ${messageConfig.body}`;

    const message = {
      token: fcmToken,
      notification: {
        title,
        body,
        sound: "default",
      },
      data: {
        orderId,
        order_id: orderId,
        status: newStatus,
        type: "order_status",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "order_updates",
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      await messaging.send(message);
      console.log(`✅ Sent order status notification to user ${userId}: ${newStatus}`);
      return null;
    } catch (error) {
      console.error(`❌ Error sending notification for order ${orderId}:`, error);
      if (error.code === "messaging/invalid-registration-token" ||
          error.code === "messaging/registration-token-not-registered") {
        // Token is invalid, remove it from Firestore
        await db.collection("users").doc(userId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
        console.log(`Removed invalid FCM token for user ${userId}`);
      }
      throw error;
    }
  });
