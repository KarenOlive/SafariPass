require("dotenv").config();

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const axios = require('axios');
const crypto = require('crypto');
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

function hashPhoneNumber(phoneNumber) {
  if (!phoneNumber) return null;
  return crypto.createHash('sha256').update(phoneNumber.trim()).digest('hex');
}

function requireAuth(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }
  console.log("Auth context:", context.auth);
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

      const rawSmsDoc = buildRawInboundSms(body);
      const docRef = db.collection("raw_inbound_sms").doc(messageSid);
      const existing = await docRef.get();

      if (!existing.exists) {
        // Try to find user by phone number (hashed)
        const fromNumber = body.From;
        let userId = null;

        if (fromNumber) {
          const phoneHash = hashPhoneNumber(fromNumber);
          const phoneQuery = await db.collection('users')
            .where('phone_hash', '==', phoneHash)
            .limit(1)
            .get();

          if (!phoneQuery.empty) {
            userId = phoneQuery.docs[0].id;
          }
        }

        await docRef.set({
          ...rawSmsDoc,
          associated_user_id: userId || null, // Will be null if phone not found
        });
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

// ---------- SMS Ticket Parsing & Storage ----------

/**
 * Local parser for common East African ticket formats
 * Returns null if pattern doesn't match (fallback to Groq)
 */
function tryLocalParse(smsText) {
  if (!smsText) return null;

  const text = smsText.trim();
  const tickets = [];

  // Pattern 1: "Carrier: Origin → Destination, Date Time, Seat"
  // e.g., "EasyCoach: Nairobi → Kisumu, 2 Apr 10:00AM, Seat B4"
  const pattern1 = /^([^:]+):\s*([^→]+?)\s*→\s*([^,]+),\s*([^,]+),\s*(?:Seat\s*)?([A-Z0-9]+)$/i;
  const match1 = text.match(pattern1);
  if (match1) {
    const [, carrier, origin, destination, dateTime, seat] = match1;
    const departure = parseDateTime(dateTime);
    if (departure) {
      tickets.push({
        carrier: carrier.trim(),
        pnr: null,
        departure,
        arrival: null,
        origin: origin.trim(),
        destination: destination.trim(),
        seat: seat.trim(),
        status: 'confirmed',
        confidence_score: 0.9,
      });
      return tickets;
    }
  }

  // Pattern 2: "Airline PNR: NBO → MBA, Date Time, Seat"
  // e.g., "JK 101: NBO → MBA, 2 Apr 10:00AM, Seat 12A"
  const pattern2 = /^([A-Z0-9]+\s[A-Z0-9]+):\s*([A-Z]+)\s*→\s*([A-Z]+),\s*([^,]+),\s*(?:Seat\s*)?([A-Z0-9]+)$/i;
  const match2 = text.match(pattern2);
  if (match2) {
    const [, pnr, origin, destination, dateTime, seat] = match2;
    const departure = parseDateTime(dateTime);
    if (departure) {
      tickets.push({
        carrier: extractCarrier(pnr),
        pnr: pnr.trim(),
        departure,
        arrival: null,
        origin: origin.toUpperCase(),
        destination: destination.toUpperCase(),
        seat: seat.trim(),
        status: 'confirmed',
        confidence_score: 0.85,
      });
      return tickets;
    }
  }

  // Pattern 3: Multi-line round trip or multi-leg
  // e.g., "Outbound: NBO → MBA, 2 Apr 10:00\nReturn: MBA → NBO, 5 Apr 18:00"
  const lines = text.split(/\n|return/i);
  if (lines.length > 1) {
    for (const line of lines) {
      const match = line.match(/([A-Z]+)\s*→\s*([A-Z]+),?\s*([^,]+)\s*(?:Seat\s*)?([A-Z0-9]*)/i);
      if (match) {
        const [, origin, destination, dateTime, seat] = match;
        const departure = parseDateTime(dateTime);
        if (departure) {
          tickets.push({
            carrier: null,
            pnr: null,
            departure,
            arrival: null,
            origin: origin.toUpperCase(),
            destination: destination.toUpperCase(),
            seat: seat || null,
            status: 'confirmed',
            confidence_score: 0.7,
          });
        }
      }
    }
    if (tickets.length > 0) return tickets;
  }

  return null; // No pattern matched, fallback to Groq
}

function extractCarrier(pnr) {
  return (pnr || '').split(/\s+/)[0] || null;
}

function parseDateTime(dateTimeStr) {
  try {
    // Handle formats like "2 Apr 10:00AM", "2-Apr-2026 10:00", "April 2, 2026 10:00"
    const normalized = dateTimeStr
      .replace(/(\d+)\s*(AM|PM)/i, '$1$2')
      .replace(/Apr/i, 'Apr')
      .replace(/April/i, 'Apr');

    const parsed = new Date(normalized);
    if (isNaN(parsed.getTime())) return null;

    // If year not provided, assume current or next year
    if (!dateTimeStr.includes('202') && !dateTimeStr.includes('202')) {
      const currentYear = new Date().getFullYear();
      const parsed2 = new Date(`${normalized} ${currentYear}`);
      if (!isNaN(parsed2.getTime())) {
        return parsed2.toISOString();
      }
    }

    return parsed.toISOString();
  } catch {
    return null;
  }
}

async function parseTicketFromSmsText(smsText) {
  // Try local parser first (fast, no API cost)
  const localResult = tryLocalParse(smsText);
  if (localResult && localResult.length > 0) {
    console.log(`✓ Local parser succeeded for: ${smsText.substring(0, 50)}`);
    return localResult;
  }

  // Fallback to Groq for complex formats
  console.log(`ℹ Local parser failed, using Groq API for: ${smsText.substring(0, 50)}`);
  const groqApiKey = process.env.GROQ_API_KEY;
  if (!groqApiKey) {
    throw new Error('GROQ_API_KEY not configured');
  }

  const promptText = `
Extract travel details from this SMS ticket.
IMPORTANT: If the SMS describes multiple segments or a round trip, return a SEPARATE object for EACH segment in the "tickets" array.

Return ONLY a JSON object containing an array called "tickets".
Each object should include: carrier, pnr, departure (ISO 8601), arrival (ISO 8601), origin, destination, seat, status, confidence.
Use null for missing fields.

SMS: ${smsText}
`;

  try {
    const response = await axios.post(
      'https://api.groq.com/openai/v1/chat/completions',
      {
        model: "llama-3.3-70b-versatile",
        messages: [
          {
            role: "user",
            content: promptText
          }
        ],
        response_format: { type: "json_object" },
        temperature: 0.0
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${groqApiKey}`
        }
      }
    );

    const textResponse = response.data.choices[0].message.content;
    const parsed = JSON.parse(textResponse);

    // Extract tickets array
    const ticketsArray = parsed.tickets || [];
    return ticketsArray.map(ticket => ({
      carrier: ticket.carrier || null,
      pnr: ticket.pnr || null,
      departure: ticket.departure || null,
      arrival: ticket.arrival || null,
      origin: ticket.origin || null,
      destination: ticket.destination || null,
      seat: ticket.seat || null,
      status: ticket.status || 'confirmed',
      confidence_score: ticket.confidence || 0.7,
    }));
  } catch (error) {
    console.error('Groq parsing error:', error);
    throw error;
  }
}

function generateId() {
  return (Math.random() * 100000000000000000).toString(36).substring(0, 16);
}

/**
 * Parse raw SMS and create tickets in Firestore
 * @param {string} userId - User ID to associate tickets with
 * @param {string} smsText - SMS content to parse
 * @param {string} journeyId - Journey ID (or auto-create if not provided)
 * @returns {Object} Result with tickets created
 */
async function storeSmsTicketsToFirestore(userId, smsText, journeyId = null) {
  // Parse tickets from SMS using Groq
  const parsedTickets = await parseTicketFromSmsText(smsText);

  if (!parsedTickets || parsedTickets.length === 0) {
    throw new Error('Could not extract ticket data from SMS');
  }

  // Determine or create journey
  let targetJourneyId = journeyId;
  if (!targetJourneyId) {
    // Create a default journey from first ticket's departure date
    const firstTicket = parsedTickets[0];
    const departureDate = firstTicket.departure ? new Date(firstTicket.departure).toISOString().split('T')[0] : new Date().toISOString().split('T')[0];

    targetJourneyId = `journey_${generateId()}`;
    const journeyData = {
      journey_id: targetJourneyId,
      user_id: userId,
      title: `Journey - ${departureDate}`,
      start_date: firstTicket.departure || new Date().toISOString(),
      end_date: firstTicket.arrival || new Date().toISOString(),
      status: 'active',
      last_modified: new Date().toISOString(),
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    await db.collection('users').doc(userId)
      .collection('journeys').doc(targetJourneyId).set(journeyData);

    console.log(`Created journey ${targetJourneyId} for user ${userId}`);
  }

  // Create ticket documents
  const createdTicketIds = [];
  for (const ticket of parsedTickets) {
    const ticketId = `ticket_${generateId()}`;
    const ticketData = {
      ticket_id: ticketId,
      journey_id: targetJourneyId,
      carrier: ticket.carrier,
      pnr: ticket.pnr,
      departure: ticket.departure,
      arrival: ticket.arrival,
      origin: ticket.origin,
      destination: ticket.destination,
      seat: ticket.seat,
      status: ticket.status,
      source_type: 'sms',
      confidence_score: ticket.confidence_score,
      last_modified: new Date().toISOString(),
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    await db.collection('users').doc(userId)
      .collection('journeys').doc(targetJourneyId)
      .collection('tickets').doc(ticketId).set(ticketData);

    createdTicketIds.push(ticketId);
    console.log(`Created ticket ${ticketId} for journey ${targetJourneyId}`);
  }

  // Detect and create connections between tickets in the same journey
  if (createdTicketIds.length > 1) {
    await createConnectionsForJourney(userId, targetJourneyId, createdTicketIds, parsedTickets);
  }

  return {
    success: true,
    journeyId: targetJourneyId,
    ticketIds: createdTicketIds,
    ticketCount: createdTicketIds.length
  };
}

/**
 * Create connections between tickets based on arrival/departure times
 */
async function createConnectionsForJourney(userId, journeyId, ticketIds, ticketData) {
  try {
    // Sort tickets by departure time
    const ticketsWithIds = ticketIds.map((id, idx) => ({
      id,
      ...ticketData[idx]
    })).sort((a, b) => {
      const dateA = new Date(a.departure || 0);
      const dateB = new Date(b.departure || 0);
      return dateA - dateB;
    });

    // Create connections between consecutive tickets
    for (let i = 0; i < ticketsWithIds.length - 1; i++) {
      const fromTicket = ticketsWithIds[i];
      const toTicket = ticketsWithIds[i + 1];

      // Check if arrival of one ticket matches origin of next (or is close in time)
      const arrivalTime = new Date(fromTicket.arrival || fromTicket.departure);
      const departureTime = new Date(toTicket.departure);
      const timeDiffMinutes = (departureTime - arrivalTime) / (1000 * 60);

      // Connection is valid if departure is within 24 hours of previous arrival
      if (timeDiffMinutes >= 0 && timeDiffMinutes <= 1440) {
        const connectionId = `conn_${generateId()}`;
        const connectionData = {
          connection_id: connectionId,
          journey_id: journeyId,
          from_ticket_id: fromTicket.id,
          to_ticket_id: toTicket.id,
          transport_type: 'ground', // Could be 'air', 'rail', 'bus', 'ground', etc.
          estimated_duration: `${Math.round(timeDiffMinutes)} minutes`,
          status: 'active',
          last_modified: new Date().toISOString(),
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        };

        await db.collection('users').doc(userId)
          .collection('journeys').doc(journeyId)
          .collection('connections').doc(connectionId).set(connectionData);

        console.log(`Created connection ${connectionId} between tickets ${fromTicket.id} and ${toTicket.id}`);
      }
    }
  } catch (error) {
    console.error('Error creating connections:', error);
    // Non-fatal error, don't throw
  }
}

// Callable function to manually parse and store SMS tickets
exports.parseSmsAndCreateTickets = functions.region(region).https.onCall(async (data, context) => {
  // Allow unauthenticated calls in emulator for testing
  const isEmulator = process.env.FUNCTIONS_EMULATOR === 'true';
  const uid = isEmulator ? (data.userId || 'test-user-emulator') : requireAuth(context);

  const { smsText, journeyId } = data;

  if (!smsText) {
    throw new functions.https.HttpsError('invalid-argument', 'smsText required');
  }

  try {
    const result = await storeSmsTicketsToFirestore(uid, smsText, journeyId || null);
    return result;
  } catch (error) {
    console.error('parseSmsAndCreateTickets error:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Callable function to process a raw SMS from Twilio and create tickets
exports.processRawSms = functions.region(region).https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const { messageSid, journeyId } = data;

  if (!messageSid) {
    throw new functions.https.HttpsError('invalid-argument', 'messageSid required');
  }

  try {
    // Get the raw SMS document
    const rawSmsSnap = await db.collection('raw_inbound_sms').doc(messageSid).get();
    if (!rawSmsSnap.exists) {
      throw new Error('Raw SMS not found');
    }

    const rawSms = rawSmsSnap.data();
    const smsText = rawSms.bodyText || '';

    if (!smsText.trim()) {
      throw new Error('SMS text is empty');
    }

    // Parse and store
    const result = await storeSmsTicketsToFirestore(uid, smsText, journeyId || null);

    // Update raw_inbound_sms status
    await db.collection('raw_inbound_sms').doc(messageSid).update({
      parseStatus: 'completed',
      parsed_at: new Date().toISOString(),
      parsed_journey_id: result.journeyId,
      parsed_ticket_ids: result.ticketIds,
    });

    return result;
  } catch (error) {
    console.error('processRawSms error:', error);

    // Mark as failed
    await db.collection('raw_inbound_sms').doc(messageSid).update({
      parseStatus: 'failed',
      error: error.message,
      failed_at: new Date().toISOString(),
    });

    throw new functions.https.HttpsError('internal', error.message);
  }
});

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
  const ref = db.collection('journeys').doc(journeyId);
  await upsertWithConflict(ref, { ...data, user_id: uid });
  return { success: true };
});

exports.syncTicket = functions.region(region).https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const ticketId = data.ticket_id;
  if (!ticketId) {
    throw new functions.https.HttpsError("invalid-argument", "ticket_id required");
  }
  const ref = db.collection('tickets').doc(ticketId);
  await upsertWithConflict(ref, { ...data, user_id: uid });
  return { success: true };
});

exports.syncConnection = functions.region(region).https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const connectionId = data.connection_id;
  if (!connectionId) {
    throw new functions.https.HttpsError("invalid-argument", "connection_id required");
  }
  const ref = db.collection('connections').doc(connectionId);
  await upsertWithConflict(ref, { ...data, user_id: uid });
  return { success: true };
});

exports.syncAiQueue = functions.region(region).https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const queueId = data.queue_id;
  if (!queueId) {
    throw new functions.https.HttpsError("invalid-argument", "queue_id required");
  }
  const ref = db.collection('ai_processing_queue').doc(queueId);
  await upsertWithConflict(ref, { ...data, user_id: uid });
  return { success: true };
});

exports.syncUser = functions.region(region).https.onCall(async (data, context) => {
 // 🔐 Check authentication
  if (!context.auth) {
    console.log("❌ No auth context:", context);
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be logged in"
    );
  }

  const userId = context.auth.uid;

  const { last_modified, name, phone_hash } = data;

  console.log("✅ syncUser called by:", userId);
  console.log("📦 Incoming data:", data);

  console.log("Auth:", context.auth);
  console.log("Headers:", context.rawRequest?.headers);

  // Hash phone number if provided (phone_hash parameter contains raw phone number)
  const hashedPhone = phone_hash ? hashPhoneNumber(phone_hash) : null;

  // Save user data to Firestore
  await admin.firestore().collection("users").doc(userId).set(
    {
      user_id: userId,
      name: name || "",
      phone_hash: hashedPhone,
      last_modified: last_modified || new Date().toISOString(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

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

exports.processAiQueueItem = functions.region(region).https.onCall(async (data, context) => {
  const uid = requireAuth(context);

  const queueId = data.queue_id;
  if (!queueId) {
    throw new functions.https.HttpsError("invalid-argument", "queue_id required");
  }

  const queueRef = db.collection('ai_processing_queue').doc(queueId);
  const queueSnap = await queueRef.get();

  if (!queueSnap.exists) {
    throw new functions.https.HttpsError("not-found", "Queue item not found");
  }

  const queueData = queueSnap.data();

  try {
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

    const prompt = `
Extract travel ticket details from this image or document.

Return JSON:
carrier, pnr, departure, origin, destination, seat, status
`;

    const result = await model.generateContent([
      prompt,
      {
        inlineData: {
          data: queueData.image_data,
          mimeType: "image/jpeg", // adjust if needed
        },
      },
    ]);

    const text = result.response.text();

    let parsed;
    try {
      parsed = JSON.parse(text);
    } catch (e) {
      throw new Error("Failed to parse Gemini response");
    }

    await queueRef.update({
      status: "completed",
      result_json: parsed,
      processed_at: admin.firestore.FieldValue.serverTimestamp(),
      last_modified: new Date().toISOString(),
    });

    return {
      success: true,
      result: parsed,
    };
  } catch (error) {
    await queueRef.update({
      status: "failed",
      processed_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    throw new functions.https.HttpsError("internal", error.message);
  }
});


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
    const userId = ticket.user_id; // Read from doc instead of path

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
        const userPhone = userDoc.data()?.phone_hash;
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