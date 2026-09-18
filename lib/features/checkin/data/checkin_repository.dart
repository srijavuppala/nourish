import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../auth/data/auth_repository.dart';
import '../models/day_log.dart';

/// One document per day, keyed `yyyy-MM-dd`.
class CheckinRepository {
  CheckinRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(Paths.days(_uid));

  Stream<DayLog?> watchDay(String date) =>
      _collection.doc(date).snapshots().map((snapshot) {
        final data = snapshot.data();
        return data == null ? null : DayLog.fromMap(snapshot.id, data);
      });

  Future<DayLog?> loadDay(String date) async {
    final snapshot = await _collection.doc(date).get();
    final data = snapshot.data();
    return data == null ? null : DayLog.fromMap(snapshot.id, data);
  }

  Future<void> saveDay(DayLog log) => _collection.doc(log.date).set(log.toMap());

  /// Days between two dates inclusive, for the History calendar. A month is
  /// about 30 small documents, which is one cheap query.
  Stream<List<DayLog>> watchRange(DateTime from, DateTime to) => _collection
      .where(FieldPath.documentId, isGreaterThanOrEqualTo: dayId(from))
      .where(FieldPath.documentId, isLessThanOrEqualTo: dayId(to))
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => DayLog.fromMap(doc.id, doc.data()))
          .toList());
}

final checkinRepositoryProvider = Provider<CheckinRepository?>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return null;
  return CheckinRepository(FirebaseFirestore.instance, uid);
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
