# Web app and PWA

The Flutter web build is what Netlify publishes (`netlify.toml` publishes `build/web`). `web/_redirects` and the Netlify redirect send every path to `index.html`, so these routes stay stable:

| Path | Page |
| --- | --- |
| `/privacy` | Privacy Policy |
| `/terms` | Terms |
| `/support` | Support and safety |
| `/delete-account` | Account deletion instructions |

Each page shows the text **Draft, pending legal review**. They do not require a session. The session guard returns null for those paths, including while the app is still booting.

## Installable PWA

`web/manifest.json` sets `name` and `short_name` to HOMIZI, `display` to `standalone`, portrait orientation, and PNG icons at 192 and 512 for both `any` and `maskable`. `web/index.html` links the manifest and the Apple touch icon.

Flutter 3.44 generates `flutter_service_worker.js` as a cleanup worker: it unregisters itself and has no fetch listener, and the bootstrap comment says that worker is deprecated. Chrome will not treat that file as an installable service worker. After `flutter build web`, `tool/install_web_sw.py` copies `web/homizi_sw.js` over `flutter_service_worker.js`. The loader still registers that name. The replacement worker caches the app shell, handles `fetch` for same-origin GET requests, and calls `skipWaiting` so an open tab can see `controllerchange`.

Check a build with:

```bash
python3 tool/check_web_pwa.py build/web
```

## Update prompt

`web/index.html` keeps a banner, hidden until a service worker update is waiting or a new worker takes control of a page that already had a controller. The first install does not show it. The banner says "A new version of HOMIZI is available." The Update button posts `SKIP_WAITING` to a waiting worker, if one exists, and reloads the page. Returning to the tab calls `registration.update()` so a long-lived tab can notice a new build.

Chrome's install criteria (HTTPS, manifest name, 192 and 512 icons, standalone display, and a service worker that handles fetch) are what that script checks. HTTPS is the Netlify site, not the local `file://` build.
