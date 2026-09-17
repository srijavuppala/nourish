part of 'main.dart';

const recipeIngredients = <String, List<String>>{
  'Chickpea & avocado bowl': [
    'Chickpeas',
    'Avocado',
    'Tomatoes',
    'Mixed greens',
    'Lemon',
    'Olive oil'
  ],
  'Homestyle dal & rice': [
    'Lentils',
    'Rice',
    'Tomatoes',
    'Onion',
    'Seasonal vegetables',
    'Ground spices'
  ],
  'Teriyaki salmon bowl': [
    'Salmon',
    'Rice',
    'Mixed vegetables',
    'Teriyaki sauce'
  ],
  'Paneer & vegetable bowl': [
    'Paneer',
    'Bell peppers',
    'Tomatoes',
    'Onion',
    'Ground spices'
  ],
  'Garden grain bowl': [
    'Whole grains',
    'Chickpeas',
    'Mixed greens',
    'Tomatoes'
  ],
  'Miso tofu rice bowl': ['Tofu', 'Rice', 'Mixed greens', 'Miso paste'],
  'Tomato & chickpea salad': [
    'Tomatoes',
    'Chickpeas',
    'Fresh herbs',
    'Olive oil'
  ],
  'Grilled salmon plate': ['Salmon', 'Whole grains', 'Seasonal vegetables'],
};
const routines = <Map<String, dynamic>>[
  {
    'title': 'Full-body foundations',
    'kind': 'Gym',
    'minutes': 40,
    'exercises': [
      {
        'name': 'Goblet squat',
        'sets': 3,
        'reps': '8–10',
        'load': 'Choose a comfortable load'
      },
      {
        'name': 'Dumbbell row',
        'sets': 3,
        'reps': '10 each side',
        'load': 'Choose a comfortable load'
      },
      {
        'name': 'Incline push-up',
        'sets': 3,
        'reps': '8–12',
        'load': 'Bodyweight'
      },
      {
        'name': 'Dead bug',
        'sets': 2,
        'reps': '8 each side',
        'load': 'Bodyweight'
      }
    ]
  },
  {
    'title': 'At-home movement',
    'kind': 'Home',
    'minutes': 25,
    'exercises': [
      {'name': 'Chair squat', 'sets': 2, 'reps': '8–10', 'load': 'Bodyweight'},
      {'name': 'Wall push-up', 'sets': 2, 'reps': '8–10', 'load': 'Bodyweight'},
      {'name': 'Glute bridge', 'sets': 2, 'reps': '10', 'load': 'Bodyweight'},
      {
        'name': 'Standing march',
        'sets': 2,
        'reps': '45 seconds',
        'load': 'Bodyweight'
      }
    ]
  },
  {
    'title': 'Walk & unwind',
    'kind': 'Cardio',
    'minutes': 30,
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
      }
    ]
  },
];

class PlanMealDialog extends StatefulWidget {
  final DateTime initialDate;
  final Food? initialFood;
  final String diet;
  const PlanMealDialog(
      {super.key,
      required this.initialDate,
      this.initialFood,
      required this.diet});
  @override
  State<PlanMealDialog> createState() => _PlanMealDialogState();
}

