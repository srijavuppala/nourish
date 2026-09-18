import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_user.dart';
import '../../../core/constants.dart';
import '../../../core/demo_mode.dart';
import '../../../core/demo_store.dart';
import '../../auth/data/auth_repository.dart';
import '../models/profile.dart';
import '../models/targets.dart';

abstract class OnboardingRepository {
  Future<void> ensureUserDocument(AppUser user);
  Stream<bool> onboardingDone();
  Future<void> markOnboardingDone();
  Future<Profile?> loadProfile();
  Future<void> saveProfile(Profile profile);
  Stream<Targets?> watchTargets();
  Future<void> saveTargets(Targets targets);
  Future<void> appendChatMessage({
    required String role,
    required String text,
    List<Map<String, dynamic>>? parsedItems,
  });
}

class FirestoreOnboardingRepository implements OnboardingRepository {
  FirestoreOnboardingRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  /// Called on every sign-in. `merge` keeps onboarding progress intact when an
  /// existing user signs in again on a new device.
  @override
  Future<void> ensureUserDocument(AppUser user) async {
    await _firestore.doc(Paths.user(_uid)).set(
      {
        'name': user.displayName,
        'email': user.email,
        'photoUrl': user.photoUrl,
        'timezone': DateTime.now().timeZoneName,
        'lastSignInAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final snapshot = await _firestore.doc(Paths.user(_uid)).get();
    if (snapshot.data()?['createdAt'] == null) {
      await _firestore.doc(Paths.user(_uid)).set(
        {
          'createdAt': FieldValue.serverTimestamp(),
          'onboardingDone': false,
          'units': 'metric',
        },
        SetOptions(merge: true),
      );
    }
  }

  @override
  Stream<bool> onboardingDone() => _firestore
      .doc(Paths.user(_uid))
      .snapshots()
      .map((snapshot) => snapshot.data()?['onboardingDone'] == true);

  @override
  Future<void> markOnboardingDone() => _firestore.doc(Paths.user(_uid)).set(
        {'onboardingDone': true},
        SetOptions(merge: true),
      );

  @override
  Future<Profile?> loadProfile() async {
    final snapshot = await _firestore.doc(Paths.profile(_uid)).get();
    final data = snapshot.data();
    return data == null ? null : Profile.fromMap(data);
  }

  @override
  Future<void> saveProfile(Profile profile) =>
      _firestore.doc(Paths.profile(_uid)).set(profile.toMap());

  @override
  Stream<Targets?> watchTargets() =>
      _firestore.doc(Paths.targets(_uid)).snapshots().map(
            (snapshot) => snapshot.data() == null
                ? null
                : Targets.fromMap(snapshot.data()!),
          );

  @override
  Future<void> saveTargets(Targets targets) =>
      _firestore.doc(Paths.targets(_uid)).set(targets.toMap());

  /// Kept so the chat can be resumed, and so we can see where parsing failed.
  @override
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

class DemoOnboardingRepository implements OnboardingRepository {
  final _done = StreamController<bool>.broadcast();
  final _targets = StreamController<Targets?>.broadcast();

  @override
  Future<void> ensureUserDocument(AppUser user) async {}

  @override
  Stream<bool> onboardingDone() async* {
    final store = await DemoStore.instance();
    yield store.readDoc('user')?['onboardingDone'] == true;
    yield* _done.stream;
  }

  @override
  Future<void> markOnboardingDone() async {
    final store = await DemoStore.instance();
    await store.writeDoc('user', {'onboardingDone': true});
    _done.add(true);
  }

  @override
  Future<Profile?> loadProfile() async {
    final store = await DemoStore.instance();
    final data = store.readDoc('profile');
    return data == null ? null : Profile.fromMap(data);
  }

  @override
  Future<void> saveProfile(Profile profile) async {
    final store = await DemoStore.instance();
    await store.writeDoc('profile', profile.toMap());
  }

  @override
  Stream<Targets?> watchTargets() async* {
    final store = await DemoStore.instance();
    final data = store.readDoc('targets');
    yield data == null ? null : Targets.fromMap(data);
    yield* _targets.stream;
  }

  @override
  Future<void> saveTargets(Targets targets) async {
    final store = await DemoStore.instance();
    await store.writeDoc('targets', targets.toMap());
    _targets.add(targets);
  }

  @override
  Future<void> appendChatMessage({
    required String role,
    required String text,
    List<Map<String, dynamic>>? parsedItems,
  }) async {}
}

/// Null until someone is signed in — every screen behind the router has a user.
final onboardingRepositoryProvider = Provider<OnboardingRepository?>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return null;
  if (kDemoMode) return DemoOnboardingRepository();
  return FirestoreOnboardingRepository(FirebaseFirestore.instance, uid);
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
