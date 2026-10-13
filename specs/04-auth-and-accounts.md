# 04 · Authentication, Accounts and Preferences

One account works in both apps. Auth is implemented with **Serverpod's built-in IDP**
(`serverpod_auth_idp_server` / `serverpod_auth_idp_flutter`, 4.1.x): email + password, and
**Sign in with Google** on web (§1.6).
The scaffolded `JwtConfigFromPasswords()` token manager and `ServerpodCloudEmailIdpConfig` (or
`EmailIdpConfigFromPasswords` when self-hosting mail) in `wonky_server/lib/server.dart` are
kept. **One sign-in covers both apps**: on web the session lives in Serverpod's httpOnly auth
cookie on the shared origin; desktop details in [01 §2.5](01-architecture.md).

## 1. Flows

### 1.1 Sign up
1. **Sign-up screen**: *Continue with Google* (web, §1.6; a line below it says continuing
   accepts the terms and the privacy policy), an "or" divider, then display name, email, password (+ strength meter), "I agree to the terms"
   checkbox with *Terms of service* · *Privacy policy* links below it (the web server's `/terms`
   and `/privacy` pages, suite 13 §5; opened like external links, `AppUrls.page`), *Create
   account* button, link to *Sign in*.
2. Server sends a verification code (development: logged to console).
3. **Verify email screen**: 6-digit code input (`ShadInputOTP`), *Resend code* (60 s cooldown),
   *Change email*.
4. On success → create `UserProfile` (see §3), set `writeDefaults.defaultThemeId` to the
   built-in default theme (built-in themes are global rows, see Write 06), create a welcome
   document + welcome spreadsheet (from templates) → land on **Home**.

### 1.2 Sign in
- *Continue with Google* (web, §1.6) and an "or" divider above the form.
- Email, password, *Remember me* (keeps the session across restarts: on web via the shared
  httpOnly auth cookie, on desktop via secure storage), *Forgot password?*, *Create account*.
- Errors inline under fields; rate limited server-side (IDP default) with a friendly message.

### 1.3 Password reset
Request (email) → code screen → new password + confirm → signed in.

### 1.4 Sign out
Account menu → *Sign out*. Signs out of **both** apps (shared session). Clears tokens, local caches marked user-scoped (Write offline cache,
Sheets sync DB is **kept** but locked to that user id; signing in as a different user uses a
different DB file — see offline spec), and in-memory undo stacks.

### 1.5 Session expiry
JWT refresh is automatic. If refresh fails (revoked/expired), show a blocking
**"Session expired"** dialog over the current screen (state preserved) with a sign-in form;
after re-auth the user continues where they were. Pending offline changes are kept.

### 1.6 Sign in with Google (web)
Serverpod's Google IDP ([Serverpod docs](https://docs.serverpod.dev/concepts/authentication/providers/google/setup)),
OAuth2 authorization code + PKCE in a popup (the single-window exception of
[03 §1](03-app-shell-and-navigation.md)). Desktop doesn't offer it yet.

- **Server** (`platform/users/google_idp.dart`): enabled only when the `googleClientSecret`
  password holds a valid client JSON (the Google Cloud console's *Web application* client,
  `{"web": {"client_id", "client_secret", …}}`; on Serverpod Cloud a password secret).
  `redirect_uris` is optional: Google's download only has it when the client had redirect
  URIs at download time, Serverpod requires the key but doesn't use it, and Google validates
  the redirect URI against the console. A missing or invalid secret turns Google sign-in off with a warning on stderr; it
  never stops the server. `GoogleIdpEndpoint` (`googleIdp`) extends `GoogleIdpBaseEndpoint`;
  `FlutterWebAuth2CallbackRoute` serves `/auth/callback`, the page that posts the code back to
  the app (same origin as `/write/` and `/sheets/`). `AppConfigRoute` adds `google: {clientId,
  redirectUri}` to `config.json`, with `redirectUri` = the public web origin + `/auth/callback`
  ([01 §2.4](01-architecture.md)).
