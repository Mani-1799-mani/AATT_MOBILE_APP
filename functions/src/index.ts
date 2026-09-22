import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

/**
 * Normalizes an Indian phone number to the canonical +91XXXXXXXXXX format.
 * Returns null if the input is not a valid 10-digit Indian mobile number.
 */
function normalizeIndianPhone(value: string): string | null {
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

  if (!/^[6-9]\d{9}$/.test(local)) {
    return null;
  }

  return `+91${local}`;
}

export const checkPhoneRegistered = onCall(
  { cors: true },
  async (request) => {
    const { phone } = request.data ?? {};
    if (!phone || typeof phone !== "string") {
      throw new HttpsError("invalid-argument", "Missing or invalid 'phone' parameter.");
    }

    const normalized = normalizeIndianPhone(phone);
    if (!normalized) {
      throw new HttpsError("invalid-argument", "Invalid Indian phone number.");
    }

    const phoneIndexDoc = await db.collection("phone_index").doc(normalized).get();
    if (phoneIndexDoc.exists) {
      return { registered: true, collection: "actors" };
    }

    const directorQuery = await db
      .collection("directors")
      .where("phoneNumber", "==", normalized)
      .limit(1)
      .get();

    if (!directorQuery.empty) {
      return { registered: true, collection: "directors" };
    }

    return { registered: false };
  }
);

export const linkPhoneToActor = onCall(
  { cors: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be logged in.");
    }

    const uid = request.auth.uid;
    const phoneFromToken = request.auth.token.phone_number;

    if (!phoneFromToken || typeof phoneFromToken !== "string") {
      throw new HttpsError(
        "failed-precondition",
        "No phone number associated with this Firebase Auth account."
      );
    }

    const normalized = normalizeIndianPhone(phoneFromToken);
    if (!normalized) {
      throw new HttpsError(
        "failed-precondition",
        "Phone number on auth account is not a valid Indian number."
      );
    }

    const phoneIndexRef = db.collection("phone_index").doc(normalized);
    const phoneIndexDoc = await phoneIndexRef.get();

    if (!phoneIndexDoc.exists) {
      throw new HttpsError("not-found", "No actor profile found for this phone number.");
    }

    const phoneData = phoneIndexDoc.data();
    const actorDocId = phoneData?.actorId;

    if (!actorDocId || typeof actorDocId !== "string") {
      throw new HttpsError(
        "internal",
        "phone_index entry is missing actorId."
      );
    }

    const actorRef = db.collection("actors").doc(actorDocId);

    const result = await db.runTransaction(async (tx) => {
      const actorDoc = await tx.get(actorRef);
      if (!actorDoc.exists) {
        throw new HttpsError("not-found", "Actor document not found.");
      }

      const actorData = actorDoc.data();
      const existingUid = actorData?.uid;

      if (existingUid === uid) {
        return { action: "already_linked" as const };
      }

      if (existingUid && existingUid !== "" && existingUid !== uid) {
        logger.warn(
          `linkPhoneToActor: Actor ${actorDocId} already linked to UID ${existingUid}, ` +
          `rejecting claim from UID ${uid}`
        );
        throw new HttpsError(
          "already-exists",
          "This actor profile is already linked to another account."
        );
      }

      tx.update(actorRef, {
        uid: uid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.update(phoneIndexRef, {
        uid: uid,
        claimedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { action: "linked" as const };
    });

    logger.info(
      `linkPhoneToActor: UID ${uid} → actor ${actorDocId} (${result.action})`
    );

    return {
      success: true,
      action: result.action,
      actorId: actorDocId,
    };
  }
);

// sendMaskedNotification lives in notifications.ts — deploy separately once
// Twilio secrets are configured:
//   firebase deploy --only functions:default:sendMaskedNotification
