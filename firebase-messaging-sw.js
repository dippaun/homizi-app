/* HOMIZI web push worker. No-ops until web/firebase-config.js is filled. */
importScripts('firebase-config.js');

if (self.HOMIZI_FIREBASE_CONFIG) {
  importScripts('https://www.gstatic.com/firebasejs/11.6.0/firebase-app-compat.js');
  importScripts('https://www.gstatic.com/firebasejs/11.6.0/firebase-messaging-compat.js');
  firebase.initializeApp(self.HOMIZI_FIREBASE_CONFIG);
  firebase.messaging();
}