class _PlanMealDialogState extends State<PlanMealDialog> {
  late DateTime day;
  late Food food;
  String group = 'Lunch';
  final portion = TextEditingController(text: '1');
  final form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    day = widget.initialDate;
    food = widget.initialFood ?? foods.first;
  }

  @override
  void dispose() {
    portion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Plan a meal'),
          content: SizedBox(
              width: 430,
              child: SingleChildScrollView(
                  child: Form(
                      key: form,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        DropdownButtonFormField<Food>(
                            isExpanded: true,
                            initialValue: food,
                            decoration:
                                const InputDecoration(labelText: 'Meal'),
                            items: foods
                                .where((f) =>
                                    widget.diet != 'Vegetarian' ||
                                    f.veg ||
                                    f == food)
                                .map((f) => DropdownMenuItem(
                                    value: f,
                                    child: Text(f.name,
                                        overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (v) => setState(() => food = v!)),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                            onPressed: () async {
                              final d = await showDatePicker(
                                  context: context,
                                  initialDate: day,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2040));
                              if (d != null) setState(() => day = d);
                            },
                            icon: const Icon(Icons.calendar_month),
                            label: Text(dayKey(day))),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                            initialValue: group,
                            decoration:
                                const InputDecoration(labelText: 'Meal time'),
                            items: ['Breakfast', 'Lunch', 'Dinner', 'Snacks']
                                .map((g) =>
                                    DropdownMenuItem(value: g, child: Text(g)))
                                .toList(),
                            onChanged: (v) => group = v!),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: portion,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Servings'),
                            validator: (s) {
                              final n = double.tryParse(s ?? '');
                              return n == null ||
                                      !n.isFinite ||
                                      n <= 0 ||
                                      n > 20
                                  ? 'Enter 0–20 servings'
                                  : null;
                            }),
                      ])))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (form.currentState!.validate())
                    Navigator.pop(context, {
                      ...food.entry(
                          group, double.parse(portion.text), dayKey(day)),
                      'logged': false
                    });
                },
                child: const Text('Add to plan'))
          ]);
}

class WorkoutEditor extends StatefulWidget {
  final Map<String, dynamic>? existing, template;
  final DateTime initialDate;
  const WorkoutEditor(
      {super.key, this.existing, this.template, required this.initialDate});
  @override
  State<WorkoutEditor> createState() => _WorkoutEditorState();
}

class _WorkoutEditorState extends State<WorkoutEditor> {
  final form = GlobalKey<FormState>();
  late TextEditingController title, minutes;
  late DateTime date;
  late List<Map<String, dynamic>> exercises;
  @override
  void initState() {
    super.initState();
    final s = widget.existing ?? widget.template ?? {};
    title = TextEditingController(text: s['title'] ?? 'My workout');
    minutes = TextEditingController(text: '${s['minutes'] ?? 30}');
    date = DateTime.tryParse(s['date'] ?? '') ?? widget.initialDate;
    exercises = List<Map<String, dynamic>>.from((s['exercises'] ??
            [
              {'name': '', 'sets': 3, 'reps': '10', 'load': 'Bodyweight'}
            ])
        .map((e) => Map<String, dynamic>.from(e)));
  }

