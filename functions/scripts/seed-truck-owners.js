/**
 * Seed script: Creates truck owner accounts for test9@gmail.com and test10@gmail.com
 * - test9@gmail.com -> Taco Fiesta (truck2)
 * - test10@gmail.com -> Pizza Corner (truck3)
 * - test11@gmail.com -> Sushi Roll (truck4)
 *
 * Truck owner accounts bypass email verification (role check in app).
 * Run: node functions/scripts/seed-truck-owners.js
 * Or: GOOGLE_APPLICATION_CREDENTIALS=path/to/serviceAccountKey.json node functions/scripts/seed-truck-owners.js
 */

const admin = require('firebase-admin');
const path = require('path');

const DEFAULT_PASSWORD = 'UniPick123!';

const TRUCK_OWNERS = [
  {
    email: 'test9@gmail.com',
    name: 'Taco Fiesta Owner',
    ownerId: 'truck2',
    truckName: 'Taco Fiesta',
  },
  {
    email: 'test10@gmail.com',
    name: 'Pizza Corner Owner',
    ownerId: 'truck3',
    truckName: 'Pizza Corner',
  },
  {
    email: 'test11@gmail.com',
    name: 'Sushi Roll Owner',
    ownerId: 'truck4',
    truckName: 'Sushi Roll',
  },
];

async function main() {
  // Initialize Firebase Admin (use default credentials or service account)
  if (!admin.apps.length) {
    const projectId = process.env.GCLOUD_PROJECT || 'unipick-1b5ed';
    const credentialPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    if (credentialPath) {
      const serviceAccount = require(path.resolve(credentialPath));
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId,
      });
    } else {
      admin.initializeApp({ projectId });
    }
  }

  const auth = admin.auth();
  const db = admin.firestore();

  for (const owner of TRUCK_OWNERS) {
    try {
      let userRecord;
      try {
        userRecord = await auth.getUserByEmail(owner.email);
        console.log(`User ${owner.email} already exists (uid: ${userRecord.uid})`);
        // Mark email as verified and update if needed
        await auth.updateUser(userRecord.uid, { emailVerified: true });
      } catch (e) {
        if (e.code === 'auth/user-not-found') {
          userRecord = await auth.createUser({
            email: owner.email,
            password: DEFAULT_PASSWORD,
            displayName: owner.name,
            emailVerified: true, // No verification needed for truck owners
          });
          console.log(`Created Auth user: ${owner.email} (uid: ${userRecord.uid})`);
        } else {
          throw e;
        }
      }

      await db.collection('users').doc(userRecord.uid).set({
        name: owner.name,
        email: owner.email,
        role: 'truck owner',
        ownerId: owner.ownerId,
        termsAcceptance: true,
        skipEmailVerification: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      console.log(`✓ ${owner.email} -> ${owner.truckName} (${owner.ownerId})`);
    } catch (err) {
      console.error(`✗ Failed for ${owner.email}:`, err.message);
    }
  }

  console.log('\nDone. Truck owners can log in with password:', DEFAULT_PASSWORD);
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
