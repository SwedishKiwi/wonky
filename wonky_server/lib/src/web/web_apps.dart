/// The Flutter web apps the web server serves (specs/01-architecture.md
/// §2.4), each at `/<name>/` from `web/<name>/` (`--base-href /<name>/`).
///
/// An app whose build folder is missing (not built yet, or Wonky Slides
/// before it exists) answers with `web/pages/build_flutter_app.html`.
const webApps = ['drive', 'write', 'sheets', 'slides'];

/// Where the site root `/` sends the browser: Wonky Drive's home, the
/// default landing app (v2 review B4, replacing Q2's Write home;
/// `RootRedirectRoute`).
const rootRedirectTarget = '/drive/';
