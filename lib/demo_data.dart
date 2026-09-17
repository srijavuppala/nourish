// Synthetic presentation records, dated relative to the day the demo is opened.
// Never sourced from a real diary or Supabase account.
Map<String, dynamic> demoState(DateTime now) {
  String date(int offset) {
    final d = DateTime(now.year, now.month, now.day + offset);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> meal(
          String id,
          String name,
          String cuisine,
          String image,
          String group,
          int offset,
          int kcal,
          int p,
          int c,
          int f) =>
      {
        'id': id,
        'name': name,
        'cuisine': cuisine,
        'image': image,
        'group': group,
        'date': date(offset),
        'servings': 1.0,
        'kcal': kcal,
        'p': p,
        'c': c,
        'f': f,
      };
  Map<String, dynamic> workout(int offset, bool done) => {
        'id': 'demo-workout-$offset',
        'title': 'Walk & unwind',
        'minutes': 30,
        'date': date(offset),
        'done': done,
        'checked': done ? ['0:0', '1:0', '2:0'] : <String>[],
        'notes':
            done ? 'Sample session · a little movement goes a long way.' : '',
        'exercises': [
          {
            'name': 'Easy warm-up walk',
            'sets': 1,
            'reps': '5 minutes',
            'load': 'Easy pace'
          },
          {
            'name': 'Comfortable brisk walk',
            'sets': 1,
            'reps': '20 minutes',
            'load': 'Your own pace'
          },
          {
            'name': 'Cool-down walk',
            'sets': 1,
            'reps': '5 minutes',
            'load': 'Easy pace'
          },
        ]
      };
  return {
    'profile': {
      'name': 'Alex',
      'goal': 'Feel balanced',
      'diet': 'Everything',
      'cuisines': ['Indian', 'Italian', 'Japanese', 'American'],
      'calories': 2000,
      'protein': 100,
      'carbs': 250,
      'fat': 67,
      'done': true,
    },
    'meals': [
      meal('demo-breakfast', 'Chickpea & avocado bowl', 'Italian',
          'mediterranean-salad.jpg', 'Breakfast', 0, 420, 18, 46, 18),
      meal('demo-lunch', 'Homestyle dal & rice', 'Indian', 'indian-curry.jpg',
          'Lunch', 0, 510, 22, 78, 12),
      for (int d = -6; d < 0; d++) ...[
        meal('demo-history-am-$d', 'Garden grain bowl', 'American',
            'mediterranean-salad.jpg', 'Breakfast', d, 390, 16, 52, 14),
        meal('demo-history-mid-$d', 'Homestyle dal & rice', 'Indian',
            'indian-curry.jpg', 'Lunch', d, 510, 22, 78, 12),
        meal('demo-history-pm-$d', 'Teriyaki salmon bowl', 'Japanese',
            'japanese-salmon.jpg', 'Dinner', d, 580, 38, 62, 20),
      ],
    ],
    'plans': [
      {
        ...meal('demo-plan-1', 'Teriyaki salmon bowl', 'Japanese',
            'japanese-salmon.jpg', 'Dinner', 0, 580, 38, 62, 20),
        'logged': false
      },
      {
        ...meal('demo-plan-2', 'Paneer & vegetable bowl', 'Indian',
            'indian-curry.jpg', 'Lunch', 1, 480, 28, 32, 27),
        'logged': false
      },
      {
        ...meal('demo-plan-3', 'Tomato & chickpea salad', 'Italian',
            'mediterranean-salad.jpg', 'Lunch', 2, 340, 16, 36, 16),
        'logged': false
      },
    ],
    'workouts': [workout(-2, true), workout(0, false), workout(2, false)],
    'weights': [
      {'date': date(-6), 'kg': 68.4},
      {'date': date(-3), 'kg': 68.2},
      {'date': date(0), 'kg': 68.3},
    ],
    'water': {date(0): 1000},
    'saved': ['Homestyle dal & rice', 'Miso tofu rice bowl'],
    'groceriesChecked': <String>[],
  };
}
