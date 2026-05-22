const { onDocumentCreated, onDocumentUpdated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();
const BATCH_SIZE = 500;

// ============================================================
// UTILITY: Write workflow log
// ============================================================
async function writeWorkflowLog(surveyId, step, status, message, metadata = {}, error = null) {
  const logEntry = {
    surveyId,
    step,
    status,
    message,
    metadata,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (error) {
    logEntry.error = error.message || error;
    logEntry.errorStack = error.stack || '';
  }
  await db.collection('surveyWorkflowLogs').add(logEntry);
}

// ============================================================
// 1. SURVEY CAMPAIGN ORCHESTRATION
// ============================================================
exports.orchestrateSurvey = onDocumentCreated({
  document: 'dailySurveys/{surveyId}',
  region: 'europe-west1'
}, async (event) => {
  const snap = event.data;
  if (!snap) return;
  const survey = snap.data();
  const surveyId = event.params.surveyId;

  console.log(`[ORCHESTRATE] Starting survey ${surveyId}`);
  await writeWorkflowLog(surveyId, 'start', 'running', 'Survey campaign orchestration started.', { surveyName: survey.name || survey.title?.en });

  try {
    let questionIds = survey.questionIds || [];

    // Auto-populate questions if none specified or if referenced IDs don't exist
    if (questionIds.length === 0) {
      console.log(`[ORCHESTRATE] No questionIds specified. Auto-fetching all active questions.`);
      await writeWorkflowLog(surveyId, 'auto_fetch_questions', 'running', 'No questions specified. Auto-fetching active questions from surveyQuestions collection.');

      const questionsSnap = await db.collection('surveyQuestions')
        .where('isActive', '==', true)
        .get();

      questionIds = questionsSnap.docs.map(d => d.id);
      console.log(`[ORCHESTRATE] Auto-fetched ${questionIds.length} active questions.`);

      // Update the survey doc with the resolved question IDs
      await snap.ref.update({ questionIds });

      await writeWorkflowLog(surveyId, 'auto_fetch_questions', 'completed',
        `Auto-fetched ${questionIds.length} active questions.`,
        { questionCount: questionIds.length, autoPopulated: true });
    } else {
      // Validate that referenced question IDs actually exist
      const questionsSnap = await db.collection('surveyQuestions')
        .where('isActive', '==', true)
        .get();
      const validIds = new Set(questionsSnap.docs.map(d => d.id));
      const invalidIds = questionIds.filter(id => !validIds.has(id));

      if (invalidIds.length > 0) {
        console.warn(`[ORCHESTRATE] ${invalidIds.length} invalid questionIds found: ${invalidIds.join(', ')}. Replacing with all active questions.`);
        await writeWorkflowLog(surveyId, 'validate_questions', 'warning',
          `${invalidIds.length} questionIds not found in surveyQuestions. Auto-populating instead.`,
          { invalidIds, questionCount: questionIds.length });

        questionIds = Array.from(validIds);
        await snap.ref.update({ questionIds });
      }
    }

    if (questionIds.length === 0) {
      throw new Error('No active questions available in surveyQuestions collection. Aborting.');
    }

    await writeWorkflowLog(surveyId, 'validate_questions', 'completed', `Survey has ${questionIds.length} questions.`, { questionCount: questionIds.length });

    // Build user query
    let usersQuery = db.collection('userProfiles').where('isBanned', '==', false);
    const targetAudience = survey.targetAudience || 'all';
    const targetValue = survey.targetValue || '';

    if (targetAudience === 'city' && targetValue) {
      usersQuery = usersQuery.where('city', '==', targetValue);
    } else if (targetAudience === 'line' && targetValue) {
      usersQuery = usersQuery.where('favoriteLines', 'array-contains', targetValue);
    } else if (targetAudience === 'category' && targetValue) {
      usersQuery = usersQuery.where('category', '==', targetValue);
    }

    let lastDoc = null;
    let totalAssigned = 0;

    while (true) {
      let query = usersQuery.orderBy('__name__').limit(BATCH_SIZE);
      if (lastDoc) query = query.startAfter(lastDoc);

      const userSnapshot = await query.get();
      if (userSnapshot.empty) break;

      lastDoc = userSnapshot.docs[userSnapshot.docs.length - 1];
      let currentBatch = db.batch();

      for (const doc of userSnapshot.docs) {
        const userSurveyRef = db.collection('userSurveyStates').doc(`${doc.id}_${surveyId}`);
        currentBatch.set(userSurveyRef, {
          uid: doc.id,
          surveyId: surveyId,
          status: 'pending',
          blocked: survey.isMandatory || false,
          isMandatory: survey.isMandatory || false,
          isRead: false,
          isAnswered: false,
          notificationSent: true,
          notificationOpened: false,
          answeredAt: null,
          openedAt: null,
          reminderCount: 0,
          expiresAt: survey.expiresAt || null,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Create inAppNotification for each user
        const notifId = `${doc.id}_${surveyId}_notif`;
        const inboxRef = db.collection('inAppNotifications').doc(notifId);
        currentBatch.set(inboxRef, {
          uid: doc.id,
          type: 'survey',
          entityId: surveyId,
          title: survey.title || { en: 'Daily Survey', fr: 'Sondage Quotidien', ar: 'استبيان يومي' },
          body: survey.description || { en: 'A new survey is available.', fr: 'Un nouveau sondage est disponible.', ar: 'استبيان جديد متاح.' },
          read: false,
          clicked: false,
          priority: survey.isMandatory ? 'high' : 'normal',
          deepLink: `/survey/${surveyId}`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        totalAssigned++;
      }

      await currentBatch.commit();
    }

    await writeWorkflowLog(surveyId, 'assign_users', 'completed',
      `Assigned survey to ${totalAssigned} users with inAppNotifications.`,
      { totalAssigned }
    );

    // Update survey analytics
    await snap.ref.update({
      'analytics.totalTargets': totalAssigned,
      'analytics.totalOpened': 0,
      'analytics.totalAnswered': 0,
      'analytics.completionRate': 0,
    });

    // Send FCM push notifications via direct messaging (batched per user)
    let lastUserDoc = null;
    let fcmTotalSent = 0;

    while (true) {
      let userQuery = db.collection('userProfiles')
        .where('isBanned', '==', false)
        .orderBy('__name__')
        .limit(BATCH_SIZE);

      if (targetAudience === 'city' && targetValue) {
        userQuery = db.collection('userProfiles')
          .where('isBanned', '==', false)
          .where('city', '==', targetValue)
          .orderBy('__name__')
          .limit(BATCH_SIZE);
      }

      if (lastUserDoc) userQuery = userQuery.startAfter(lastUserDoc);

      const userSnap = await userQuery.get();
      if (userSnap.empty) break;

      lastUserDoc = userSnap.docs[userSnap.docs.length - 1];
      const tokens = [];

      for (const doc of userSnap.docs) {
        const token = doc.data().fcmToken;
        if (token) tokens.push(token);
      }

      if (tokens.length > 0) {
        try {
          const titleStr = survey.title?.en || survey.name || 'Daily Survey';
          const bodyStr = survey.description?.en || 'A new survey is available.';

          const message = {
            notification: { title: titleStr, body: bodyStr },
            data: {
              type: 'survey',
              surveyId: surveyId,
              isMandatory: (survey.isMandatory || false).toString(),
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            tokens,
          };

          const response = await admin.messaging().sendEachForMulticast(message);
          fcmTotalSent += response.successCount;

          const failedTokens = [];
          response.responses.forEach((resp, idx) => {
            if (!resp.success) failedTokens.push(tokens[idx]);
          });

          if (failedTokens.length > 0) {
            let cleanupBatch = db.batch();
            for (const doc of userSnap.docs) {
              if (failedTokens.includes(doc.data().fcmToken)) {
                cleanupBatch.update(doc.ref, { fcmToken: null });
              }
            }
            await cleanupBatch.commit();
          }
        } catch (fcmError) {
          console.error(`[ORCHESTRATE] FCM batch error: ${fcmError}`);
        }
      }
    }

    await writeWorkflowLog(surveyId, 'send_fcm', 'completed',
      `FCM notifications sent to ${fcmTotalSent} devices.`,
      { fcmTotalSent }
    );

    // Log analytics event
    await db.collection('analyticsEvents').add({
      eventType: 'survey_published',
      surveyId: surveyId,
      isMandatory: survey.isMandatory || false,
      targetAudience,
      targetValue,
      questionCount: questionIds.length,
      totalTargets: totalAssigned,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    await writeWorkflowLog(surveyId, 'orchestrate_complete', 'completed',
      `Survey campaign fully orchestrated. ${totalAssigned} users assigned, ${fcmTotalSent} FCM sent.`,
      { totalAssigned, fcmTotalSent, isMandatory: survey.isMandatory || false }
    );

    console.log(`[ORCHESTRATE] Survey ${surveyId} complete. Assigned to ${totalAssigned} users.`);
  } catch (error) {
    console.error(`[ORCHESTRATE] Failed for survey ${surveyId}:`, error);
    await writeWorkflowLog(surveyId, 'orchestrate', 'failed',
      `Orchestration failed: ${error.message}`, {}, error
    );
  }
});

// ============================================================
// 2. FCM NOTIFICATION DISPATCH (legacy support)
// ============================================================
exports.sendNotificationOnCreate = onDocumentCreated({
  document: 'notifications/{notificationId}',
  region: 'europe-west1'
}, async (event) => {
  const snap = event.data;
  if (!snap) return;
  const data = snap.data();
  const { targetType, city, lineId, category, type, surveyId } = data;

  const titleObj = typeof data.title === 'string' ? { en: data.title } : (data.title || { en: 'Notification' });
  const bodyObj = typeof data.body === 'string' ? { en: data.body } : (data.body || { en: 'You have a new message.' });
  const titleStr = titleObj.en || 'Notification';
  const bodyStr = bodyObj.en || 'You have a new message.';

  let usersQuery = db.collection('userProfiles').where('isBanned', '==', false);

  if (targetType === 'city' && city) {
    usersQuery = usersQuery.where('city', '==', city);
  } else if (targetType === 'line' && lineId) {
    usersQuery = usersQuery.where('favoriteLines', 'array-contains', lineId);
  } else if (targetType === 'category' && category) {
    usersQuery = usersQuery.where('category', '==', category);
  }

  let lastDoc = null;
  let totalSent = 0;

  while (true) {
    let query = usersQuery.orderBy('__name__').limit(BATCH_SIZE);
    if (lastDoc) query = query.startAfter(lastDoc);

    const userSnapshot = await query.get();
    if (userSnapshot.empty) break;

    lastDoc = userSnapshot.docs[userSnapshot.docs.length - 1];
    const tokens = [];
    let currentBatch = db.batch();

    for (const doc of userSnapshot.docs) {
      const inboxRef = db.collection('inAppNotifications').doc(`${doc.id}_${event.params.notificationId}`);
      currentBatch.set(inboxRef, {
        uid: doc.id,
        type: type || 'notification',
        entityId: surveyId || event.params.notificationId,
        title: titleObj,
        body: bodyObj,
        read: false,
        clicked: false,
        priority: type === 'survey' ? 'high' : 'normal',
        deepLink: type === 'survey' ? `/survey/${surveyId}` : `/notification/${event.params.notificationId}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      const token = doc.data().fcmToken;
      if (token) tokens.push(token);
    }

    await currentBatch.commit();

    if (tokens.length > 0) {
      const message = {
        notification: { title: titleStr, body: bodyStr },
        data: {
          type: type || 'notification',
          notificationId: event.params.notificationId,
          surveyId: surveyId || '',
          isMandatory: 'false',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        tokens,
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      totalSent += response.successCount;

      const failedTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) failedTokens.push(tokens[idx]);
      });

      if (failedTokens.length > 0) {
        let cleanupBatch = db.batch();
        for (const doc of userSnapshot.docs) {
          if (failedTokens.includes(doc.data().fcmToken)) {
            cleanupBatch.update(doc.ref, { fcmToken: null });
          }
        }
        await cleanupBatch.commit();
      }
    }
  }

  await snap.ref.update({
    sentCount: totalSent,
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
    status: 'sent',
  });

  if (surveyId) {
    await writeWorkflowLog(surveyId, 'send_fcm', 'completed',
      `FCM sent to ${totalSent} devices + inAppNotifications populated.`,
      { totalSent }
    );

    const statesSnap = await db.collection('userSurveyStates')
      .where('surveyId', '==', surveyId)
      .get();

    if (!statesSnap.empty) {
      const batch = db.batch();
      statesSnap.docs.forEach((doc) => {
        batch.update(doc.ref, { notificationSent: true });
      });
      await batch.commit();
    }
  }

  console.log(`[FCM] Notification ${event.params.notificationId}: ${totalSent} devices notified.`);
});

// ============================================================
// 3. TRACK SURVEY ANSWER → AUTO-UPDATE USER STATE
// ============================================================
exports.onSurveyAnswerCreated = onDocumentCreated({
  document: 'surveyAnswers/{answerId}',
  region: 'europe-west1',
}, async (event) => {
  const snap = event.data;
  if (!snap) return;
  const answer = snap.data();
  const surveyId = answer.surveyId || '';
  const uid = answer.uid || answer.userId || '';
  if (!surveyId || !uid) return;

  try {
    await db.collection('userSurveyStates').doc(`${uid}_${surveyId}`).update({
      status: 'answered',
      isAnswered: true,
      blocked: false,
      answeredAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update survey analytics
    const statesSnap = await db.collection('userSurveyStates')
      .where('surveyId', '==', surveyId)
      .get();

    const totalTargets = statesSnap.size;
    const answered = statesSnap.docs.filter(d => d.data().status === 'answered' || d.data().isAnswered === true).length;
    const completionRate = totalTargets > 0 ? Math.round((answered / totalTargets) * 100) : 0;

    await db.collection('dailySurveys').doc(surveyId).update({
      'analytics.totalAnswered': answered,
      'analytics.completionRate': completionRate,
    });

    // Log analytics event
    await db.collection('analyticsEvents').add({
      eventType: 'survey_answered',
      uid: uid,
      surveyId: surveyId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    console.log(`[ANSWER] Could not update state for ${uid}_${surveyId}: ${e}`);
  }
});

// ============================================================
// 4. SCHEDULED: AGGREGATE SURVEY METRICS (every 60 min)
// ============================================================
exports.aggregateSurveyMetrics = onSchedule({
  schedule: 'every 60 minutes',
  region: 'europe-west1',
  timeZone: 'Africa/Casablanca',
}, async () => {
  console.log('[METRICS] Starting scheduled aggregation');
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const todayStr = today.toISOString().split('T')[0];

  try {
    const surveysSnap = await db.collection('dailySurveys').get();
    let totalPlatformAnswers = 0;

    for (const surveyDoc of surveysSnap.docs) {
      const survey = surveyDoc.data();
      const surveyId = surveyDoc.id;

      const statesSnap = await db.collection('userSurveyStates')
        .where('surveyId', '==', surveyId)
        .get();

      const totalAssigned = statesSnap.size;
      const answered = statesSnap.docs.filter(d => d.data().status === 'answered' || d.data().isAnswered === true).length;
      const pending = statesSnap.docs.filter(d => d.data().status === 'pending').length;
      const expired = statesSnap.docs.filter(d => d.data().status === 'expired').length;
      const completionRate = totalAssigned > 0 ? (answered / totalAssigned * 100) : 0;

      const answersSnap = await db.collection('surveyAnswers')
        .where('surveyId', '==', surveyId)
        .get();
      totalPlatformAnswers += answersSnap.size;

      // Rich breakdowns
      const questionBreakdown = {};
      const cityBreakdown = {};
      const genderBreakdown = {};
      const lineBreakdown = {};
      const ageBreakdown = { '18-24': 0, '25-34': 0, '35-44': 0, '45+': 0 };

      for (const doc of answersSnap.docs) {
        const a = doc.data();
        const qId = a.questionId;
        questionBreakdown[qId] = (questionBreakdown[qId] || 0) + 1;

        const city = a.userMetadata?.city || a.city || 'unknown';
        cityBreakdown[city] = (cityBreakdown[city] || 0) + 1;

        const gender = a.userMetadata?.gender || a.userGender || 'unknown';
        genderBreakdown[gender] = (genderBreakdown[gender] || 0) + 1;

        const line = a.userMetadata?.mainLine || 'unknown';
        lineBreakdown[line] = (lineBreakdown[line] || 0) + 1;

        const age = a.userMetadata?.age || a.userAge || 0;
        if (age >= 18 && age <= 24) ageBreakdown['18-24']++;
        else if (age >= 25 && age <= 34) ageBreakdown['25-34']++;
        else if (age >= 35 && age <= 44) ageBreakdown['35-44']++;
        else if (age >= 45) ageBreakdown['45+']++;
      }

      await db.collection('aggregatedMetrics').doc(`survey_${surveyId}_${todayStr}`).set({
        type: 'survey_daily',
        surveyId,
        surveyName: survey.name || survey.title?.en || '',
        date: todayStr,
        totalAssigned,
        totalAnswered: answered,
        totalPending: pending,
        totalExpired: expired,
        completionRate: Math.round(completionRate * 100) / 100,
        totalAnswers: answersSnap.size,
        questionBreakdown,
        cityBreakdown,
        genderBreakdown,
        lineBreakdown,
        ageBreakdown,
        isMandatory: survey.isMandatory || false,
        targetAudience: survey.targetAudience || 'all',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }

    const allUsersSnap = await db.collection('userProfiles')
      .where('isBanned', '==', false)
      .get();

    const answeredUsersSnapshot = await db.collectionGroup('userSurveyStates')
      .where('status', '==', 'answered')
      .get();

    await db.collection('aggregatedMetrics').doc(`platform_${todayStr}`).set({
      type: 'platform_daily',
      date: todayStr,
      totalActiveUsers: allUsersSnap.size,
      totalSurveyAnswers: totalPlatformAnswers,
      totalAnsweredSurveys: answeredUsersSnapshot.size,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log(`[METRICS] Aggregated ${surveysSnap.docs.length} surveys. Total answers: ${totalPlatformAnswers}`);
  } catch (error) {
    console.error('[METRICS] Aggregation failed:', error);
  }
});

// ============================================================
// 5. SCHEDULED: REMINDER FOR PENDING SURVEYS (every 6 hours)
// ============================================================
exports.sendSurveyReminders = onSchedule({
  schedule: 'every 6 hours',
  region: 'europe-west1',
  timeZone: 'Africa/Casablanca',
}, async () => {
  console.log('[REMINDER] Starting survey reminder check');
  try {
    const pendingStates = await db.collectionGroup('userSurveyStates')
      .where('status', '==', 'pending')
      .where('isMandatory', '==', true)
      .where('isAnswered', '==', false)
      .get();

    const grouped = {};
    for (const doc of pendingStates.docs) {
      const data = doc.data();
      const surveyId = data.surveyId;
      if (!grouped[surveyId]) grouped[surveyId] = [];
      grouped[surveyId].push({ uid: data.uid, docRef: doc.ref, reminderCount: data.reminderCount || 0 });
    }

    for (const [surveyId, users] of Object.entries(grouped)) {
      const surveyDoc = await db.collection('dailySurveys').doc(surveyId).get();
      if (!surveyDoc.exists) continue;
      const survey = surveyDoc.data();

      // Skip if expired
      if (survey.expiresAt && new Date(survey.expiresAt.toDate()) < new Date()) {
        const batch = db.batch();
        users.forEach(u => batch.update(u.docRef, { status: 'expired' }));
        await batch.commit();
        continue;
      }

      // Batch update reminder counts + send notifications
      let currentBatch = db.batch();
      let tokens = [];
      let count = 0;

      for (const user of users) {
        if (user.reminderCount >= 3) continue; // Max 3 reminders

        currentBatch.update(user.docRef, {
          reminderCount: admin.firestore.FieldValue.increment(1),
        });
        count++;

        // Get user profile for FCM token
        const userDoc = await db.collection('userProfiles').doc(user.uid).get();
        if (userDoc.exists && userDoc.data().fcmToken) {
          tokens.push(userDoc.data().fcmToken);
        }

        if (count >= BATCH_SIZE) {
          await currentBatch.commit();
          currentBatch = db.batch();
          count = 0;
        }
      }
      if (count > 0) await currentBatch.commit();

      // Send FCM reminders
      if (tokens.length > 0) {
        try {
          await admin.messaging().sendEachForMulticast({
            notification: {
              title: 'Survey Reminder',
              body: 'You have a pending survey. Please complete it to continue using the app.'
            },
            data: {
              type: 'survey',
              surveyId: surveyId,
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            tokens,
          });
          console.log(`[REMINDER] Sent ${tokens.length} reminders for survey ${surveyId}`);
        } catch (e) {
          console.error(`[REMINDER] FCM error for ${surveyId}:`, e);
        }
      }

      await writeWorkflowLog(surveyId, 'reminder', 'completed',
        `Sent ${tokens.length} reminder notifications.`,
        { totalUsers: users.length, remindersSent: tokens.length }
      );
    }

    console.log(`[REMINDER] Processed ${Object.keys(grouped).length} surveys with pending users.`);
  } catch (error) {
    console.error('[REMINDER] Failed:', error);
  }
});