  @override
  void dispose() {
    title.dispose();
    minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(
              widget.existing == null ? 'Build your workout' : 'Edit workout'),
          content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                  child: Form(
                      key: form,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                                controller: title,
                                maxLength: 100,
                                decoration: const InputDecoration(
                                    labelText: 'Workout name'),
                                validator: (s) => (s ?? '').trim().isEmpty
                                    ? 'Enter a name'
                                    : null),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                  child: TextFormField(
                                      controller: minutes,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                          labelText: 'Minutes'),
                                      validator: (s) {
                                        final n = int.tryParse(s ?? '');
                                        return n == null || n < 1 || n > 300
                                            ? 'Enter 1–300'
                                            : null;
                                      })),
                              const SizedBox(width: 14),
                              OutlinedButton.icon(
                                  onPressed: () async {
                                    final d = await showDatePicker(
                                        context: context,
                                        initialDate: date,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2040));
                                    if (d != null) setState(() => date = d);
                                  },
                                  icon: const Icon(Icons.calendar_today,
                                      size: 18),
                                  label: Text(dayKey(date)))
                            ]),
                            const SizedBox(height: 24),
                            const Text('Your exercises',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 18)),
                            const SizedBox(height: 8),
                            const Text(
                                'Include warm-up and recovery time. Edit example routines to suit you.',
                                style: TextStyle(fontSize: 13, color: muted)),
                            const SizedBox(height: 16),
                            for (int i = 0; i < exercises.length; i++)
                              Container(
                                  key: ObjectKey(exercises[i]),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                      border: Border.all(color: line),
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Column(children: [
                                    Row(children: [
                                      Expanded(
                                          child: TextFormField(
                                              initialValue: exercises[i]
                                                  ['name'],
                                              maxLength: 100,
                                              decoration: InputDecoration(
                                                  labelText:
                                                      'Exercise ${i + 1}'),
                                              onChanged: (v) =>
                                                  exercises[i]['name'] = v,
                                              validator: (s) =>
                                                  (s ?? '').trim().isEmpty
                                                      ? 'Enter an exercise'
                                                      : null)),
                                      IconButton(
                                          tooltip: 'Remove exercise ${i + 1}',
                                          onPressed: exercises.length == 1
                                              ? null
                                              : () => setState(
                                                  () => exercises.removeAt(i)),
                                          icon:
                                              const Icon(Icons.close, size: 18))
                                    ]),
                                    const SizedBox(height: 10),
                                    Row(children: [
                                      Expanded(
                                          child: TextFormField(
                                              initialValue:
                                                  '${exercises[i]['sets']}',
                                              decoration: const InputDecoration(
                                                  labelText: 'Sets'),
                                              keyboardType:
                                                  TextInputType.number,
                                              onChanged: (s) => exercises[i]
                                                      ['sets'] =
                                                  int.tryParse(s) ?? 0,
                                              validator: (s) {
                                                final n = int.tryParse(s ?? '');
                                                return n == null ||
                                                        n < 1 ||
                                                        n > 20
                                                    ? '1–20 sets'
                                                    : null;
                                              })),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          flex: 2,
                                          child: TextFormField(
                                              initialValue: exercises[i]
                                                  ['reps'],
                                              decoration: const InputDecoration(
                                                  labelText: 'Reps or time'),
                                              onChanged: (s) =>
                                                  exercises[i]['reps'] = s,
                                              validator: (s) =>
                                                  (s ?? '').trim().isEmpty
                                                      ? 'Enter reps or time'
                                                      : null))
                                    ]),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                        initialValue: exercises[i]['load'],
                                        decoration: const InputDecoration(
                                            labelText:
                                                'Weight / intensity (include units)'),
                                        onChanged: (s) =>
                                            exercises[i]['load'] = s),
                                  ])),
                            OutlinedButton.icon(
                                onPressed: exercises.length >= 20
                                    ? null
                                    : () => setState(() => exercises.add({
                                          'name': '',
                                          'sets': 3,
                                          'reps': '10',
                                          'load': 'Bodyweight'
                                        })),
                                icon: const Icon(Icons.add),
                                label: const Text('Add exercise')),
                          ])))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (!form.currentState!.validate()) return;
                  // Editing a routine preserves completed checkmarks only for unchanged exercise layouts.
                  final old = widget.existing;
                  final same = old != null &&
                      jsonEncode(old['exercises']) == jsonEncode(exercises);
                  Navigator.pop(context, {
                    'id': old?['id'] ??
                        DateTime.now().microsecondsSinceEpoch.toString(),
                    'title': title.text.trim(),
                    'minutes': int.parse(minutes.text),
                    'date': dayKey(date),
                    'exercises': exercises,
                    'done': same ? old['done'] ?? false : false,
                    'checked': same ? old['checked'] ?? [] : [],
                    'notes': old?['notes'] ?? ''
                  });
                },
                child: const Text('Save workout'))
          ]);
}

class WorkoutSession extends StatefulWidget {
  final Map<String, dynamic> workout;
  const WorkoutSession({super.key, required this.workout});
  @override
  State<WorkoutSession> createState() => _WorkoutSessionState();
}

class _WorkoutSessionState extends State<WorkoutSession> {
  late List<String> checked;
  late TextEditingController notes;
  Timer? timer;
  int remaining = 60;
  bool running = false;
  @override
  void initState() {
    super.initState();
    checked = List<String>.from(widget.workout['checked'] ?? []);
    notes = TextEditingController(text: widget.workout['notes'] ?? '');
  }

