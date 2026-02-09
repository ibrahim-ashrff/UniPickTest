# Play Store Build Guide

## 1. Set up signing

An `upload-keystore.jks` file may already exist. If not, or to create a new one:

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Store the keystore file in the project root and keep it safe. **Do not commit it to git.**

## 2. Configure key.properties

Edit `android/key.properties` and replace the placeholders with your keystore values:

```properties
storePassword=YOUR_ACTUAL_STORE_PASSWORD
keyPassword=YOUR_ACTUAL_KEY_PASSWORD
keyAlias=upload
storeFile=../upload-keystore.jks
```

- `storeFile`: Path to the keystore (relative to `android/`). `../upload-keystore.jks` = project root.
- If the keystore is elsewhere, use the correct path.

## 3. Build the App Bundle

```bash
flutter build appbundle
```

Output: `build/app/outputs/bundle/release/app-release.aab`

## 4. Upload to Play Console

1. Open [Google Play Console](https://play.google.com/console)
2. Create or select your app
3. **Release** → **Testing** → **Closed testing**
4. Create or edit a release
5. Upload `app-release.aab`
6. Add release notes and save

## Notes

- `key.properties` is gitignored.
- Keep the keystore and passwords secure; losing them blocks app updates.
- For Play App Signing, use the upload key and follow Play Console setup.
