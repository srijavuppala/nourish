import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../auth/data/auth_repository.dart';
import '../models/meal_item.dart';
import '../models/plan_meal.dart';

/// The user's standing meals — what the check-in deck is built from.
class PlanRepository {
  PlanRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(Paths.planMeals(_uid));

  Stream<List<PlanMeal>> watchMeals() => _collection.snapshots().map((snapshot) {
        final meals = snapshot.docs
            .map((doc) => PlanMeal.fromMap(doc.id, doc.data()))
            .toList();
        // Order by slot so the check-in deck runs breakfast to snacks.
        meals.sort((a, b) => a.slot.index.compareTo(b.slot.index));
        return meals;
      });

  Future<List<PlanMeal>> loadMeals() async {
    final snapshot = await _collection.get();
    final meals =
        snapshot.docs.map((doc) => PlanMeal.fromMap(doc.id, doc.data())).toList();
    meals.sort((a, b) => a.slot.index.compareTo(b.slot.index));
    return meals;
  }

  Future<String> addMeal({
    required MealSlot slot,
    required String label,
    required List<MealItem> items,
    String source = 'chat',
  }) async {
    final doc = await _collection.add(
      PlanMeal(id: '', slot: slot, label: label, items: items, source: source)
          .toMap(),
    );
    return doc.id;
  }

  Future<void> updateMeal(PlanMeal meal) =>
      _collection.doc(meal.id).set(meal.toMap());

  Future<void> deleteMeal(String mealId) => _collection.doc(mealId).delete();
}

final planRepositoryProvider = Provider<PlanRepository?>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return null;
  return PlanRepository(FirebaseFirestore.instance, uid);
});

final planMealsProvider = StreamProvider<List<PlanMeal>>((ref) {
  final repository = ref.watch(planRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchMeals();
});
