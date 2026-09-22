"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.linkPhoneToActor = exports.checkPhoneRegistered = void 0;
const https_1 = require("firebase-functions/v2/https");
const v2_1 = require("firebase-functions/v2");
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
const db = admin.firestore();
/**
 * Normalizes an Indian phone number to the canonical +91XXXXXXXXXX format.
 * Returns null if the input is not a valid 10-digit Indian mobile number.
 */
function normalizeIndianPhone(value) {
    const digits = value.replace(/\D/g, "");
    let local;
    if (digits.length === 12 && digits.startsWith("91")) {
        local = digits.substring(2);
    }
    else if (digits.length === 11 && digits.startsWith("0")) {
        local = digits.substring(1);
    }
    else if (digits.length === 10) {
        local = digits;
    }
    else {
        return null;
    }
    if (!/^[6-9]\d{9}$/.test(local)) {
        return null;
    }
    return `+91${local}`;
}
exports.checkPhoneRegistered = (0, https_1.onCall)({ cors: true }, async (request) => {
    var _a;
    const { phone } = (_a = request.data) !== null && _a !== void 0 ? _a : {};
    if (!phone || typeof phone !== "string") {
        throw new https_1.HttpsError("invalid-argument", "Missing or invalid 'phone' parameter.");
    }
    const normalized = normalizeIndianPhone(phone);
    if (!normalized) {
        throw new https_1.HttpsError("invalid-argument", "Invalid Indian phone number.");
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
});
exports.linkPhoneToActor = (0, https_1.onCall)({ cors: true }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "You must be logged in.");
    }
    const uid = request.auth.uid;
    const phoneFromToken = request.auth.token.phone_number;
    if (!phoneFromToken || typeof phoneFromToken !== "string") {
        throw new https_1.HttpsError("failed-precondition", "No phone number associated with this Firebase Auth account.");
    }
    const normalized = normalizeIndianPhone(phoneFromToken);
    if (!normalized) {
        throw new https_1.HttpsError("failed-precondition", "Phone number on auth account is not a valid Indian number.");
    }
    const phoneIndexRef = db.collection("phone_index").doc(normalized);
    const phoneIndexDoc = await phoneIndexRef.get();
    if (!phoneIndexDoc.exists) {
        throw new https_1.HttpsError("not-found", "No actor profile found for this phone number.");
    }
    const phoneData = phoneIndexDoc.data();
    const actorDocId = phoneData === null || phoneData === void 0 ? void 0 : phoneData.actorId;
    if (!actorDocId || typeof actorDocId !== "string") {
        throw new https_1.HttpsError("internal", "phone_index entry is missing actorId.");
    }
    const actorRef = db.collection("actors").doc(actorDocId);
    const result = await db.runTransaction(async (tx) => {
        const actorDoc = await tx.get(actorRef);
        if (!actorDoc.exists) {
            throw new https_1.HttpsError("not-found", "Actor document not found.");
        }
        const actorData = actorDoc.data();
        const existingUid = actorData === null || actorData === void 0 ? void 0 : actorData.uid;
        if (existingUid === uid) {
            return { action: "already_linked" };
        }
        if (existingUid && existingUid !== "" && existingUid !== uid) {
            v2_1.logger.warn(`linkPhoneToActor: Actor ${actorDocId} already linked to UID ${existingUid}, ` +
                `rejecting claim from UID ${uid}`);
            throw new https_1.HttpsError("already-exists", "This actor profile is already linked to another account.");
        }
        tx.update(actorRef, {
            uid: uid,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        tx.update(phoneIndexRef, {
            uid: uid,
            claimedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return { action: "linked" };
    });
    v2_1.logger.info(`linkPhoneToActor: UID ${uid} → actor ${actorDocId} (${result.action})`);
    return {
        success: true,
        action: result.action,
        actorId: actorDocId,
    };
});
// sendMaskedNotification lives in notifications.ts — deploy separately once
// Twilio secrets are configured:
//   firebase deploy --only functions:default:sendMaskedNotification
//# sourceMappingURL=index.js.map