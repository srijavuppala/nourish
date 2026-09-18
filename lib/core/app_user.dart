/// The app's own user type, so nothing outside the auth layer depends on
/// Firebase. Demo mode supplies one of these without a Firebase project.
class AppUser {
  const AppUser({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;
}
