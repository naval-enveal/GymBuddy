/// The app's top-level authentication status, watched by the `AuthGate`.
///
/// Kept as a tiny standalone enum so both the controller and the gate can
/// depend on it without one importing the other's widget code.
enum AuthStatus {
  /// Session restore hasn't resolved yet — show a splash, not the shell or the
  /// signed-out flow. Reserved for when launch-time token restore lands with
  /// the API client / secure storage task; the controller may start here then.
  unknown,

  /// A valid session exists. The `AuthGate` shows the app shell.
  authenticated,

  /// No session. The `AuthGate` shows the signed-out flow (landing + login /
  /// signup screens).
  unauthenticated,
}
