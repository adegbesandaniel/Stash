/**
 * STASH — Paystack wallet funding (secure backend).
 *
 * Flow:
 *  1) App calls initializePaystack({ amount }) -> we call Paystack with the
 *     SECRET key and return an authorization_url + reference.
 *  2) App opens the authorization_url in a WebView. User pays.
 *  3) App calls verifyPaystack({ reference }) -> we verify with Paystack and,
 *     if successful, credit the wallet by writing an `income` / "Funding"
 *     transaction (idempotent).
 *  4) paystackWebhook is a server-to-server backup that credits even if the
 *     app is closed before step 3.
 *
 * The secret key never touches the phone.
 */
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const https = require("https");
const crypto = require("crypto");

admin.initializeApp();
const db = admin.firestore();

// Set with:  firebase functions:secrets:set PAYSTACK_SECRET_KEY
const PAYSTACK_SECRET_KEY = defineSecret("PAYSTACK_SECRET_KEY");

const MIN_AMOUNT = 100; // ₦100
const MAX_AMOUNT = 1000000; // ₦1,000,000 per top-up

// Minimal HTTPS helper for the Paystack REST API.
function paystackRequest(method, path, secret, body) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const options = {
      hostname: "api.paystack.co",
      port: 443,
      path,
      method,
      headers: {
        Authorization: `Bearer ${secret}`,
        "Content-Type": "application/json",
      },
    };
    const req = https.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error("Invalid response from Paystack"));
        }
      });
    });
    req.on("error", reject);
    if (payload) req.write(payload);
    req.end();
  });
}

// Credit the wallet exactly once by writing an income transaction.
async function creditWallet(uid, reference, amountNaira, channel) {
  const paymentRef = db
    .collection("users").doc(uid)
    .collection("payments").doc(reference);
  const txRef = db
    .collection("users").doc(uid)
    .collection("transactions").doc();

  await db.runTransaction(async (t) => {
    const existing = await t.get(paymentRef);
    if (existing.exists && existing.data().status === "success") {
      return; // already credited — do nothing
    }
    t.set(paymentRef, {
      reference,
      amount: amountNaira,
      channel: channel || "paystack",
      status: "success",
      creditedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    // Matches TransactionModel.toMap() so it shows up everywhere in the app.
    t.set(txRef, {
      type: "income",
      category: "Funding",
      amount: amountNaira,
      note: "Wallet funding via Paystack",
      date: new Date().toISOString(),
      reference,
    });
  });
}

exports.initializePaystack = onCall(
  { secrets: [PAYSTACK_SECRET_KEY] },
  async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) throw new HttpsError("unauthenticated", "You must be signed in.");

    const email =
      (request.auth.token && request.auth.token.email) || request.data.email;
    const amount = Number(request.data.amount);

    if (!email) throw new HttpsError("invalid-argument", "Email is required.");
    if (!Number.isFinite(amount) || amount < MIN_AMOUNT || amount > MAX_AMOUNT) {
      throw new HttpsError(
        "invalid-argument",
        `Enter an amount between ₦${MIN_AMOUNT} and ₦${MAX_AMOUNT}.`
      );
    }

    const res = await paystackRequest(
      "POST",
      "/transaction/initialize",
      PAYSTACK_SECRET_KEY.value(),
      {
        email,
        amount: Math.round(amount * 100), // Paystack expects kobo
        currency: "NGN",
        callback_url: "https://stash-payment.web.app/paystack/callback",
        metadata: { uid, purpose: "wallet_funding" },
      }
    );

    if (!res.status) {
      throw new HttpsError("internal", res.message || "Could not start payment.");
    }
    return {
      authorizationUrl: res.data.authorization_url,
      accessCode: res.data.access_code,
      reference: res.data.reference,
    };
  }
);

exports.verifyPaystack = onCall(
  { secrets: [PAYSTACK_SECRET_KEY] },
  async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) throw new HttpsError("unauthenticated", "You must be signed in.");

    const reference = request.data.reference;
    if (!reference) throw new HttpsError("invalid-argument", "Missing reference.");

    const res = await paystackRequest(
      "GET",
      `/transaction/verify/${encodeURIComponent(reference)}`,
      PAYSTACK_SECRET_KEY.value()
    );

    if (!res.status) {
      throw new HttpsError("internal", res.message || "Verification failed.");
    }

    const data = res.data;
    if (data.status !== "success") {
      return { success: false, status: data.status };
    }

    const metaUid = data.metadata && data.metadata.uid;
    if (metaUid && metaUid !== uid) {
      throw new HttpsError("permission-denied", "This payment is not yours.");
    }

    const amountNaira = data.amount / 100;
    await creditWallet(uid, reference, amountNaira, data.channel);
    return { success: true, amount: amountNaira };
  }
);

