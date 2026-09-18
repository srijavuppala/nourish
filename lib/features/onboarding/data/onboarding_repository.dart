import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../auth/data/auth_repository.dart';
import '../models/profile.dart';
import '../models/targets.dart';

/// Reads and writes the user document, their quiz answers and their targets.
class OnboardingRepository {
  OnboardingRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  /// Called on every sign-in. `merge` keeps onboarding progress intact when an
  /// existing user signs in again on a new device.
  Future<void> ensureUserDocument(User user) async {
    await _firestore.doc(Paths.user(_uid)).set({
      'name': user.displayName,
      'email': user.email,
      'photoUrl': user.photoURL,
      'timezone': DateTime.now().timeZoneName,
      'lastSignInAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(mergeFields: [
      'name',
      'email',
      'photoUrl',
      'timezone',
      'lastSignInAt',
    ]));

    final snapshot = await _firestore.doc(Paths.user(_uid)).get();
    if (snapshot.data()?['createdAt'] == null) {
      await _firestore.doc(Paths.user(_uid)).set({
        'createdAt': FieldValue.serverTimestamp(),
        'onboardingDone': false,
        'units': 'metric',
      }, SetOptions(merge: true));
    }
  }

  Stream<bool> onboardingDone() => _firestore
      .doc(Paths.user(_uid))
      .snapshots()
      .map((snapshot) => snapshot.data()?['onboardingDone'] == true);

  Future<void> markOnboardingDone() => _firestore.doc(Paths.user(_uid)).set(
        {'onboardingDone': true},
        SetOptions(merge: true),
      );

  Future<Profile?> loadProfile() async {
    final snapshot = await _firestore.doc(Paths.profile(_uid)).get();
    final data = snapshot.data();
    return data == null ? null : Profile.fromMap(data);
  }

  Future<void> saveProfile(Profile profile) =>
      _firestore.doc(Paths.profile(_uid)).set(profile.toMap());

  Stream<Targets?> watchTargets() => _firestore
      .doc(Paths.targets(_uid))
      .snapshots()
      .map((snapshot) =>
          snapshot.data() == null ? null : Targets.fromMap(snapshot.data()!));

  Future<void> saveTargets(Targets targets) =>
      _firestore.doc(Paths.targets(_uid)).set(targets.toMap());

  /// Kept so the chat can be resumed, and so we can see where parsing failed.
  Future<void> appendChatMessage({
    required String role,
    required String text,
    List<Map<String, dynamic>>? parsedItems,
  }) =>
      _firestore.collection(Paths.chatLog(_uid)).add({
        'role': role,
        'text': text,
        'parsedItems': parsedItems,
        'createdAt': FieldValue.serverTimestamp(),
      });
}

/// Null until someone is signed in — every screen behind the router has a user.
final onboardingRepositoryProvider = Provider<OnboardingRepository?>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return null;
  return OnboardingRepository(FirebaseFirestore.instance, uid);
});

final targetsProvider = StreamProvider<Targets?>((ref) {
  final repository = ref.watch(onboardingRepositoryProvider);
  if (repository == null) return Stream.value(null);
  return repository.watchTargets();
});

final onboardingDoneProvider = StreamProvider<bool>((ref) {
  final repository = ref.watch(onboardingRepositoryProvider);
  if (repository == null) return Stream.value(false);
  return repository.onboardingDone();
});
