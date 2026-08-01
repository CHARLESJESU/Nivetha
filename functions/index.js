const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");

initializeApp();
const db = getFirestore();

const userTypeOf = (id) => (id.startsWith("JO") ? "jobproviders" : "workers");

async function getUserDoc(userId) {
  const userType = userTypeOf(userId);
  return db
    .collection("users")
    .doc(userType)
    .collection(userType)
    .doc(userId)
    .get();
}

exports.sendChatNotification = onDocumentCreated(
  "chats/{postId}/messages/{messageId}",
  async (event) => {
    const message = event.data.data();
    const toUid = message.to;
    if (!toUid) {
      console.log("no 'to' field on message", message);
      return;
    }

    const userDoc = await getUserDoc(toUid);
    const token = userDoc.data()?.fcmToken;
    if (!token) {
      console.log(`no fcmToken for user ${toUid}, doc exists: ${userDoc.exists}`);
      return;
    }

    const fromUid = message.from ?? "";
    let senderName = "Someone";
    if (fromUid) {
      const senderDoc = await getUserDoc(fromUid);
      senderName = senderDoc.data()?.name || senderName;
    }

    console.log(`sending chat push to ${toUid}`);
    await getMessaging().send({
      token,
      notification: {
        title: "New message",
        body: `${senderName}: ${message.message ?? ""}`,
      },
      data: {
        type: "chat",
        postId: event.params.postId,
        senderId: fromUid,
      },
    });
  }
);

exports.sendApplicationStatusNotification = onDocumentUpdated(
  "applications/{jobProviderUserId}/posts/{orderId}/workers/{workerUserId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (before.status === after.status) return;
    if (after.status !== "accepted" && after.status !== "rejected") return;

    const workerUserId = event.params.workerUserId;
    const userDoc = await getUserDoc(workerUserId);
    const token = userDoc.data()?.fcmToken;
    if (!token) {
      console.log(`no fcmToken for worker ${workerUserId}`);
      return;
    }

    const body =
      after.status === "accepted"
        ? "You have been accepted for this job!"
        : "Your application was rejected for this job.";

    console.log(`sending application-status push to ${workerUserId}: ${after.status}`);
    await getMessaging().send({
      token,
      notification: { title: "New message", body },
      data: {
        type: "application_status",
        status: after.status,
        postId: event.params.orderId,
      },
    });
  }
);

exports.sendNewApplicationNotification = onDocumentCreated(
  "applications/{jobProviderUserId}/posts/{orderId}/workers/{workerUserId}",
  async (event) => {
    const application = event.data.data();
    const jobProviderUserId = event.params.jobProviderUserId;

    const userDoc = await getUserDoc(jobProviderUserId);
    const token = userDoc.data()?.fcmToken;
    if (!token) {
      console.log(`no fcmToken for job provider ${jobProviderUserId}`);
      return;
    }

    const workerName = application.name || "A worker";
    console.log(`sending new-application push to ${jobProviderUserId}`);
    await getMessaging().send({
      token,
      notification: {
        title: "New message",
        body: `${workerName} applied to your job post`,
      },
      data: {
        type: "new_application",
        postId: event.params.orderId,
        workerId: event.params.workerUserId,
      },
    });
  }
);

exports.notifyWorkersOfNewJob = onDocumentCreated(
  "jobs/workers/workers/{providerId}/order/{orderKey}",
  async (event) => {
    const job = event.data.data();
    console.log(`notifying workers topic of new job ${event.params.orderKey}`);
    await getMessaging().send({
      topic: "workers",
      notification: {
        title: "New message",
        body: job.description
          ? `New job posted: ${job.description}`
          : "A new job was posted",
      },
      data: {
        type: "new_job",
        postId: event.params.orderKey,
        providerId: event.params.providerId,
      },
    });
  }
);