// Reliability backup: Paystack calls this server-to-server.
// Configure the URL in Paystack Dashboard -> Settings -> API Keys & Webhooks.
exports.paystackWebhook = onRequest(
  { secrets: [PAYSTACK_SECRET_KEY] },
  async (req, res) => {
    try {
      const signature = req.headers["x-paystack-signature"];
      const hash = crypto
        .createHmac("sha512", PAYSTACK_SECRET_KEY.value())
        .update(req.rawBody) // use the raw body for a correct signature
        .digest("hex");
      if (hash !== signature) {
        return res.status(401).send("Invalid signature");
      }

      const event = req.body;
      if (event && event.event === "charge.success") {
        const data = event.data;
        const uid = data.metadata && data.metadata.uid;
        const reference = data.reference;
        if (uid && reference) {
          await creditWallet(uid, reference, data.amount / 100, data.channel);
        }
      }
      return res.status(200).send("ok");
    } catch (e) {
      logger.error("Webhook error", e);
      return res.status(500).send("error");
    }
  }
);

// ---------------------------------------------------------------------------
// 🔔 Push notifications (Firebase Cloud Messaging)
// ---------------------------------------------------------------------------

// Format a number as Naira, e.g. 125600 -> "₦125,600".
function naira(n) {
  return "₦" + Number(n || 0).toLocaleString("en-NG");
}

// Categories that are savings (money set aside), not daily spending. Kept in
// sync with BalanceService.savingsCategories in the app.
const SAVINGS_CATEGORIES = ["Locked Money", "Savings Goal"];

// Send a push to every device registered on a user document, then prune any
// tokens Firebase reports as dead so we don't keep retrying them.
async function sendToUser(uid, title, body, data) {
  const userSnap = await db.collection("users").doc(uid).get();
  const user = userSnap.data() || {};
  // Respect the user's notification preference (defaults to on).
  if (user.notificationsEnabled === false) return;
  const tokens = Array.isArray(user.fcmTokens)
    ? user.fcmTokens.filter(Boolean)
    : [];
  if (tokens.length === 0) return;

  const res = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: Object.assign(
      { click_action: "FLUTTER_NOTIFICATION_CLICK" },
      data || {}
    ),
    android: {
      priority: "high",
      notification: { defaultSound: true },
    },
  });

  const stale = [];
  res.responses.forEach((r, i) => {
    if (!r.success) {
      const code = r.error && r.error.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        stale.push(tokens[i]);
      }
    }
  });
  if (stale.length) {
    await db
      .collection("users").doc(uid)
      .update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(...stale) });
  }
}

// Fires on every new transaction: sends a confirmation and — for real spending
// — a budget alert once the daily limit is reached.
exports.onNewTransaction = onDocumentCreated(
  "users/{uid}/transactions/{txId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const tx = snap.data() || {};
    const uid = event.params.uid;

    const type = tx.type;
    const amount = Number(tx.amount || 0);
    const category = tx.category || "";

    try {
      // 1) Transaction confirmation
      if (type === "income") {
        await sendToUser(
          uid,
          "Money received 💰",
          `${naira(amount)} was added to your Stash wallet (${category || "Funding"}).`,
          { type: "transaction", txType: "income" }
        );
      } else if (type === "expense") {
        const label = SAVINGS_CATEGORIES.includes(category)
          ? `${naira(amount)} moved to ${category}.`
          : `${naira(amount)} spent on ${category || "an expense"}.`;
        await sendToUser(
          uid,
          "Payment successful ✅",
          label,
          { type: "transaction", txType: "expense" }
        );
      }

      // 2) Daily-budget alert (only for real spending, not savings / locks)
      if (type === "expense" && !SAVINGS_CATEGORIES.includes(category)) {
        const userSnap = await db.collection("users").doc(uid).get();
        const dailyBudget = Number((userSnap.data() || {}).dailyBudget || 0);
        if (dailyBudget > 0) {
          const start = new Date();
          start.setHours(0, 0, 0, 0);
          const txs = await db
            .collection("users").doc(uid)
            .collection("transactions").get();
          let spentToday = 0;
          txs.forEach((d) => {
            const t = d.data();
            if (t.type !== "expense") return;
            if (SAVINGS_CATEGORIES.includes(t.category)) return;
            const when = new Date(t.date);
            if (!isNaN(when.getTime()) && when >= start) {
              spentToday += Number(t.amount || 0);
            }
          });
          if (spentToday >= dailyBudget) {
            await sendToUser(
              uid,
              "Daily budget reached ⚠️",
              `You've spent ${naira(spentToday)} today ��� your ${naira(dailyBudget)} daily limit is used up. Spending is frozen until tomorrow.`,
              { type: "budget_alert" }
            );
          }
        }
      }
    } catch (e) {
      logger.error("onNewTransaction notification failed", e);
    }
  }
);
