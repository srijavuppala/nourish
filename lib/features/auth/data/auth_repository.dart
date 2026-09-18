import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/app_user.dart';
import '../../../core/demo_mode.dart';
import '../../../core/demo_store.dart';

/// Google sign-in only — no passwords to remember, and none to leak.
abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;

  /// Returns null when the user backs out, which is a cancellation, not an
  /// error.
  Future<AppUser?> signIn();
  Future<void> signOut();
  Future<void> deleteAccount();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    fb.FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? fb.FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _functions = functions ?? FirebaseFunctions.instance;

  final fb.FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFunctions _functions;

  static AppUser? _map(fb.User? user) => user == null
      ? null
      : AppUser(
          uid: user.uid,
          displayName: user.displayName,
          email: user.email,
          photoUrl: user.photoURL,
        );

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(_map);

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Future<AppUser?> signIn() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;

    final auth = await account.authentication;
    final credential = fb.GoogleAuthProvider.credential(
      idToken: auth.idToken,
      accessToken: auth.accessToken,
    );

    final result = await _auth.signInWithCredential(credential);
    return _map(result.user);
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Deletes Firestore data and the auth record server-side, because a client
  /// cannot delete its own subcollections.
  @override
  Future<void> deleteAccount() async {
    await _functions.httpsCallable('deleteAccount').call<void>();
    await _googleSignIn.signOut();
  }
}

/// A signed-in user with no Firebase project behind it. Sign-in is a button
/// press that succeeds, so a demo can be shown end to end.
class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository() {
    _restore();
  }

  static const _demoUser = AppUser(
    uid: 'demo-user',
    displayName: 'Demo user',
    email: 'demo@nourish.app',
  );
  static const _signedInKey = 'auth';

  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  Future<void> _restore() async {
    final store = await DemoStore.instance();
    final signedIn = store.readDoc(_signedInKey)?['signedIn'] == true;
    _current = signedIn ? _demoUser : null;
    _controller.add(_current);
  }

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  AppUser? get currentUser => _current;

  @override
  Future<AppUser?> signIn() async {
    final store = await DemoStore.instance();
    await store.writeDoc(_signedInKey, {'signedIn': true});
    _current = _demoUser;
    _controller.add(_current);
    return _current;
  }

  @override
  Future<void> signOut() async {
    final store = await DemoStore.instance();
    await store.writeDoc(_signedInKey, {'signedIn': false});
    _current = null;
    _controller.add(null);
  }

  /// In demo mode this wipes the browser's stored demo data, which is the
  /// same promise the real one makes about the server.
  @override
  Future<void> deleteAccount() async {
    final store = await DemoStore.instance();
    await store.clear();
    _current = null;
    _controller.add(null);
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => kDemoMode ? DemoAuthRepository() : FirebaseAuthRepository(),
);

final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);
