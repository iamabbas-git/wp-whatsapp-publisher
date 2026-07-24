# WP + WhatsApp Publisher

A Flutter (Android) app to **write a message once, publish it to your WordPress
site, and hand it off to your WhatsApp groups.** The editor is rich-text with a
WhatsApp-style emoji picker. The same message becomes proper HTML on your website
and WhatsApp-formatted text (`*bold*`, `_italic_`, `~strike~`) for your groups.

## Why the WhatsApp part is a "hand-off" and not fully automatic

There is **no official, allowed way** to auto-post into your existing WhatsApp
groups. Meta's official Groups API can only create *new* invite-only groups (max
8 people); it cannot post to groups you already belong to. The only way to do
"connect my account and auto-broadcast to my real groups" is unofficial
automation that **violates WhatsApp's Terms of Service and risks your number
being banned.**

So this app takes the safe, compliant route: it publishes to WordPress
automatically, then opens WhatsApp with your message pre-filled so you pick the
group and tap send. One tap per group, no ban risk, your account stays safe.

## What you need

- **Flutter SDK** installed (`flutter doctor` should pass). Get it at
  https://docs.flutter.dev/get-started/install
- **Android Studio** (or the Android SDK + a device/emulator).
- A **WordPress site** where you can create an *Application Password*.

## Setup

### 1. Get the code ready

Unzip this project, open a terminal in the folder, and run:

```bash
flutter pub get
```

### 2. Create the WordPress Application Password

1. Log in to your site's `wp-admin`.
2. Go to **Users → Profile** (or **Edit My Profile**).
3. Scroll to **Application Passwords**, enter a name like `Publisher App`, and
   click **Add New Application Password**.
4. Copy the generated password (looks like `abcd EFGH ijkl MNOP ...`). You'll
   paste it into the app's **Connect WordPress** screen along with your site URL
   and username.

> Application Passwords require HTTPS and are enabled by default on modern
> WordPress. If you don't see the section, your host may have disabled it, or
> you may be behind a security plugin that blocks the REST API — enable REST API
> Basic Auth / Application Passwords there.

### 3. Generate the Android project files

This repo contains the app code (`lib/`), the manifest additions, and
`pubspec.yaml`. Generate the platform folders (android/, etc.):

```bash
flutter create --platforms=android --org com.yourname .
```

This adds the `android/` folder without touching the code in `lib/`.

### 4. Apply the Android manifest additions

Open `android/app/src/main/AndroidManifest.xml` and merge in the two blocks from
**`android_manifest_additions.xml`** in this repo (the `INTERNET` permission and
the `<queries>` block). These let the app reach your site and open/see WhatsApp
on Android 11+.

### 5. Run it

```bash
flutter run
```

## How to use

1. Tap **Connect** (top right) and enter your site URL, username, and the
   Application Password. Tap **Test & save connection**.
2. Type a **post title**, then write your message in the editor. Use the toolbar
   for bold/italic/lists/etc., and the 😊 button for emojis. Optionally tap
   **Add featured image** to attach a photo from your gallery.
3. Tap **Publish & share**. If you added an image, it's uploaded to your media
   library and set as the post's featured image first. The app publishes to WordPress, then shows a sheet
   with **Open in WhatsApp** / **Copy** / **Share…**. Pick your group in
   WhatsApp and send. Repeat **Open in WhatsApp** for each group.

### Saving drafts (with auto-save)

- The app **auto-saves** as you write: about 2 seconds after you stop typing,
  and again whenever the app goes to the background. So an unfinished message is
  kept even if you switch away or close the app.
- Tap the **save icon** (top bar) to save on demand. Re-saving while a draft is
  open updates that same draft rather than creating a duplicate.
- Tap the **folder icon** to open **Drafts** — tap any draft to load it back
  into the editor (title, formatted body, and featured image), or the trash
  icon to delete it.
- Drafts are kept **locally on your phone** (not on WordPress). When you publish
  a message that came from a draft, that draft is removed automatically.

### Featured image

- Tap **Add featured image** under the title to pick a photo from your gallery;
  a thumbnail appears with **Change** / remove controls.
- On publish, the image is uploaded to `wp/v2/media` and attached as the post's
  featured image. It's also remembered with the draft.
- When sharing to WhatsApp, if the message has an image the app uses the share
  sheet so the **image travels with the caption** (WhatsApp's plain text link
  can't carry an image).

## Automated testing (CI)

This repo includes a GitHub Actions workflow (`.github/workflows/flutter.yml`).
Push the project to a GitHub repository and, on every push, GitHub will:

1. `flutter pub get` — resolve dependencies
2. `flutter analyze` — static analysis (catches API/type errors)
3. `flutter test` — run the unit tests in `test/`
4. `flutter create` + `flutter build apk --debug` — verify it compiles for Android
5. Upload the built **debug APK** as a downloadable artifact on the run

So you don't need Flutter installed to know whether the app builds — open the
**Actions** tab after pushing, and a green check means it compiled and passed.
If a step fails, open it and copy the log; that output is exactly what's needed
to pin down and fix any issue.

To push it to GitHub:

```bash
cd wp_wa_publisher
git init && git add . && git commit -m "Initial commit"
# create an empty repo on github.com first, then:
git remote add origin https://github.com/<you>/<repo>.git
git push -u origin main
```

## Project layout

```
lib/
  main.dart                      App entry, theme, localization
  models/
    wp_credentials.dart          WordPress connection model
    draft.dart                   Saved-draft model (title + Quill delta)
  services/
    credential_store.dart        Secure storage of credentials (keystore)
    draft_store.dart             Local draft persistence (shared_preferences)
    wordpress_service.dart       WordPress REST client (posts + media upload)
    message_converter.dart       Quill Delta -> HTML (WordPress) & WhatsApp text
    whatsapp_share.dart          Open WhatsApp / share image+caption / clipboard
  screens/
    compose_screen.dart          Editor + emoji + publish/share flow
    settings_screen.dart         Connect WordPress
    drafts_screen.dart           View / load / delete saved drafts
```

## Notes & next steps

- **Credentials** are stored in the platform keystore/keychain via
  `flutter_secure_storage`, not in plain text.
- The WordPress post is published as `status: publish`. To publish as a draft
  instead, change the `status` argument in `compose_screen.dart` → `_publish()`.
- **Drafts** are saved locally with `shared_preferences` (see
  `services/draft_store.dart`). They stay on the device and are never uploaded.
- **Featured image** uses `image_picker` (gallery). On Android 13+ this uses the
  system Photo Picker, so no storage permission prompt is needed. If you also
  want to support the camera, add camera permission and pass
  `ImageSource.camera`.
- Ideas to extend: remember multiple sites, add categories/tags to the post
  payload, or support multiple images inside the post body.

## Dependencies

`flutter_quill` (pinned to `10.8.5`), `vsc_quill_delta_to_html`,
`emoji_picker_flutter`, `http`, `flutter_secure_storage`, `shared_preferences`,
`image_picker`, `cross_file`, `share_plus`, `url_launcher`.

`flutter_quill` is pinned because its API changes between major versions and the
compose screen is written against `10.8.5`. If you bump it, expect small changes
to the toolbar/editor constructor arguments.