  @override
  void dispose() {
    timer?.cancel();
    notes.dispose();
    super.dispose();
  }

  void timerToggle() {
    if (running) {
      timer?.cancel();
      setState(() => running = false);
      return;
    }
    if (remaining == 0) remaining = 60;
    setState(() => running = true);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => remaining--);
      if (remaining <= 0) {
        timer?.cancel();
        setState(() => running = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final exercises =
        List<Map<String, dynamic>>.from(widget.workout['exercises']);
    final all =
        exercises.fold<int>(0, (s, e) => s + (e['sets'] as num).toInt());
    return AlertDialog(
        title: Text(widget.workout['title']),
        content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('${checked.length} of $all sets logged',
                      style: const TextStyle(
                          color: green, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 18),
                  for (int i = 0; i < exercises.length; i++)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(exercises[i]['name'],
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text(
                                  '${exercises[i]['reps']} · ${exercises[i]['load']}',
                                  style: const TextStyle(
                                      color: muted, fontSize: 14)),
                              const SizedBox(height: 10),
                              Wrap(
                                  spacing: 8,
                                  children: List.generate(
                                      (exercises[i]['sets'] as num).toInt(),
                                      (j) {
                                    final key = '$i:$j';
                                    return FilterChip(
                                        label: Text('Set ${j + 1}'),
                                        selected: checked.contains(key),
                                        onSelected: (v) => setState(() => v
                                            ? checked.add(key)
                                            : checked.remove(key)));
                                  })),
                            ])),
                  Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: bg, borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        const Icon(Icons.timer_outlined, color: green),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Rest timer · ${remaining}s')),
                        IconButton(
                            tooltip: running ? 'Pause timer' : 'Start timer',
                            onPressed: timerToggle,
                            icon:
                                Icon(running ? Icons.pause : Icons.play_arrow)),
                        IconButton(
                            tooltip: 'Reset timer',
                            onPressed: () {
                              timer?.cancel();
                              setState(() {
                                remaining = 60;
                                running = false;
                              });
                            },
                            icon: const Icon(Icons.refresh))
                      ])),
                  const SizedBox(height: 18),
                  TextField(
                      controller: notes,
                      maxLines: 2,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                          labelText: 'Session notes',
                          hintText: 'How did it feel?')),
                ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, {
                    ...widget.workout,
                    'checked': checked,
                    'notes': notes.text,
                    'done': false
                  }),
              child: const Text('Save progress')),
          FilledButton(
              onPressed: checked.length != all
                  ? null
                  : () => Navigator.pop(context, {
                        ...widget.workout,
                        'checked': checked,
                        'notes': notes.text,
                        'done': true
                      }),
              child: const Text('Complete workout')),
        ]);
  }
}

class WeightDialog extends StatefulWidget {
  final DateTime initialDate;
  const WeightDialog({super.key, required this.initialDate});
  @override
  State<WeightDialog> createState() => _WeightDialogState();
}

class _WeightDialogState extends State<WeightDialog> {
  late DateTime date;
  final value = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    date = widget.initialDate;
  }

  @override
  void dispose() {
    value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Log your weight'),
          content: Form(
              key: form,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                    controller: value,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Weight (kg)'),
                    validator: (s) {
                      final n = double.tryParse(s ?? '');
                      return n == null || !n.isFinite || n < 20 || n > 500
                          ? 'Enter a value from 20–500 kg'
                          : null;
                    }),
                const SizedBox(height: 16),
                TextButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now());
                      if (d != null) setState(() => date = d);
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(dayKey(date))),
                const Text(
                    'A new entry replaces any weight recorded for this date.',
                    style: TextStyle(fontSize: 12, color: muted)),
              ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (form.currentState!.validate())
                    Navigator.pop(context,
                        {'date': dayKey(date), 'kg': double.parse(value.text)});
                },
                child: const Text('Save weight'))
          ]);
}
