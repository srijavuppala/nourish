import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { setGlobalOptions } from 'firebase-functions/v2/options';
import { logger } from 'firebase-functions';

import { InvalidInput, parseMeal } from './src/parseMeal.js';

initializeApp();
setGlobalOptions({ region: 'us-central1', maxInstances: 10 });

/**
 * Parse a plain-language meal description into structured items.
 *
 * Callable rather than HTTP so Firebase checks the caller's auth token for us,
 * and App Check keeps it callable only from the real app. The Gemini key lives
 * in Secret Manager and is never sent to the client.
 */
export const parseMealCallable = onCall(
  {
    enforceAppCheck: true,
    secrets: ['GEMINI_API_KEY', 'USDA_API_KEY'],
    timeoutSeconds: 60,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to use the meal parser.');
    }

    try {
      return await parseMeal({
        text: request.data?.text,
        slot: request.data?.slot,
      });
    } catch (error) {
      if (error instanceof InvalidInput) {
        throw new HttpsError('invalid-argument', error.message);
      }
      // Log without the meal text — it is the user's private data.
      logger.error('parseMeal failed', {
        uid: request.auth.uid,
        message: error.message,
      });
      throw new HttpsError(
        'internal',
        "I couldn't read that just now. Try again in a moment.",
      );
    }
  },
);

/**
 * Delete the signed-in user's data and their auth record.
 *
 * `recursiveDelete` clears every subcollection under `users/{uid}`, which a
 * client-side delete cannot do.
 */
export const deleteAccount = onCall(
  { enforceAppCheck: true, timeoutSeconds: 120 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in first.');
    }
    const uid = request.auth.uid;

    const firestore = getFirestore();
    await firestore.recursiveDelete(firestore.doc(`users/${uid}`));
    await getAuth().deleteUser(uid);

    logger.info('Account deleted', { uid });
    return { deleted: true };
  },
);
