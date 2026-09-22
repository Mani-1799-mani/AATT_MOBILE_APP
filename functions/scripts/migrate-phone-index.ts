/**
 * Migration script to populate the phone_index collection from existing actors.
 *
 * Run with: npx ts-node scripts/migrate-phone-index.ts
 * (from the functions directory)
 */

import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK with explicit project ID
admin.initializeApp({
  projectId: "aatt-85282",
});
const db = admin.firestore();

/**
 * Normalizes an Indian phone number to the canonical +91XXXXXXXXXX format.
 * Returns null if the input is not a valid 10-digit Indian mobile number.
 */
function normalizeIndianPhone(value: string): string | null {
  if (!value) return null;

  const digits = value.replace(/\D/g, "");

  let local: string;
  if (digits.length === 12 && digits.startsWith("91")) {
    local = digits.substring(2);
  } else if (digits.length === 11 && digits.startsWith("0")) {
    local = digits.substring(1);
  } else if (digits.length === 10) {
    local = digits;
  } else {
    return null;
  }

  // Indian mobile numbers start with 6-9
  if (!/^[6-9]\d{9}$/.test(local)) {
    return null;
  }

  return `+91${local}`;
}

async function migratePhoneIndex(): Promise<void> {
  console.log("Starting phone_index migration...\n");

  const actorsSnapshot = await db.collection("actors").get();
  console.log(`Found ${actorsSnapshot.size} actor documents.\n`);

  let created = 0;
  let skipped = 0;
  let invalid = 0;
  let alreadyExists = 0;

  for (const actorDoc of actorsSnapshot.docs) {
    const data = actorDoc.data();
    const actorId = actorDoc.id;

    // Check both possible phone field names
    const rawPhone = data.phone || data.phoneNumber;

    if (!rawPhone) {
      console.log(`  [SKIP] ${actorId}: No phone number`);
      skipped++;
      continue;
    }

    const normalizedPhone = normalizeIndianPhone(rawPhone);

    if (!normalizedPhone) {
      console.log(`  [INVALID] ${actorId}: Invalid phone "${rawPhone}"`);
      invalid++;
      continue;
    }

    // Check if phone_index entry already exists
    const existingDoc = await db.collection("phone_index").doc(normalizedPhone).get();

    if (existingDoc.exists) {
      const existingData = existingDoc.data();
      if (existingData?.actorId === actorId) {
        console.log(`  [EXISTS] ${actorId}: ${normalizedPhone} already indexed`);
        alreadyExists++;
      } else {
        console.log(`  [CONFLICT] ${actorId}: ${normalizedPhone} already linked to ${existingData?.actorId}`);
        skipped++;
      }
      continue;
    }

    // Create phone_index entry
    await db.collection("phone_index").doc(normalizedPhone).set({
      actorId: actorId,
      phone: normalizedPhone,
      uid: data.uid || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      migratedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`  [CREATED] ${actorId}: ${normalizedPhone}`);
    created++;
  }

  console.log("\n=== Migration Complete ===");
  console.log(`  Created: ${created}`);
  console.log(`  Already exists: ${alreadyExists}`);
  console.log(`  Skipped (no phone/conflict): ${skipped}`);
  console.log(`  Invalid phone format: ${invalid}`);
  console.log(`  Total processed: ${actorsSnapshot.size}`);
}

// Run the migration
migratePhoneIndex()
  .then(() => {
    console.log("\nMigration finished successfully.");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\nMigration failed:", error);
    process.exit(1);
  });
