import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/demo_mode.dart';
import '../../../core/demo_store.dart';
import '../../auth/data/auth_repository.dart';
import '../models/meal_item.dart';
import '../models/plan_meal.dart';

/// The user's standing meals — what the check-in deck is built from.
abstract class PlanRepository {
  Stream<List<PlanMeal>> watchMeals();
  Future<List<PlanMeal>> loadMeals();
  Future<String> addMeal({
    required MealSlot slot,
    required String label,
    required List<MealItem> items,
    String source,
  });
  Future<void> updateMeal(PlanMeal meal);
  Future<void> deleteMeal(String mealId);
}

/// Breakfast first, snacks last, so the check-in deck runs in the order the
/// day does.
List<PlanMeal> _sorted(List<PlanMeal> meals) =>
    meals..sort((a, b) => a.slot.index.compareTo(b.slot.index));

class FirestorePlanRepository implements PlanRepository {
  FirestorePlanRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(Paths.planMeals(_uid));

  @override
  Stream<List<PlanMeal>> watchMeals() => _collection.snapshots().map(
        (snapshot) => _sorted(
          snapshot.docs
              .map((doc) => PlanMeal.fromMap(doc.id, doc.data()))
              .toList(),
        ),
      );

  @override
  Future<List<PlanMeal>> loadMeals() async {
    final snapshot = await _collection.get();
    return _sorted(
      snapshot.docs.map((doc) => PlanMeal.fromMap(doc.id, doc.data())).toList(),
    );
  }

  @override
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

  @override
  Future<void> updateMeal(PlanMeal meal) =>
      _collection.doc(meal.id).set(meal.toMap());

  @override
  Future<void> deleteMeal(String mealId) => _collection.doc(mealId).delete();
}

class DemoPlanRepository implements PlanRepository {
  static const _key = 'planMeals';

  final _controller = StreamController<List<PlanMeal>>.broadcast();

  @override
  Stream<List<PlanMeal>> watchMeals() async* {
    yield await loadMeals();
    yield* _controller.stream;
  }

  @override
  Future<List<PlanMeal>> loadMeals() async {
    final store = await DemoStore.instance();
    return _sorted(
      store
          .readCollection(_key)
          .entries
          .map((entry) => PlanMeal.fromMap(entry.key, entry.value))
          .toList(),
    );
  }

  Future<void> _emit() async => _controller.add(await loadMeals());

  @override
  Future<String> addMeal({
    required MealSlot slot,
    required String label,
    required List<MealItem> items,
    String source = 'chat',
  }) async {
    final store = await DemoStore.instance();
    final all = store.readCollection(_key);
    final id = 'meal-${DateTime.now().microsecondsSinceEpoch}';

    all[id] =
        PlanMeal(id: id, slot: slot, label: label, items: items, source: source)
            .toMap();
    await store.writeCollection(_key, all);
    await _emit();
    return id;
  }

  @override
  Future<void> updateMeal(PlanMeal meal) async {
    final store = await DemoStore.instance();
    final all = store.readCollection(_key);
    all[meal.id] = meal.toMap();
    await store.writeCollection(_key, all);
    await _emit();
  }

  @override
  Future<void> deleteMeal(String mealId) async {
    final store = await DemoStore.instance();
    final all = store.readCollection(_key)..remove(mealId);
    await store.writeCollection(_key, all);
    await _emit();
  }
}

final planRepositoryProvider = Provider<PlanRepository?>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return null;
  if (kDemoMode) return DemoPlanRepository();
  return FirestorePlanRepository(FirebaseFirestore.instance, uid);
});

final planMealsProvider = StreamProvider<List<PlanMeal>>((ref) {
  final repository = ref.watch(planRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchMeals();
});
