require("dotenv").config();

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require('axios');
const { GoogleGenerativeAI } = require("@google/generative-ai");

admin.initializeApp();
const db = admin.firestore();

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
const aviationAPI = process.env.AVIATION_API_KEY;

function parseIso(date) {
  if (!date) return 0;
  const t = Date.parse(date);
  return isNaN(t) ? 0 : t;
}

function requireAuth(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }
  return context.auth.uid;
}

async function upsertWithConflict(ref, data) {
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);

    const incomingModified = parseIso(data.last_modified);
    const serverModified = snap.exists
      ? parseIso(snap.data().client_last_modified)
      : 0;

    if (serverModified > incomingModified) {
      return;
    }

    tx.set(
      ref,
      {
        ...data,
        client_last_modified: data.last_modified,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });
}

exports.parseSmsTicket = functions.https.onCall(async (data, context) => {
  const sms = data.sms;

  if (!sms) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "SMS text required"
    );
  }

  const model = genAI.getGenerativeModel({
    model: "gemini-1.5-flash",
  });

  const prompt = `
Extract travel details from this SMS ticket.

Return JSON with:
carrier
pnr
departure (ISO)
origin
destination
seat
status

SMS:
${sms}
`;

  const result = await model.generateContent(prompt);
  const text = result.response.text();

  try {
    return JSON.parse(text);
  } catch (e) {
    throw new functions.https.HttpsError(
      "internal",
      "Failed to parse AI response"
    );
  }
});

exports.syncJourney = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);

  const journeyId = data.journey_id;

  if (!journeyId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "journey_id required"
    );
  }

  const ref = db.doc(`users/${uid}/journeys/${journeyId}`);

  await upsertWithConflict(ref, data);

  return { success: true };
});

exports.syncTicket = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);

  const ticketId = data.ticket_id;
  const journeyId = data.journey_id;

  if (!ticketId || !journeyId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "ticket_id and journey_id required"
    );
  }

  const ref = db.doc(
    `users/${uid}/journeys/${journeyId}/tickets/${ticketId}`
  );

  await upsertWithConflict(ref, data);

  return { success: true };
});

exports.syncConnection = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);

  const connectionId = data.connection_id;
  const journeyId = data.journey_id;

  if (!connectionId || !journeyId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "connection_id and journey_id required"
    );
  }

  const ref = db.doc(
    `users/${uid}/journeys/${journeyId}/connections/${connectionId}`
  );

  await upsertWithConflict(ref, data);

  return { success: true };
});

exports.syncAiQueue = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);

  const queueId = data.queue_id;

  if (!queueId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "queue_id required"
    );
  }

  const ref = db.doc(
    `users/${uid}/ai_processing_queue/${queueId}`
  );

  await upsertWithConflict(ref, data);

  return { success: true };
});

exports.syncUser = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);

  const ref = db.doc(`users/${uid}`);

  await upsertWithConflict(ref, data);

  return { success: true };
});

exports.createCustomTokenForLocalUser = functions.https.onCall(
  async (data, context) => {
    const secret = data.secret;

    if (secret !== process.env.FUNCTIONS_REGISTRATION_SECRET) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Invalid registration secret"
      );
    }

    const localUserId = data.local_user_id;

    if (!localUserId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "local_user_id required"
      );
    }

    let user;

    try {
      user = await admin.auth().getUser(localUserId);
    } catch {
      user = await admin.auth().createUser({
        uid: localUserId,
      });
    }

    const token = await admin.auth().createCustomToken(user.uid);

    return {
      token: token,
      uid: user.uid,
    };
  }
);

exports.onAuthUserCreate = functions.auth.user().onCreate(async (user) => {
  const ref = db.doc(`users/${user.uid}`);

  await ref.set({
    user_id: user.uid,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
});

// Scheduled function to run every hour
exports.monitorFlightStatus = functions.pubsub.schedule('0 * * * *').onRun(async (context) => {
  const db = admin.firestore();
  const now = new Date();
  const tomorrow = new Date(now);
  tomorrow.setDate(now.getDate() + 1);

  // Fetch all flight tickets that are not yet completed and whose departure is today or tomorrow
  const ticketsSnapshot = await db.collection('tickets')
    .where('carrier', '>=', '')
    .where('departure', '>=', now.toISOString())
    .where('departure', '<=', tomorrow.toISOString())
    .get();

  const updates = [];

  for (const doc of ticketsSnapshot.docs) {
    const ticket = doc.data();
    // Extract flight number (e.g., "JM 123" -> "JM123")
    const flightNumber = ticket.pnr || `${ticket.carrier}${ticket.pnr}`; // adjust as needed

    // Query Aviationstack
    const response = await axios.get(AVIATIONSTACK_URL, {
      params: {
        access_key: AVIATIONSTACK_API_KEY,
        flight_iata: flightNumber,
        flight_date: ticket.departure.split('T')[0],
      },
    });

    const flightData = response.data.data[0];
    if (!flightData) continue;

    const newStatus = flightData.flight_status; // e.g., "scheduled", "active", "landed", "cancelled", "delayed"
    const newDelay = flightData.delay; // minutes
    const newGate = flightData.departure.gate;

    let changed = false;
    if (newStatus !== ticket.status) changed = true;
    if (newDelay !== ticket.delay) changed = true;
    if (newGate !== ticket.gate) changed = true;

    if (changed) {
      const updateData = {
        status: newStatus,
        delay: newDelay,
        gate: newGate,
        last_modified: admin.firestore.FieldValue.serverTimestamp(),
      };
      await doc.ref.update(updateData);

      // Optionally send a push notification or SMS (via Twilio) to the user
      // You'll need to know the user's phone number (from users collection) and use Twilio
      // For simplicity, we'll just log it.
      console.log(`Flight ${flightNumber} status updated to ${newStatus}`);
    }
  }

  return null;
});