- **Accounts**: Google's default validation requires a verified email and a name. A first
  Google sign-in for an email that already has a Wonky account signs in to **that** account
  (the Google account is linked to it and the auth user the IDP just created is deleted);
  otherwise a new `UserProfile` is created with Google's full name. Later sign-ins use the
  linked account.
- **Client** (`auth/google_web_flow.dart`, `google_popup_web.dart`): Wonky runs the popup
  itself instead of `GoogleWebSignInService`/`flutter_web_auth_2`. The apps are
  cross-origin isolated (COOP `same-origin`, 13 §3), so the popup has no opener and the app
  can't see it close: the plugin would spin until its 5-minute timeout, and a retry could take
  the earlier attempt's result. `GoogleAuthRequest` builds Google's authorization URL (PKCE
  S256, random `state`, `openid` + email + profile scopes, `prompt=select_account`); the popup
  (`window.open`, one window name, opened in the click's task) returns via `/auth/callback`,
  which leaves the callback URL in `localStorage` (or posts it to the opener); results are
  matched by `state`, and stale ones are dropped. A new click restarts the attempt in the same
  popup, so the button stays enabled while it waits. `access_denied` (the user declined) does
  nothing; a blocked popup says to allow pop-ups. Then `googleIdp.loginWithCode(code,
  codeVerifier, redirectUri)` and `client.auth.updateSignedInUser`. The *Continue with Google* button
  (outline, Google's unaltered multicolor "G" — `GoogleLogo` in `wonky_ui` — in light and
  dark) is shown on web; when the server has no Google client (e.g. local development without
  the callback registered) it shows "Sign in with Google isn't set up on this server." Closing
  the popup does nothing. The button also appears in the session-expired dialog's form.
- **Google Cloud console** (production): authorized JavaScript origin `https://wonky.work`,
  redirect URI `https://wonky.work/auth/callback`, authorized domain `wonky.work`, consent
  screen links `https://wonky.work/privacy` and `https://wonky.work/terms` (13 §5).

## 2. Screens (shared, in `wonky_app`)

| Screen | Route | Notes |
|--------|-------|-------|
| Sign in | `/signin` | Centered card (max 400 px) on branded background; the suite icon (Wonky Work product icon, 56 px, [02 §5](02-design-system.md)) and "Wonky Work" as the headline (no app name, no subheadline), left-aligned with the card: one account covers both apps. |
| Sign up | `/signup` | Same layout. |
| Verify email | `/signup/verify` | |
| Forgot password | `/reset` | |
| Account settings | `/settings/account` | See §4. |

All auth screens support light/dark and are keyboard navigable (Enter submits).

## 3. Data model (server, `wonky_server/lib/src/platform/users/`)

```yaml
# user_profile.spy.yaml
class: UserProfile
table: user_profile
fields:
  authUserId: UuidValue          # serverpod auth user id (unique)
  displayName: String
  email: String                  # denormalized for search/mentions (lowercased)
  avatarFileId: UuidValue?       # → StoredFile
  avatarColor: String            # hex, deterministic from id, used for presence/initials
  locale: String?                # BCP-47, null = follow browser/OS
  timeZone: String?              # IANA, null = follow device
  createdAt: DateTime
  lastSeenAt: DateTime?
indexes:
  user_profile_auth_idx: { fields: authUserId, unique: true }
  user_profile_email_idx: { fields: email, unique: true }
```

```yaml
# user_preferences.spy.yaml
class: UserPreferences
table: user_preferences
fields:
  userId: int, relation(parent=user_profile, onDelete=Cascade)
  appTheme: AppThemeMode         # enum: system, light, dark
  accentColor: String?           # optional accent override (one of the design system accents)
  density: UiDensity             # enum: comfortable, compact
  keymapOverrides: String        # JSON {commandId: [binding,…]}
  writeDefaults: String          # JSON: default theme id, spellcheck on, smart quotes, etc.
  sheetsDefaults: String         # JSON: default locale for new sheets, default font, etc.
  notificationSettings: String   # JSON: email digests on/off, mention emails, etc.
  aiEnabled: bool, default=true
indexes:
  user_preferences_user_idx: { fields: userId, unique: true }
```

`PersonalAccessToken` (for MCP, see [09-mcp.md](09-mcp.md)):

```yaml
class: PersonalAccessToken
table: personal_access_token
fields:
  userId: int, relation(parent=user_profile, onDelete=Cascade)
  name: String
  tokenHash: String              # sha256 of the secret; secret shown once
  prefix: String                 # first 8 chars for display, e.g. "wkpat_ab12…"
  scopes: List<String>           # e.g. ["drive:read","write:edit","sheets:edit","ui:control"]
  expiresAt: DateTime?
  lastUsedAt: DateTime?
  createdAt: DateTime
  revokedAt: DateTime?
```

## 4. Settings screen (`/settings/*`)

Full-screen in-app page with a left nav (shad `ShadTabs` vertical or custom `SettingsNav`):

1. **Account** – avatar upload/crop (circle crop dialog), display name, email (change flow with
   verification), password change, delete account (type-to-confirm; transfers or deletes owned
   files — dialog lists counts).
2. **Appearance** – App theme (System/Light/Dark segmented control with live preview cards),
   density, reduce motion. (No accent color choice: the app uses the neutral palette; the stored
   `accentColor` preference is ignored.)
3. **Language & region** – UI language, default locale for new spreadsheets (number/date
   formats), time zone.
4. **Keyboard shortcuts** – see [08-commands-and-undo.md](08-commands-and-undo.md) §1.2.
5. **Write** (nav item with the Write product icon) – default theme, spellcheck, smart quotes,
   auto-pair brackets, Markdown shortcuts on/off, default page setup, default export format.
6. **Sheets** (nav item with the Sheets product icon) – default font/size, default number locale, formula autocomplete, show formula
   help, iterative calc defaults, enable scripts (per-user kill switch).
7. **Notifications** – mentions, comment replies, share notifications: in-app / email / off.
8. **AI** – enable assistant, default model tier (Fast/Balanced/Best — maps to server-side model
   choice), clear AI history, the privacy notice naming the provider; when AI isn't configured,
   *Add an API key* links to *AI providers*.
   **AI providers** (`/settings/ai-providers`, its own nav item after AI) – which provider the
   server uses; when the server has no key, the user's own key: provider select (OpenAI /
   Anthropic / Google Gemini), masked key field, *Save key*, and the saved key shown as
   "OpenAI key ending in abcd" with *Remove key* (confirm). The key is never shown again
   ([10 §1](10-ai-assistant.md)).
