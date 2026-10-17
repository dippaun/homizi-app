# Release signing

Draft for the owner. This is the upload-key process for `in.homizi.app`. It is not a Play Console submission.

The release build reads an upload key from `android/key.properties` or from environment variables. The keystore and the passwords are gitignored. If they are missing, the release build is signed with the **debug** keystore and Gradle prints:

`WARNING: HOMIZI release signing is not configured`

That build must not be uploaded to Google Play. A successful configured build prints `HOMIZI release signing: using the upload key` and does not print the path or the passwords.

## Create the upload key

Run this on a machine you control. Store the keystore outside the repository.

```bash
keytool -genkey -v \
  -keystore "$HOME/homizi-secrets/homizi-upload-keystore.jks" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

`keytool` asks for a store password, a key password, and a name. Use a long password and keep the two passwords if you set them differently. The alias in this example is `upload`.

## Back it up

The upload key is how you prove a later build is an update to the same app.

- Copy `homizi-upload-keystore.jks` to a second place that is not this git repo: an encrypted disk and a password manager attachment, or the owner's offline backup.
- Store the store password, the key password, and the alias with that copy.
- Do not email the keystore to yourself, do not paste passwords into a chat, and do not commit them.
- Confirm the backup opens: `keytool -list -keystore /path/to/homizi-upload-keystore.jks`.

Losing the upload key before Play App Signing is turned on blocks updates. After Play App Signing is on, Google can reset the upload key, and you should still keep a backup so you do not have to wait on that reset.

## Play App Signing

Google Play signs the APKs that users install. You sign the App Bundle you upload.

1. In Play Console, create the app with application id `in.homizi.app` (an owner step).
2. When the first release is uploaded, enroll in **Play App Signing**. Let Google generate the app signing key. Do not export that key into this repo.
3. Use the upload key from this document as the upload certificate. Play Console shows the certificate fingerprint. Compare it with `keytool -list -v -keystore /path/to/homizi-upload-keystore.jks`.
4. Later updates must be signed with the same upload key, unless you complete Google's upload-key reset.

The debug keystore is not an upload key. A bundle signed with it is rejected by Play.

## `android/key.properties`

Copy `android/key.properties.example` to `android/key.properties`. That copy is gitignored.

```properties
storePassword=your-store-password
keyPassword=your-key-password
keyAlias=upload
storeFile=/absolute/path/outside/the/repo/homizi-upload-keystore.jks
```

`storeFile` may be absolute, or relative to the `android/` directory. The file must exist. A missing file is treated as "not configured" and the debug key is used.

## Environment variables

These override the same fields in `key.properties`. CI uses them so the keystore does not have to be committed. Empty values are ignored.

| Variable | `key.properties` field |
| --- | --- |
| `HOMIZI_UPLOAD_STORE_FILE` | `storeFile` |
| `HOMIZI_UPLOAD_STORE_PASSWORD` | `storePassword` |
| `HOMIZI_UPLOAD_KEY_ALIAS` | `keyAlias` |
| `HOMIZI_UPLOAD_KEY_PASSWORD` | `keyPassword` |

On GitHub Actions, `HOMIZI_UPLOAD_KEYSTORE_BASE64` is the keystore file encoded with `base64 -w 0`. The workflow decodes it to a temp file and sets `HOMIZI_UPLOAD_STORE_FILE`. If that secret is set and any password or the alias is missing, the job fails and does not print the values. If the keystore secret is absent, the job builds with the debug key and says so.

## Check a build

```bash
flutter build appbundle --release
```

Then:

```bash
jarsigner -verify -certs build/app/outputs/bundle/release/app-release.aab
```

A debug-signed bundle is only for local proof that the release compile works. Upload a bundle only after the warning is gone and Play App Signing is enrolled.
