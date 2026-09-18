import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/demo_mode.dart';
import '../../../core/demo_store.dart';
import '../../auth/data/auth_repository.dart';
import '../models/day_log.dart';

/// One document per day, keyed `yyyy-MM-dd`.
abstract class CheckinRepository {
  Stream<DayLog?> watchDay(String date);
  Future<DayLog?> loadDay(String date);
  Future<void> saveDay(DayLog log);
  Stream<List<DayLog>> watchRange(DateTime from, DateTime to);
}

class FirestoreCheckinRepository implements CheckinRepository {
  FirestoreCheckinRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(Paths.days(_uid));

  @override
  Stream<DayLog?> watchDay(String date) =>
      _collection.doc(date).snapshots().map((snapshot) {
        final data = snapshot.data();
        return data == null ? null : DayLog.fromMap(snapshot.id, data);
      });

  @override
  Future<DayLog?> loadDay(String date) async {
    final snapshot = await _collection.doc(date).get();
    final data = snapshot.data();
    return data == null ? null : DayLog.fromMap(snapshot.id, data);
  }

  @override
  Future<void> saveDay(DayLog log) => _collection.doc(log.date).set(log.toMap());

  /// Days between two dates inclusive, for the History calendar. A month is
  /// about 30 small documents, which is one cheap query.
  @override
  Stream<List<DayLog>> watchRange(DateTime from, DateTime to) => _collection
      .where(FieldPath.documentId, isGreaterThanOrEqualTo: dayId(from))
      .where(FieldPath.documentId, isLessThanOrEqualTo: dayId(to))
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => DayLog.fromMap(doc.id, doc.data()))
            .toList(),
      );
}

class DemoCheckinRepository implements CheckinRepository {
  static const _key = 'days';

  final _controller = StreamController<List<DayLog>>.broadcast();

  Future<List<DayLog>> _all() async {
    final store = await DemoStore.instance();
    return store
        .readCollection(_key)
        .entries
        .map((entry) => DayLog.fromMap(entry.key, entry.value))
        .toList();
  }

  @override
  Stream<DayLog?> watchDay(String date) async* {
    yield await loadDay(date);
    yield* _controller.stream.map(
      (logs) => logs.where((log) => log.date == date).firstOrNull,
    );
  }

  @override
  Future<DayLog?> loadDay(String date) async {
    final store = await DemoStore.instance();
    final data = store.readCollection(_key)[date];
    return data == null ? null : DayLog.fromMap(date, data);
  }

  @override
  Future<void> saveDay(DayLog log) async {
    final store = await DemoStore.instance();
    final all = store.readCollection(_key);
    all[log.date] = log.toMap();
    await store.writeCollection(_key, all);
    _controller.add(await _all());
  }

  @override
  Stream<List<DayLog>> watchRange(DateTime from, DateTime to) async* {
    bool inRange(DayLog log) =>
        log.date.compareTo(dayId(from)) >= 0 &&
        log.date.compareTo(dayId(to)) <= 0;

    yield (await _all()).where(inRange).toList();
    yield* _controller.stream.map(
      (logs) => logs.where(inRange).toList(),
    );
  }
}

final checkinRepositoryProvider = Provider<CheckinRepository?>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return null;
  if (kDemoMode) return DemoCheckinRepository();
  return FirestoreCheckinRepository(FirebaseFirestore.instance, uid);
});

/// Today's log, which the Today tab's rings and check-in button read.
final todayLogProvider = StreamProvider<DayLog?>((ref) {
  final repository = ref.watch(checkinRepositoryProvider);
  if (repository == null) return Stream.value(null);
  return repository.watchDay(dayId(DateTime.now()));
});

/// The last 60 days, enough for the History calendar and the streak.
final recentDaysProvider = StreamProvider<List<DayLog>>((ref) {
  final repository = ref.watch(checkinRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  final now = DateTime.now();
  return repository.watchRange(now.subtract(const Duration(days: 60)), now);
});
