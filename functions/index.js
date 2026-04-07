require("dotenv").config();

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const axios = require('axios');
const { GoogleGenerativeAI } = require("@google/generative-ai");
const twilio = require('twilio');
const express = require("express");

admin.initializeApp();
const db = admin.firestore();

// ---------- Environment variables ----------
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
const aviationApiKey = process.env.AVIATION_API_KEY;
const aviationStackUrl = process.env.AVIATIONSTACK_URL || 'http://api.aviationstack.com/v1/flights';
const twilioSid = process.env.TWILIO_SID;
const twilioAuthToken = process.env.TWILIO_AUTH_TOKEN;
const twilioPhoneNumber = process.env.TWILIO_PHONE_NUMBER; //sender number

const twilioClient = twilioSid && twilioAuthToken ? twilio(twilioSid, twilioAuthToken) : null;

// ---------- Helper functions ----------
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

// Helper to send SMS using Twilio (outbound)
async function sendSms(to, body) {
  if (!twilioClient || !twilioPhoneNumber) {
    console.warn('Twilio not configured. SMS not sent.');
    return;
  }
  try {
    const message = await twilioClient.messages.create({
      body: body,
      to: to,
      from: twilioPhoneNumber,
    });
    console.log(`SMS sent to ${to}: ${message.sid}`);
  } catch (error) {
    console.error(`Failed to send SMS to ${to}:`, error);
  }
}

// Simple airline name -> IATA code mapping (add more as needed)
const airlineIataMap = {
  'jambojet': 'JM',
  'safarilink': 'F2',
  'kenya airways': 'KQ',
  'fly540': '5H',
  'uganda airlines': 'UR',
  'rwandair': 'WB',
  'air tanzania': 'TC',
};

function getFlightIata(carrier, pnr) {
  const carrierLower = (carrier || '').toLowerCase();
  const iata = airlineIataMap[carrierLower];
  if (!iata) {
    // Fallback: try to extract from carrier string (e.g., "JM 123")
    const match = (carrier + ' ' + (pnr || '')).match(/[A-Z]{2}\s?\d+/);
    if (match) return match[0].replace(/\s/g, '');
    return null;
  }
  const pnrDigits = (pnr || '').replace(/\D/g, '');
  return pnrDigits ? `${iata}${pnrDigits}` : iata;
}

// ---------- Inbound Twilio Webhook (v2 HTTP) ----------

const inboundApp = express();
inboundApp.use(express.urlencoded({ extended: false }));

function buildMediaArray(body) {
  const numMedia = Number(body.NumMedia || 0);
  const media = [];
  for (let i = 0; i < numMedia; i++) {
    const url = body[`MediaUrl${i}`];
    if (url) {
      media.push({
        url,
        contentType: body[`MediaContentType${i}`] || null,
      });
    }
  }
  return media;
}

function buildRawInboundSms(body) {
  const messageSid = body.MessageSid || body.SmsMessageSid || body.SmsSid || null;
  return {
    provider: "twilio",
    messageSid,
    accountSid: body.AccountSid || null,
    messagingServiceSid: body.MessagingServiceSid || null,
    fromNumber: body.From || null,
    toNumber: body.To || null,
    bodyText: body.Body || "",
    numMedia: Number(body.NumMedia || 0),
    media: buildMediaArray(body),
    receivedAt: admin.firestore.FieldValue.serverTimestamp(),
    parseStatus: "pending",
    rawPayload: body,
  };
}

inboundApp.post(
  "/twilio/inbound-sms",
  twilio.webhook({ validate: process.env.NODE_ENV !== "test" }),
  async (req, res) => {
    try {
      const body = req.body || {};
      const messageSid = body.MessageSid || body.SmsMessageSid || body.SmsSid;

      if (!messageSid) {
        return res.status(400).json({ error: "Missing MessageSid" });
      }

      const docRef = db.collection("raw_inbound_sms").doc(messageSid);
      const existing = await docRef.get();

      if (!existing.exists) {
        await docRef.set(buildRawInboundSms(body));
      }

      res.status(200).send("OK");
    } catch (error) {
      console.error("Twilio inbound SMS webhook failed:", error);
      res.status(500).send("Internal Server Error");
    }
  }
);

const region = 'europe-west1';

exports.twilioInboundSms = functions.region(region).https.onRequest(inboundApp);

// ---------- Existing callable functions ----------
exports.parseSmsTicket = functions.region(region).https.onCall(async (data, context) => {
  const sms = data.sms;
  if (!sms) {
    throw new functions.https.HttpsError("invalid-argument", "SMS text required");
  }

  const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

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
    throw new functions.https.HttpsError("internal", "Failed to parse AI response");
  }
});

exports.syncJourney = functions.region(region).https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const journeyId = data.journey_id;
  if (!journeyId) {
    throw new functions.https.HttpsError("invalid-argument", "journey_id required");
  }
  const ref = db.doc(`users/${uid}/journeys/${journeyId}`);
  await upsertWithConflict(ref, data);
  return { success: true };
});

