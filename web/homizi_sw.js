/* HOMIZI service worker.
   Flutter 3.44's generated flutter_service_worker.js only removes the old worker.
   tool/install_web_sw.py copies this file over that name after `flutter build web`
   so the loader registers a worker with a fetch handler. */
'use strict';

const CACHE = 'homizi-shell-v1';
const SHELL = [
  'index.html',
  'manifest.json',
  'flutter_bootstrap.js',
  'flutter.js',
  'main.dart.js',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) =>
      Promise.all(
        SHELL.map((path) => cache.add(path).catch(() => undefined)),
      ),
    ).then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys.filter((key) => key !== CACHE).map((key) => caches.delete(key)),
      ),
    ).then(() => self.clients.claim()),
  );
});

self.addEventListener('message', (event) => {
  const data = event.data;
  if (data && data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') {
    return;
  }
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) {
    return;
  }
  event.respondWith(
    fetch(request).then((response) => {
      if (response && response.ok) {
        const copy = response.clone();
        caches.open(CACHE).then((cache) => cache.put(request, copy));
      }
      return response;
    }).catch(() => caches.match(request)),
  );
});
