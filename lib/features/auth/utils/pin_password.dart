// PIN login helper. Added 16 October 2026.
//
// WHY THIS EXISTS: the app's PIN is 4 digits, but Firebase email/password
// accounts need a password of at least 6 characters. Registration was linking
// the raw 4 digit PIN, Firebase rejected it as too short, and the error was
// swallowed. The account was left with no password at all, so every PIN login
// afterwards failed with "Incorrect PIN" even when the PIN was right.
//
// The fix: never send the raw PIN to Firebase. Always send this padded form,
// both when the PIN is saved (registration) and when it is checked (login).

String pinToFirebasePassword(String pin) => 'GoOuts#${pin.trim()}';
