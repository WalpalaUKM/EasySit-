const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// ============================================================================
// BACKEND TIMING CONFIGURATION (UNITS & HOW TO CHANGE SAFELY)
// ============================================================================
// [BOOKED SESSION DURATION]:
// Unit: Minutes (integer).
// Current: 120 minutes (2 hours standard study session).
// How to change safely: Update this number (e.g., 120 for 2 hours, 60 for 1 hour).
// NOTE: Always match with Flutter SeatExpiryService.bookedDurationMinutes!
const BOOKED_DURATION_MINUTES = 120;

// [PENDING RESERVATION GRACE PERIOD]:
// Unit: Minutes (integer).
// Current: 20 minutes.
// How to change safely: Update this number (e.g., 20 for 20 minutes).
// NOTE: Always match with Flutter SeatExpiryService.pendingDurationMinutes!
const PENDING_DURATION_MINUTES = 20;

/**
 * Core helper to check and release all expired seats in Firestore.
 * Performs atomic Firestore batch operations to ensure consistency.
 */
async function processExpiredSeats() {
  const now = Date.now();
  const seatsRef = db.collection("seats");

  // Query booked and pending seats
  const [bookedSnapshot, pendingSnapshot] = await Promise.all([
    seatsRef.where("status", "==", "booked").get(),
    seatsRef.where("status", "==", "pending").get(),
  ]);

  const batch = db.batch();
  let releaseCount = 0;

  // 1. Process Booked Seats
  for (const doc of bookedSnapshot.docs) {
    const data = doc.data();
    const bookedAt = data.bookedAt ? data.bookedAt.toDate().getTime() : null;
    if (!bookedAt) continue;

    const expiresAt = bookedAt + BOOKED_DURATION_MINUTES * 60 * 1000;
    if (now >= expiresAt) {
      const seatId = doc.id;
      const userId = data.bookedBy;

      // Update seat to available
      batch.update(doc.ref, {
        status: "available",
        bookedBy: admin.firestore.FieldValue.delete(),
        bookedAt: admin.firestore.FieldValue.delete(),
        pendingBy: admin.firestore.FieldValue.delete(),
        pendingAt: admin.firestore.FieldValue.delete(),
      });

      // Record completed session stats for the student
      if (userId) {
        const userRef = db.collection("users").doc(userId);
        const sessionKey = `${seatId}_${bookedAt}`;
        batch.set(
          userRef,
          {
            sessionsCompleted: admin.firestore.FieldValue.increment(1),
            totalMinutesStudied: admin.firestore.FieldValue.increment(BOOKED_DURATION_MINUTES),
            completedSessionKeys: admin.firestore.FieldValue.arrayUnion(sessionKey),
          },
          { merge: true }
        );
      }

      releaseCount++;
    }
  }

  // 2. Process Pending Seats
  for (const doc of pendingSnapshot.docs) {
    const data = doc.data();
    const pendingAt = data.pendingAt ? data.pendingAt.toDate().getTime() : null;
    if (!pendingAt) continue;

    const expiresAt = pendingAt + PENDING_DURATION_MINUTES * 60 * 1000;
    if (now >= expiresAt) {
      batch.update(doc.ref, {
        status: "available",
        pendingBy: admin.firestore.FieldValue.delete(),
        pendingAt: admin.firestore.FieldValue.delete(),
      });
      releaseCount++;
    }
  }

  if (releaseCount > 0) {
    await batch.commit();
    console.log(`[Auto-Release] Successfully released ${releaseCount} expired seats.`);
  }

  return releaseCount;
}

// ============================================================================
// [BACKGROUND CLOUD SCHEDULER / CRON JOB]
// ============================================================================
/**
 * Scheduled Cloud Function running every 1 minute.
 * Unit: Minutes (Runs every 1 minute: "every 1 minutes").
 * Purpose: Ensures expired seats are freed even if students close their apps,
 * go offline, or lose internet connectivity.
 * How to change safely: Modify "every 1 minutes" (e.g. "every 5 minutes").
 */
exports.releaseExpiredSeatsCron = onSchedule("every 1 minutes", async (event) => {
  try {
    const released = await processExpiredSeats();
    console.log(`Cron execution completed. Released: ${released}`);
  } catch (error) {
    console.error("Error running releaseExpiredSeatsCron:", error);
  }
});

/**
 * HTTPS endpoint to trigger seat release on demand or for testing.
 */
exports.releaseExpiredSeatsHttp = onRequest(async (req, res) => {
  try {
    const released = await processExpiredSeats();
    res.json({ success: true, releasedSeats: released, timestamp: new Date().toISOString() });
  } catch (error) {
    console.error("Error in releaseExpiredSeatsHttp:", error);
    res.status(500).json({ success: false, error: error.message });
  }
});