9. **Developer / MCP** – *Server* status: whether the backend is connected to Redis
   (*Connected* / *Not reachable* / *Not configured*, from `ProtocolInfo.redisEnabled` /
   `redisConnected` — `meta.getInfo` pings Redis, 1 s timeout — with a reload button); personal access tokens (list, create with name + scopes + expiry, copy
   once, revoke), MCP connection instructions (copyable JSON config for Claude Desktop /
   Claude Code), live UI-bridge status ("This window is controllable by MCP: On/Off").
10. **Offline & storage** – offline availability toggles (per file pinning list), local storage
    used, "Clear local data", sync status/errors log.
11. **About** – versions (app, server, protocol), licenses (`LicensePage` styled), links.

Every setting change is a command (e.g. `shell.settings.setAppTheme`) so it is MCP-controllable;
settings are **not** on the undo stack (they apply immediately and are trivially reversible).

## 5. Endpoints

`UserEndpoint` (`user`): `getMe()`, `updateProfile(displayName, locale, timeZone)`,
`uploadAvatar()` (upload description flow), `getPreferences()`, `updatePreferences(patch)`,
`searchUsers(query, limit)` (for share dialog & @mentions; only returns users who share at least
one item with the caller, or exact email matches), `deleteAccount(confirmation)`.

`GoogleIdpEndpoint` (`googleIdp`): Serverpod's `GoogleIdpBaseEndpoint` (`loginWithCode`, §1.6).

`AccessTokenEndpoint` (`accessToken`): `list()`, `create(name, scopes, expiresAt)` →
`{token, secret}`, `revoke(id)`.