exports.syncTicket = functions.region(region).https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const ticketId = data.ticket_id;
  const journeyId = data.journey_id;
  if (!ticketId || !journeyId) {
    throw new functions.https.HttpsError("invalid-argument", "ticket_id and journey_id required");
  }
  const ref = db.doc(`users/${uid}/journeys/${journeyId}/tickets/${ticketId}`);
  await upsertWithConflict(ref, data);
  return { success: true };
});

exports.syncConnection = functions.region(region).https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const connectionId = data.connection_id;
  const journeyId = data.journey_id;
  if (!connectionId || !journeyId) {
    throw new functions.https.HttpsError("invalid-argument", "connection_id and journey_id required");
  }
  const ref = db.doc(`users/${uid}/journeys/${journeyId}/connections/${connectionId}`);
  await upsertWithConflict(ref, data);
  return { success: true };
});

exports.syncAiQueue = functions.region(region).https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const queueId = data.queue_id;
  if (!queueId) {
    throw new functions.https.HttpsError("invalid-argument", "queue_id required");
  }
  const ref = db.doc(`users/${uid}/ai_processing_queue/${queueId}`);
  await upsertWithConflict(ref, data);
  return { success: true };
});

exports.syncUser = functions.region(region).https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const ref = db.doc(`users/${uid}`);
  await upsertWithConflict(ref, data);
  return { success: true };
});

exports.createCustomTokenForLocalUser = functions.region(region).https.onCall(async (data, context) => {
  const secret = data.secret;
  if (secret !== process.env.FUNCTIONS_REGISTRATION_SECRET) {
    throw new functions.https.HttpsError("permission-denied", "Invalid registration secret");
  }
  const localUserId = data.local_user_id;
  if (!localUserId) {
    throw new functions.https.HttpsError("invalid-argument", "local_user_id required");
  }

  let user;
  try {
    user = await admin.auth().getUser(localUserId);
  } catch {
    user = await admin.auth().createUser({ uid: localUserId });
  }

  const token = await admin.auth().createCustomToken(user.uid);
  return { token: token, uid: user.uid };
});

// ---------- Triggers & Scheduled Tasks ----------

exports.onAuthUserCreate = functions.region(region).auth.user().onCreate(async (user) => {
  const ref = db.doc(`users/${user.uid}`);
  await ref.set(
    {
      user_id: user.uid,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
});

// ---------- Scheduled flight monitor with SMS alerts ----------
exports.monitorFlightStatus = functions.region(region).pubsub.schedule('0 * * * *').onRun(async (context) => {
  const now = new Date();
  const tomorrow = new Date(now);
  tomorrow.setDate(now.getDate() + 1);

  const nowIso = now.toISOString();
  const tomorrowIso = tomorrow.toISOString();

  // Query all tickets (collection group) with departure in next 24h
  const ticketsSnapshot = await db.collectionGroup('tickets')
    .where('departure', '>=', nowIso)
    .where('departure', '<=', tomorrowIso)
    .get();

  for (const doc of ticketsSnapshot.docs) {
    const ticket = doc.data();
    const pathSegments = doc.ref.path.split('/');
    const userId = pathSegments[1]; // users/{userId}/...

    // Skip non-flight carriers (e.g., SGR)
    if (ticket.carrier?.toLowerCase().includes('sgr')) continue;

    const flightNumber = getFlightIata(ticket.carrier, ticket.pnr);
    if (!flightNumber) {
      console.warn(`No flight number for ${doc.id}`);
      continue;
    }

    const flightDate = ticket.departure.split('T')[0];
    try {
      const response = await axios.get(aviationStackUrl, {
        params: {
          access_key: aviationApiKey,
          flight_iata: flightNumber,
          flight_date: flightDate,
        },
      });

      const flightData = response.data.data?.[0];
      if (!flightData) continue;

      const newStatus = flightData.flight_status;
      const newDelay = flightData.delay;
      const newGate = flightData.departure?.gate;

      let changed = false;
      const updateData = {};
      if (newStatus && newStatus !== ticket.status) {
        updateData.status = newStatus;
        changed = true;
      }
      if (newDelay !== undefined && newDelay !== ticket.delay) {
        updateData.delay = newDelay;
        changed = true;
      }
      if (newGate && newGate !== ticket.gate) {
        updateData.gate = newGate;
        changed = true;
      }

      if (changed) {
        updateData.last_modified = admin.firestore.FieldValue.serverTimestamp();
        await doc.ref.update(updateData);
        console.log(`Flight ${flightNumber} changed to ${newStatus} for user ${userId}`);

        // Send SMS if user has phone number
        const userDoc = await db.doc(`users/${userId}`).get();
        const userPhone = userDoc.data()?.phoneNumber;
        if (userPhone && userPhone.match(/^\+[1-9]\d{1,14}$/)) {
          const smsBody = `✈️ Flight ${flightNumber} status changed to ${newStatus}${newDelay ? `. Delay: ${newDelay} min` : ''}. Gate: ${newGate || 'N/A'}.`;
          await sendSms(userPhone, smsBody);
        }
      }
    } catch (error) {
      console.error(`Error processing ${flightNumber}:`, error.message);
    }
  }

  return null;
});