import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:image_picker/image_picker.dart';
import 'backend.dart';

part 'planning.dart';
part 'account.dart';

const green = Color(0xFF24734F);
const ink = Color(0xFF20392E);
const muted = Color(0xFF77847D);
const line = Color(0xFFE6ECE8);
const bg = Color(0xFFF6F8F7);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  await NourishBackend.initialize();
  runApp(const NourishApp());
}

class NourishApp extends StatelessWidget {
  const NourishApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Nourish',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Arial',
          scaffoldBackgroundColor: bg,
          colorScheme: ColorScheme.fromSeed(
            seedColor: green,
            primary: green,
            surface: Colors.white,
          ),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(fontSize: 15, color: ink),
            bodyLarge: TextStyle(fontSize: 16, color: ink),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: bg,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: line),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        home: const AccountGate(),
      );
}

class Food {
  final String name, cuisine, image, desc;
  final int kcal, p, c, f, minutes;
  final bool veg;
  const Food(
    this.name,
    this.cuisine,
    this.image,
    this.kcal,
    this.p,
    this.c,
    this.f,
    this.minutes,
    this.veg,
    this.desc,
  );
  Map<String, dynamic> entry(String group, double servings, String date) => {
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'name': name,
        'cuisine': cuisine,
        'image': image,
        'kcal': (kcal * servings).round(),
        'p': (p * servings).round(),
        'c': (c * servings).round(),
        'f': (f * servings).round(),
        'servings': servings,
        'group': group,
        'date': date,
      };
}

const foods = [
  Food(
    'Chickpea & avocado bowl',
    'Italian',
    'mediterranean-salad.jpg',
    420,
    18,
    46,
    18,
    15,
    true,
    'Chickpeas, avocado, tomatoes and greens with a lemon dressing.',
  ),
  Food(
    'Homestyle dal & rice',
    'Indian',
    'indian-curry.jpg',
    510,
    22,
    78,
    12,
    25,
    true,
    'Comforting lentils, steamed rice and seasonal vegetables.',
  ),
  Food(
    'Teriyaki salmon bowl',
    'Japanese',
    'japanese-salmon.jpg',
    580,
    38,
    62,
    20,
    25,
    false,
    'Salmon, rice and crisp vegetables with a teriyaki glaze.',
  ),
  Food(
    'Paneer & vegetable bowl',
    'Indian',
    'indian-curry.jpg',
    480,
    28,
    32,
    27,
    20,
    true,
    'Paneer, peppers and a gently spiced tomato sauce.',
  ),
  Food(
    'Garden grain bowl',
    'American',
    'mediterranean-salad.jpg',
    390,
    16,
    52,
    14,
    15,
    true,
    'Whole grains, chickpeas and crunchy vegetables.',
  ),
  Food(
    'Miso tofu rice bowl',
    'Japanese',
    'mediterranean-salad.jpg',
    440,
    24,
    55,
    14,
    20,
    true,
    'Tofu, rice and greens with a light miso dressing.',
  ),
  Food(
    'Tomato & chickpea salad',
    'Italian',
    'mediterranean-salad.jpg',
    340,
    16,
    36,
    16,
    10,
    true,
    'A simple salad with chickpeas, herbs and olive oil.',
  ),
  Food(
    'Grilled salmon plate',
    'American',
    'japanese-salmon.jpg',
    540,
    40,
    38,
    24,
    30,
    false,
    'Grilled salmon with grains and seasonal vegetables.',
  ),
];
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int page = 0;
  int? tourStep;
  String cuisine = 'All cuisines';
  DateTime date = DateTime.now();
  bool loading = true, saving = false;
  String? error;
  Map<String, dynamic> profile = {
    'name': 'Srija',
    'goal': 'Feel balanced',
    'diet': 'Everything',
    'cuisines': ['Indian', 'Italian', 'Japanese', 'American'],
    'calories': 2000,
    'protein': 100,
    'carbs': 250,
    'fat': 67,
    'done': false,
  };
  List<Map<String, dynamic>> meals = [];
  List<String> saved = [];
  List<Map<String, dynamic>> get today =>
      meals.where((m) => m['date'] == dayKey(date)).toList();
  int total(String key) => today.fold(0, (a, m) => a + (m[key] as num).round());
  List<Food> get suggestions {
    final selected = List<String>.from(profile['cuisines'] ?? []);
    var list = foods
        .where(
          (f) =>
              (profile['diet'] != 'Vegetarian' || f.veg) &&
              (cuisine == 'All cuisines' || f.cuisine == cuisine),
        )
        .toList();
    list.sort((a, b) {
      int score(Food f) =>
          (selected.contains(f.cuisine) ? 10 : 0) +
          (profile['goal'] == 'More protein' ? f.p : 0);
      return score(b).compareTo(score(a));
    });
    return list;
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final loaded = await NourishBackend.load();
      if (loaded != null) {
        final s = loaded;
        profile = {
          ...profile,
          ...Map<String, dynamic>.from(s['profile'] ?? {}),
        };
        meals = List<Map<String, dynamic>>.from(
          (s['meals'] ?? []).map((m) => Map<String, dynamic>.from(m)),
        );
        saved = List<String>.from(s['saved'] ?? []);
        plans = List<Map<String, dynamic>>.from(
            (s['plans'] ?? []).map((x) => Map<String, dynamic>.from(x)));
        workouts = List<Map<String, dynamic>>.from(
            (s['workouts'] ?? []).map((x) => Map<String, dynamic>.from(x)));
        weights = List<Map<String, dynamic>>.from(
            (s['weights'] ?? []).map((x) => Map<String, dynamic>.from(x)));
        water = Map<String, dynamic>.from(s['water'] ?? {});
        groceriesChecked = List<String>.from(s['groceriesChecked'] ?? []);
      }
    } catch (_) {
      error = 'Could not load your diary. Please retry before making changes.';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _saveQueue = Future.value();
  int pendingSaves = 0;
  Future<bool> persist() {
    final snapshot = Map<String, dynamic>.from(jsonDecode(jsonEncode({
      'profile': profile,
      'meals': meals,
      'saved': saved,
      'plans': plans,
      'workouts': workouts,
      'weights': weights,
      'water': water,
      'groceriesChecked': groceriesChecked
    })));
    final result = Completer<bool>();
    setState(() {
      pendingSaves++;
      saving = true;
    });
    _saveQueue = _saveQueue.then((_) async {
      bool success = false;
      try {
        await NourishBackend.save(snapshot);
        success = true;
        if (mounted) setState(() => error = null);
      } catch (_) {
        if (mounted)
          setState(() => error =
              'Your changes have not been saved. Keep this page open and retry.');
      } finally {
        if (mounted)
          setState(() {
            pendingSaves--;
            saving = pendingSaves > 0;
          });
        result.complete(success);
      }
    });
    return result.future;
  }

  void toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  static const tourSteps = <Map<String, dynamic>>[
    {
      'page': 0,
      'title': 'Start with today',
      'body':
          'See calories, macros, water and today’s meals together. The shortcuts below make the main actions one tap away.'
    },
    {
      'page': 1,
      'title': 'Log food your way',
      'body':
          'Search the sample catalog, enter a custom meal, or try the photo-review demo. Portions remain editable before saving.'
    },
    {
      'page': 4,
      'title': 'Build the week',
      'body':
          'Schedule meals, log a planned dish to the diary, and turn the plan into a grocery checklist.'
    },
    {
      'page': 5,
      'title': 'Make movement practical',
      'body':
          'Create a routine, schedule it, check off every set and use the built-in rest timer during a session.'
    },
    {
      'page': 6,
      'title': 'See the pattern',
      'body':
          'Review seven-day nutrition, completed workouts and weight entries. This is where daily actions become visible progress.'
    },
  ];

  void startTour() => setState(() {
        tourStep = 0;
        page = 0;
        date = DateTime.now();
      });

  void moveTour(int direction) {
    final next = (tourStep ?? 0) + direction;
    if (next >= tourSteps.length) {
      setState(() => tourStep = null);
      toast('Tour complete — the demo is yours to explore');
      return;
    }
    setState(() {
      tourStep = next.clamp(0, tourSteps.length - 1);
      page = tourSteps[tourStep!]['page'] as int;
    });
  }

  Future<void> add(Map<String, dynamic> meal) async {
    setState(() => meals.add(meal));
    if (await persist()) toast('Meal added to your diary');
  }

  Widget txt(
    String s, {
    double size = 16,
    Color color = ink,
    FontWeight weight = FontWeight.normal,
  }) =>
      Text(
        s,
        style: TextStyle(fontSize: size, color: color, fontWeight: weight),
      );
  Widget photo(String path, {double? height, double? width}) => Image.asset(
        'assets/images/$path',
        height: height,
        width: width,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: height,
          width: width,
          color: const Color(0xFFE5EEE8),
          child: const Icon(Icons.restaurant, color: green, size: 32),
        ),
      );
  Widget panel(
    Widget child, {
    EdgeInsets? padding,
    Color color = Colors.white,
  }) =>
      Container(
        padding: padding ?? const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: line),
        ),
        child: child,
      );
  Widget section(String title, {Widget? action}) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          children: [
            Expanded(child: txt(title, size: 20, weight: FontWeight.w700)),
            if (action != null) action,
          ],
        ),
      );
  Widget tag(String s, {Color color = green}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(7),
        ),
        child: txt(s, size: 12, color: color, weight: FontWeight.w600),
      );
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return Scaffold(
      body: Row(
        children: [
          if (wide) side(),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 82,
                  padding: EdgeInsets.symmetric(horizontal: wide ? 36 : 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: line)),
                  ),
                  child: Row(
                    children: [
                      if (!wide) ...[
                        const Icon(Icons.spa_rounded, color: green),
                        const SizedBox(width: 8),
                        txt('nourish', size: 25, weight: FontWeight.w800),
                        const Spacer(),
                      ] else ...[
                        txt(
                          pageNames[page],
                          weight: FontWeight.w600,
                        ),
                        const Spacer(),
                      ],
                      tag('PROTOTYPE'),
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: () => setState(() => page = 3),
                        borderRadius: BorderRadius.circular(30),
                        child: CircleAvatar(
                          backgroundColor: const Color(0xFFE7EEE8),
                          child: txt(
                            (profile['name'] as String).isEmpty
                                ? 'S'
                                : profile['name'][0],
                            weight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: EdgeInsets.all(wide ? 36 : 20),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1250),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (NourishBackend.demo)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 24),
                                      child: panel(LayoutBuilder(
                                              builder: (context, box) {
                                        final compact = box.maxWidth < 650;
                                        final message = Row(children: [
                                          const Icon(Icons.play_circle_outline,
                                              color: green),
                                          const SizedBox(width: 12),
                                          Expanded(
                                              child: txt(
                                            'Interactive demo · Sample data. Changes stay in this browser. Photo AI is simulated.',
                                            size: 13,
                                          )),
                                        ]);
                                        final actions = Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            FilledButton.tonalIcon(
                                              onPressed: startTour,
                                              icon: const Icon(
                                                  Icons.assistant_navigation,
                                                  size: 18),
                                              label: const Text('Guided tour'),
                                            ),
                                            TextButton(
                                              onPressed: saving
                                                  ? null
                                                  : () async {
                                                      try {
                                                        await NourishBackend
                                                            .resetDemo();
                                                        setState(() {
                                                          loading = true;
                                                          error = null;
                                                          tourStep = null;
                                                          date = DateTime.now();
                                                        });
                                                        await load();
                                                        toast(
                                                            'Sample day restored');
                                                      } catch (_) {
                                                        toast(
                                                            'Could not reset the demo. Please retry.');
                                                      }
                                                    },
                                              child: const Text('Reset demo'),
                                            ),
                                          ],
                                        );
                                        return compact
                                            ? Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                    message,
                                                    const SizedBox(height: 12),
                                                    actions,
                                                  ])
                                            : Row(children: [
                                                Expanded(child: message),
                                                actions
                                              ]);
                                      }),
                                          padding: const EdgeInsets.all(16),
                                          color: const Color(0xFFEAF3EC)),
                                    ),
                                  if (tourStep != null) tourCoach(),
                                  if (error != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 20,
                                      ),
                                      child: panel(
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.info_outline,
                                              color: Colors.orange,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: txt(error!, size: 14),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  error!.startsWith('Could')
                                                      ? load()
                                                      : persist(),
                                              child: const Text('Retry'),
                                            ),
                                          ],
                                        ),
                                        color: const Color(0xFFFFF7E7),
                                      ),
                                    ),
                                  if (page == 0) dashboard(wide),
                                  if (page == 1) diaryPage(),
                                  if (page == 2) discover(),
                                  if (page == 3) ...[
                                    panel(Row(children: [
                                      const Icon(Icons.cloud_outlined,
                                          color: green),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: txt(
                                              NourishBackend.connected
                                                  ? 'Account sync is connected'
                                                  : NourishBackend.demo
                                                      ? 'Demo mode · Saved in this browser only'
                                                      : 'Private preview · Account sync is not connected',
                                              size: 14)),
                                      if (NourishBackend.connected)
                                        TextButton(
                                            onPressed: () => NourishBackend
                                                .client!.auth
                                                .signOut(),
                                            child: const Text('Sign out'))
                                    ])),
                                    const SizedBox(height: 22),
                                    preferences()
                                  ],
                                  if (page == 4) plannerPage(),
                                  if (page == 5) workoutsPage(),
                                  if (page == 6) progressPage(),
                                  if (page == 7) morePage(),
                                  const SizedBox(height: 30),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.lock_outline,
                                        size: 14,
                                        color: muted,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: txt(
                                          NourishBackend.demo
                                              ? 'Demo prototype · Sample nutrition values · Photos are illustrative'
                                              : 'Private prototype · Sample nutrition values · Photos are illustrative',
                                          size: 12,
                                          color: muted,
                                        ),
                                      ),
                                      if (saving)
                                        txt('Saving…', size: 12, color: green),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex:
                  [0, 1, 4, 5].contains(page) ? [0, 1, 4, 5].indexOf(page) : 4,
              onDestinationSelected: (i) =>
                  setState(() => page = [0, 1, 4, 5, 7][i]),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  label: 'Today',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  label: 'Diary',
                ),
                NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined), label: 'Meals'),
                NavigationDestination(
                    icon: Icon(Icons.fitness_center), label: 'Train'),
                NavigationDestination(
                    icon: Icon(Icons.more_horiz), label: 'More'),
              ],
            ),
    );
  }

  Widget side() => Container(
      width: 232,
      decoration: const BoxDecoration(
          color: Colors.white, border: Border(right: BorderSide(color: line))),
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
            child: Row(children: [
              const Icon(Icons.spa_rounded, color: green, size: 32),
              const SizedBox(width: 10),
              txt('nourish', size: 29, weight: FontWeight.w800)
            ])),
        const SizedBox(height: 30),
        txt('YOUR EVERYDAY', size: 11, color: muted, weight: FontWeight.w700),
        const SizedBox(height: 16),
        Expanded(
            child: ListView(children: [
          for (final i in [0, 1, 2, 4, 5, 6, 3])
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                    color: page == i
                        ? const Color(0xFFEAF3ED)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: ListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        leading: Icon(
                            [
                              Icons.space_dashboard_outlined,
                              Icons.menu_book_outlined,
                              Icons.explore_outlined,
                              Icons.tune,
                              Icons.calendar_month_outlined,
                              Icons.fitness_center,
                              Icons.insights_outlined
                            ][i],
                            color: page == i ? green : muted,
                            size: 22),
                        title: txt(pageNames[i],
                            size: 14,
                            color: page == i ? green : muted,
                            weight:
                                page == i ? FontWeight.bold : FontWeight.w500),
                        onTap: () => setState(() => page = i))))
        ])),
        panel(
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.favorite_border, color: green),
              const SizedBox(height: 12),
              txt('Eat well. Move your way.',
                  size: 17, weight: FontWeight.w600),
              const SizedBox(height: 8),
              txt('One everyday habit at a time.', size: 13, color: muted)
            ]),
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFF2F6EF)),
      ]));
  Widget dashboard(bool wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 18,
          spacing: 40,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                txt(
                  'A LITTLE BETTER, EVERY DAY',
                  size: 11,
                  color: green,
                  weight: FontWeight.w700,
                ),
                const SizedBox(height: 10),
                txt(
                  'Your day, nourished.',
                  size: wide ? 36 : 29,
                  weight: FontWeight.w700,
                ),
                const SizedBox(height: 9),
                txt(
                  'Hi ${profile['name']}. Let’s make room for feeling good.',
                  color: muted,
                ),
              ],
            ),
            dateControl(),
          ],
        ),
        const SizedBox(height: 24),
        quickActions(),
        const SizedBox(height: 20),
        dailyExtras(),
        if (profile['done'] != true)
          Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: panel(
              Row(
                children: [
                  const Icon(Icons.favorite_border, color: green),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        txt('Make this feel like you', weight: FontWeight.w600),
                        txt(
                          'Choose your cuisines, preferences and daily goals.',
                          size: 14,
                          color: muted,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => page = 3),
                    child: const Text('Personalize'),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              color: const Color(0xFFF0F6F1),
            ),
          ),
        LayoutBuilder(
          builder: (context, box) {
            final desktop = box.maxWidth >= 750;
            return Flex(
              direction: desktop ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (desktop) Expanded(flex: 6, child: summary()) else summary(),
                SizedBox(width: desktop ? 20 : 0, height: desktop ? 0 : 18),
                if (desktop)
                  Expanded(flex: 5, child: scanCard())
                else
                  scanCard(),
              ],
            );
          },
        ),
        const SizedBox(height: 30),
        LayoutBuilder(
          builder: (context, box) {
            final desktop = box.maxWidth >= 900;
            return Flex(
              direction: desktop ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (desktop)
                  Expanded(flex: 7, child: mealPanel())
                else
                  mealPanel(),
                SizedBox(width: desktop ? 24 : 0, height: desktop ? 0 : 24),
                if (desktop) Expanded(flex: 4, child: insight()) else insight(),
              ],
            );
          },
        ),
        const SizedBox(height: 32),
        section(
          'A little inspiration for your next meal',
          action: TextButton(
            onPressed: () => setState(() => page = 2),
            child: const Text('Explore meals →'),
          ),
        ),
        foodGrid(suggestions.take(3).toList()),
      ],
    );
  }

  Widget tourCoach() {
    final step = tourSteps[tourStep!];
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: panel(
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: Column(
            key: ValueKey(tourStep),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                tag('STEP ${tourStep! + 1} OF ${tourSteps.length}'),
                const Spacer(),
                IconButton(
                  tooltip: 'Close guided tour',
                  onPressed: () => setState(() => tourStep = null),
                  icon: const Icon(Icons.close, size: 19),
                ),
              ]),
              const SizedBox(height: 10),
              txt(step['title'] as String, size: 22, weight: FontWeight.w700),
              const SizedBox(height: 7),
              txt(step['body'] as String, size: 14, color: muted),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (tourStep! + 1) / tourSteps.length,
                      minHeight: 7,
                      color: green,
                      backgroundColor: const Color(0xFFDDE8E0),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                if (tourStep! > 0)
                  TextButton(
                    onPressed: () => moveTour(-1),
                    child: const Text('Back'),
                  ),
                FilledButton.icon(
                  onPressed: () => moveTour(1),
                  icon: Icon(tourStep == tourSteps.length - 1
                      ? Icons.check
                      : Icons.arrow_forward),
                  label: Text(
                      tourStep == tourSteps.length - 1 ? 'Finish' : 'Next'),
                ),
              ]),
            ],
          ),
        ),
        color: const Color(0xFFFFFBEE),
      ),
    );
  }

  Widget quickActions() => LayoutBuilder(builder: (context, box) {
        final columns = box.maxWidth >= 850
            ? 4
            : box.maxWidth >= 480
                ? 2
                : 1;
        final width = (box.maxWidth - (columns - 1) * 12) / columns;
        Widget action(
                String label, String helper, IconData icon, VoidCallback tap) =>
            SizedBox(
              width: width,
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: line),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: tap,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF3ED),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(icon, color: green, size: 21),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          txt(label, size: 14, weight: FontWeight.w700),
                          const SizedBox(height: 3),
                          txt(helper, size: 11, color: muted),
                        ],
                      )),
                      const Icon(Icons.chevron_right, color: muted, size: 18),
                    ]),
                  ),
                ),
              ),
            );
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            action('Log food', 'Search or enter', Icons.add_circle_outline,
                () => showAdd()),
            action('Scan meal', 'Photo demo', Icons.center_focus_strong,
                () => showAdd(photoMode: true)),
            action('Plan meal', 'Build your week',
                Icons.calendar_month_outlined, () => scheduleMeal()),
            action('Start workout', 'Open today’s plan', Icons.fitness_center,
                () => setState(() => page = 5)),
          ],
        );
      });

  Widget dateControl() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Previous day',
              onPressed: () =>
                  setState(() => date = date.subtract(const Duration(days: 1))),
              icon: const Icon(Icons.chevron_left, size: 18),
            ),
            const Icon(Icons.calendar_today_outlined, size: 16, color: muted),
            const SizedBox(width: 10),
            txt(
              dayKey(date) == dayKey(DateTime.now())
                  ? 'Today, ${[
                      'Jan',
                      'Feb',
                      'Mar',
                      'Apr',
                      'May',
                      'Jun',
                      'Jul',
                      'Aug',
                      'Sep',
                      'Oct',
                      'Nov',
                      'Dec'
                    ][date.month - 1]} ${date.day}'
                  : '${date.month}/${date.day}/${date.year}',
              size: 14,
            ),
            IconButton(
              tooltip: 'Next day',
              onPressed: dayKey(date) == dayKey(DateTime.now())
                  ? null
                  : () =>
                      setState(() => date = date.add(const Duration(days: 1))),
              icon: const Icon(Icons.chevron_right, size: 18),
            ),
          ],
        ),
      );
  Widget summary() {
    final goal = (profile['calories'] as num).toInt();
    final eaten = total('kcal');
    final remain = goal - eaten;
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              txt('Daily nutrition', size: 17, weight: FontWeight.w600),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => page = 3),
                child: const Text('Edit goals'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 145,
                height: 145,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: (eaten / goal).clamp(0, 1)),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => SizedBox(
                        width: 137,
                        height: 137,
                        child: CircularProgressIndicator(
                          value: value,
                          strokeWidth: 11,
                          backgroundColor: const Color(0xFFEDF2EE),
                          color: green,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        txt(
                          remain.abs().toString(),
                          size: 33,
                          weight: FontWeight.w700,
                        ),
                        txt(
                          remain >= 0 ? 'kcal remaining' : 'kcal over goal',
                          size: 12,
                          color: muted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    txt(
                      'EATEN',
                      size: 11,
                      color: muted,
                      weight: FontWeight.w700,
                    ),
                    const SizedBox(height: 5),
                    txt('$eaten kcal', size: 23, weight: FontWeight.w600),
                    const SizedBox(height: 20),
                    txt(
                      'DAILY GOAL',
                      size: 11,
                      color: muted,
                      weight: FontWeight.w700,
                    ),
                    const SizedBox(height: 5),
                    txt('$goal kcal', size: 19),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              macro('Protein', 'p', 'protein', const Color(0xFF7D9CDE)),
              const SizedBox(width: 18),
              macro('Carbs', 'c', 'carbs', const Color(0xFFE4AE67)),
              const SizedBox(width: 18),
              macro('Fat', 'f', 'fat', const Color(0xFFA78CC1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget macro(String title, String key, String goal, Color color) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            txt(title, size: 13, color: muted),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${total(key)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ink,
                      fontSize: 16,
                    ),
                  ),
                  TextSpan(
                    text: ' / ${profile[goal]} g',
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (total(key) / (profile[goal] as num)).clamp(0, 1),
                minHeight: 5,
                color: color,
                backgroundColor: color.withValues(alpha: .13),
              ),
            ),
          ],
        ),
      );
  Widget scanCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: const Color(0xFFE9F2EB),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.center_focus_strong,
                    color: green,
                    size: 26,
                  ),
                ),
                const Spacer(),
                tag('PHOTO DEMO'),
              ],
            ),
            const SizedBox(height: 22),
            txt(
              'A photo. A simpler food diary.',
              size: 25,
              weight: FontWeight.w700,
            ),
            const SizedBox(height: 10),
            txt(
              'Try the photo-to-meal flow, then make it yours with a quick portion check.',
              size: 14,
              color: const Color(0xFF587561),
            ),
            const SizedBox(height: 23),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => showAdd(photoMode: true),
                icon: const Icon(Icons.camera_alt_outlined, size: 19),
                label: const Text('Try meal scan'),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: txt(
                'Demo results · No live AI analysis',
                size: 12,
                color: const Color(0xFF587561),
              ),
            ),
          ],
        ),
      );
  Widget mealPanel() => panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            section(
              'Your meals',
              action: TextButton.icon(
                onPressed: () => showAdd(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add food'),
              ),
            ),
            if (today.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.restaurant_outlined,
                          size: 38, color: muted),
                      const SizedBox(height: 12),
                      txt('A fresh page for your day', weight: FontWeight.w600),
                      const SizedBox(height: 6),
                      txt(
                        'Log your first meal whenever you’re ready.',
                        size: 14,
                        color: muted,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...today.take(4).map((m) => mealRow(m)),
            const Divider(color: line, height: 24),
            Row(
              children: [
                txt('${today.length} meals logged', size: 13, color: muted),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => page = 1),
                  child: const Text('View diary →'),
                ),
              ],
            ),
          ],
        ),
      );
  Widget mealRow(Map<String, dynamic> m) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: photo(
                m['image'] ?? 'mediterranean-salad.jpg',
                width: 52,
                height: 52,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  txt(m['name'], size: 14, weight: FontWeight.w600),
                  const SizedBox(height: 5),
                  txt(
                    '${m['group']} · ${m['servings']} serving(s)',
                    size: 12,
                    color: muted,
                  ),
                ],
              ),
            ),
            txt('${m['kcal']} kcal', size: 14, weight: FontWeight.w600),
            PopupMenuButton<String>(
              tooltip: 'Meal actions',
              onSelected: (v) {
                if (v == 'edit') {
                  showEdit(m);
                } else {
                  deleteMeal(m);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit meal')),
                PopupMenuItem(value: 'delete', child: Text('Delete meal')),
              ],
            ),
          ],
        ),
      );
  Widget insight() => panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_outlined, color: green, size: 19),
                const SizedBox(width: 8),
                txt('A little nudge', size: 16, weight: FontWeight.w600),
              ],
            ),
            const SizedBox(height: 20),
            txt(
              today.isEmpty
                  ? 'Start with what you love.'
                  : 'Make your next meal count.',
              size: 23,
              weight: FontWeight.w600,
            ),
            const SizedBox(height: 13),
            txt(
              today.isEmpty
                  ? 'Your usual breakfast is a great place to begin. There’s no perfect way to start—just your way.'
                  : 'You’ve logged ${total('p')} g of protein today. Explore a meal that matches your preferences.',
              size: 15,
              color: muted,
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 6,
              runSpacing: 8,
              children: List<String>.from(profile['cuisines'])
                  .take(3)
                  .map((c) => tag(c))
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => page = 2),
              child: const Text('Find my next meal →'),
            ),
          ],
        ),
        color: const Color(0xFFFAFBF8),
      );
  Widget foodGrid(List<Food> list) => LayoutBuilder(
        builder: (context, box) {
          final columns = box.maxWidth > 950
              ? 3
              : box.maxWidth > 600
                  ? 2
                  : 1;
          final width = (box.maxWidth - (columns - 1) * 18) / columns;
          return Wrap(
            spacing: 18,
            runSpacing: 18,
            children: list
                .map((f) => SizedBox(width: width, child: foodCard(f)))
                .toList(),
          );
        },
      );
  Widget foodCard(Food f) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: photo(f.image, height: 165, width: double.infinity),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: txt(f.cuisine, size: 12, weight: FontWeight.w600),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filledTonal(
                    tooltip:
                        saved.contains(f.name) ? 'Unsave meal' : 'Save meal',
                    style: IconButton.styleFrom(backgroundColor: Colors.white),
                    onPressed: () async {
                      setState(
                        () => saved.contains(f.name)
                            ? saved.remove(f.name)
                            : saved.add(f.name),
                      );
                      await persist();
                    },
                    icon: Icon(
                      saved.contains(f.name)
                          ? Icons.bookmark
                          : Icons.bookmark_outline,
                      size: 21,
                      color: green,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  txt(f.name, size: 17, weight: FontWeight.w600),
                  const SizedBox(height: 9),
                  txt(
                    '${f.kcal} kcal  ·  ${f.p} g protein  ·  ${f.minutes} min',
                    size: 12,
                    color: muted,
                  ),
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      Expanded(
                        child: txt(
                          f.veg ? 'Vegetarian' : 'Protein-rich',
                          size: 12,
                          color: green,
                        ),
                      ),
                      TextButton(
                        onPressed: () => showFood(f),
                        child: const Text('View meal →'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
  Widget diaryPage() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          section(
            'Your food diary',
            action: FilledButton.icon(
              onPressed: () => showAdd(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add meal'),
            ),
          ),
          txt('The everyday meals that add up to your day.', color: muted),
          const SizedBox(height: 22),
          dateControl(),
          const SizedBox(height: 24),
          for (final group in ['Breakfast', 'Lunch', 'Dinner', 'Snacks'])
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    section(
                      group,
                      action: TextButton.icon(
                        onPressed: () => showAdd(group: group),
                        icon: const Icon(Icons.add, size: 17),
                        label: const Text('Add'),
                      ),
                    ),
                    if (today.where((m) => m['group'] == group).isEmpty)
                      txt('Nothing logged yet.', size: 14, color: muted)
                    else
                      ...today.where((m) => m['group'] == group).map(mealRow),
                  ],
                ),
              ),
            ),
          panel(
            Row(
              children: [
                txt('Daily total', weight: FontWeight.w600),
                const Spacer(),
                txt(
                  '${total('kcal')} kcal · ${total('p')} g protein',
                  weight: FontWeight.w600,
                ),
              ],
            ),
          ),
        ],
      );
  bool savedOnly = false;
  Widget discover() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          txt('Good food. Your kind of good.',
              size: 32, weight: FontWeight.w700),
          const SizedBox(height: 10),
          txt(
            'Meal inspiration shaped by your cuisines and preferences.',
            color: muted,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in [
                'All cuisines',
                'Indian',
                'Italian',
                'Japanese',
                'American',
              ])
                ChoiceChip(
                  label: Text(c),
                  selected: cuisine == c,
                  onSelected: (_) => setState(() => cuisine = c),
                  selectedColor: const Color(0xFFDDEFE2),
                  side: const BorderSide(color: line),
                ),
              FilterChip(
                label: const Text('Saved meals'),
                avatar: const Icon(Icons.bookmark_outline, size: 17),
                selected: savedOnly,
                onSelected: (v) => setState(() => savedOnly = v),
              ),
            ],
          ),
          const SizedBox(height: 22),
          txt(
            profile['diet'] == 'Vegetarian'
                ? 'Showing vegetarian meals · Based on your preferences'
                : 'Based on your cuisine preferences · ${profile['goal']}',
            size: 13,
            color: green,
          ),
          const SizedBox(height: 20),
          if (suggestions
              .where((f) => !savedOnly || saved.contains(f.name))
              .isEmpty)
            panel(
              txt(
                'No saved meals here yet. Bookmark a meal to find it here.',
                color: muted,
              ),
            )
          else
            foodGrid(
              suggestions
                  .where((f) => !savedOnly || saved.contains(f.name))
                  .toList(),
            ),
        ],
      );
  List<Map<String, dynamic>> plans = [], workouts = [], weights = [];
  Map<String, dynamic> water = {};
  List<String> groceriesChecked = [];
  DateTime week =
      DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  static const pageNames = [
    'Overview',
    'Food diary',
    'Discover meals',
    'Preferences',
    'Meal planner',
    'Workouts',
    'Progress',
    'More'
  ];
  int get waterToday => (water[dayKey(date)] as num? ?? 0).round();
  List<DateTime> get weekDays =>
      List.generate(7, (i) => DateTime(week.year, week.month, week.day + i));
  String shortDate(DateTime d) => '${[
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun'
      ][d.weekday - 1]}, ${d.month}/${d.day}';
  Widget weekControl() => Row(children: [
        IconButton(
            tooltip: 'Previous week',
            onPressed: () =>
                setState(() => week = week.subtract(const Duration(days: 7))),
            icon: const Icon(Icons.chevron_left)),
        Expanded(
            child: Center(
                child: txt(
                    '${shortDate(weekDays.first)} – ${shortDate(weekDays.last)}',
                    size: 16,
                    weight: FontWeight.w600))),
        IconButton(
            tooltip: 'Next week',
            onPressed: () =>
                setState(() => week = week.add(const Duration(days: 7))),
            icon: const Icon(Icons.chevron_right)),
      ]);
  Widget morePage() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        section('Make it yours'),
        for (final i in [2, 6, 3])
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: panel(ListTile(
                  title: Text(pageNames[i]),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => setState(() => page = i)))),
      ]);
  Widget dailyExtras() => Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: LayoutBuilder(builder: (context, box) {
        final width =
            box.maxWidth >= 750 ? (box.maxWidth - 16) / 2 : box.maxWidth;
        return Wrap(spacing: 16, runSpacing: 16, children: [
          SizedBox(
              width: width,
              child: panel(
                  Row(children: [
                    const Icon(Icons.water_drop_outlined,
                        color: Color(0xFF4F8CA7), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          txt('Water today', size: 14, color: muted),
                          const SizedBox(height: 5),
                          txt('$waterToday ml',
                              size: 23, weight: FontWeight.w600)
                        ])),
                    IconButton(
                        tooltip: 'Remove 250 ml',
                        onPressed: waterToday == 0
                            ? null
                            : () async {
                                setState(() => water[dayKey(date)] =
                                    (waterToday - 250).clamp(0, 20000));
                                await persist();
                              },
                        icon: const Icon(Icons.remove_circle_outline)),
                    FilledButton.tonal(
                        onPressed: waterToday >= 20000
                            ? null
                            : () async {
                                setState(() =>
                                    water[dayKey(date)] = waterToday + 250);
                                await persist();
                              },
                        child: const Text('+ 250 ml')),
                  ]),
                  padding: const EdgeInsets.all(18))),
          SizedBox(
              width: width,
              child: panel(
                  Row(children: [
                    const Icon(Icons.fitness_center, color: green, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          txt('Move your way', size: 14, color: muted),
                          const SizedBox(height: 5),
                          txt('${workouts.where((w) => w['date'] == dayKey(date) && w['done'] == true).length} sessions completed',
                              size: 18, weight: FontWeight.w600)
                        ])),
                    TextButton(
                        onPressed: () => setState(() => page = 5),
                        child: const Text('Plan →')),
                  ]),
                  padding: const EdgeInsets.all(18))),
        ]);
      }));
  Future<void> scheduleMeal(
      {DateTime? selectedDate, Food? selectedFood}) async {
    final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => PlanMealDialog(
            initialDate: selectedDate ?? date,
            initialFood: selectedFood,
            diet: profile['diet']));
    if (result != null) {
      setState(() => plans.add(result));
      if (await persist()) toast('Meal added to your plan');
    }
  }

  Widget plannerPage() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        section('A good week starts with a plan.',
            action: FilledButton.icon(
                onPressed: () => scheduleMeal(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Plan meal'))),
        txt('Choose meals you look forward to. Your diary updates only when you log them.',
            color: muted),
        const SizedBox(height: 20),
        weekControl(),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, box) {
          final n = box.maxWidth > 1050
              ? 4
              : box.maxWidth > 650
                  ? 3
                  : box.maxWidth > 420
                      ? 2
                      : 1;
          final width = (box.maxWidth - (n - 1) * 14) / n;
          return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: weekDays.map((d) {
                final entries =
                    plans.where((p) => p['date'] == dayKey(d)).toList();
                return SizedBox(
                    width: width,
                    child: panel(
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                    child: txt(shortDate(d),
                                        size: 15, weight: FontWeight.w700)),
                                IconButton(
                                    tooltip: 'Plan a meal for ${shortDate(d)}',
                                    onPressed: () =>
                                        scheduleMeal(selectedDate: d),
                                    icon: const Icon(Icons.add, size: 19))
                              ]),
                              if (entries.isEmpty)
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 25),
                                    child: txt('Room for something good.',
                                        size: 14, color: muted)),
                              for (final p in entries)
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          tag(p['group']),
                                          const SizedBox(height: 8),
                                          txt(p['name'],
                                              size: 15,
                                              weight: FontWeight.w600),
                                          const SizedBox(height: 5),
                                          txt('${p['servings']} serving(s) · ${p['kcal']} kcal',
                                              size: 12, color: muted),
                                          Row(children: [
                                            TextButton(
                                                onPressed: p['logged'] == true
                                                    ? null
                                                    : () async {
                                                        final entry = {
                                                          ...p,
                                                          'id': DateTime.now()
                                                              .microsecondsSinceEpoch
                                                              .toString()
                                                        };
                                                        entry.remove('logged');
                                                        setState(() {
                                                          meals.add(entry);
                                                          p['logged'] = true;
                                                        });
                                                        if (await persist())
                                                          toast(
                                                              'Planned meal logged');
                                                      },
                                                child: Text(p['logged'] == true
                                                    ? 'Logged'
                                                    : 'Log meal')),
                                            const Spacer(),
                                            IconButton(
                                                tooltip: 'Remove planned meal',
                                                onPressed: () async {
                                                  setState(
                                                      () => plans.remove(p));
                                                  await persist();
                                                },
                                                icon: const Icon(Icons.close,
                                                    size: 17)),
                                          ]),
                                          const Divider(color: line),
                                        ])),
                            ]),
                        padding: const EdgeInsets.all(16)));
              }).toList());
        }),
        const SizedBox(height: 28),
        groceryPanel(),
      ]);
  Widget groceryPanel() {
    final active = plans
        .where((p) => weekDays.any((d) => p['date'] == dayKey(d)))
        .toList();
    final items = <String>{};
    for (final p in active) {
      items.addAll(recipeIngredients[p['name']] ?? [p['name'] as String]);
    }
    return panel(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      section('Your grocery checklist',
          action: tag('${items.length} ingredients')),
      txt('Ingredients from this week’s sample recipes. Check quantities and package labels before shopping.',
          size: 14, color: muted),
      const SizedBox(height: 16),
      if (items.isEmpty)
        txt('Plan a meal to start your checklist.', color: muted),
      Wrap(
          spacing: 18,
          runSpacing: 6,
          children: (items.toList()..sort())
              .map((item) => SizedBox(
                  width: 240,
                  child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(item, style: const TextStyle(fontSize: 14)),
                      value: groceriesChecked.contains(item),
                      onChanged: (v) async {
                        setState(() => v == true
                            ? groceriesChecked.add(item)
                            : groceriesChecked.remove(item));
                        await persist();
                      })))
              .toList()),
    ]));
  }

  Future<void> editWorkout(
      {Map<String, dynamic>? existing, Map<String, dynamic>? template}) async {
    final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => WorkoutEditor(
            existing: existing, template: template, initialDate: date));
    if (result != null) {
      setState(() {
        if (existing == null) {
          workouts.add(result);
        } else {
          workouts[workouts.indexWhere((w) => w['id'] == existing['id'])] =
              result;
        }
      });
      if (await persist()) toast('Workout plan saved');
    }
  }

  Future<void> logWorkout(Map<String, dynamic> workout) async {
    final result = await showDialog<Map<String, dynamic>>(
        context: context, builder: (ctx) => WorkoutSession(workout: workout));
    if (result != null) {
      setState(() =>
          workouts[workouts.indexWhere((w) => w['id'] == result['id'])] =
              result);
      if (await persist())
        toast(result['done'] == true
            ? 'Workout completed. Nice work!'
            : 'Workout progress saved');
    }
  }

  Widget workoutsPage() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        section('Make movement part of your week.',
            action: FilledButton.icon(
                onPressed: () => editWorkout(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create workout'))),
        txt('Schedule your sessions, adjust exercises, and log your sets.',
            color: muted),
        const SizedBox(height: 22),
        weekControl(),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, box) {
          final n = box.maxWidth >= 800
              ? 3
              : box.maxWidth >= 520
                  ? 2
                  : 1;
          final width = (box.maxWidth - (n - 1) * 16) / n;
          return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: weekDays.map((d) {
                final list =
                    workouts.where((w) => w['date'] == dayKey(d)).toList();
                return SizedBox(
                    width: width,
                    child: panel(
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                    child: txt(shortDate(d),
                                        size: 16, weight: FontWeight.w700)),
                                if (dayKey(d) == dayKey(DateTime.now()))
                                  tag('TODAY')
                              ]),
                              const SizedBox(height: 16),
                              if (list.isEmpty)
                                txt('Rest day or room to move.',
                                    size: 14, color: muted),
                              for (final w in list)
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            Icon(
                                                w['done'] == true
                                                    ? Icons.check_circle
                                                    : Icons.fitness_center,
                                                color: green,
                                                size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                                child: txt(w['title'],
                                                    size: 17,
                                                    weight: FontWeight.w600))
                                          ]),
                                          const SizedBox(height: 9),
                                          txt('${w['minutes']} min · ${(w['exercises'] as List).length} exercises',
                                              size: 13, color: muted),
                                          const SizedBox(height: 10),
                                          Wrap(spacing: 4, children: [
                                            FilledButton.tonal(
                                                onPressed: () => logWorkout(w),
                                                child: Text(w['done'] == true
                                                    ? 'Review session'
                                                    : 'Log session')),
                                            IconButton(
                                                tooltip: 'Edit workout',
                                                onPressed: () =>
                                                    editWorkout(existing: w),
                                                icon: const Icon(
                                                    Icons.edit_outlined,
                                                    size: 20)),
                                            IconButton(
                                                tooltip: 'Delete workout',
                                                onPressed: () =>
                                                    deleteWorkout(w),
                                                icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 20))
                                          ]),
                                        ])),
                            ]),
                        padding: const EdgeInsets.all(20)));
              }).toList());
        }),
        const SizedBox(height: 30),
        section('Start with a routine'),
        txt('Editable examples—not a personalized training prescription. Adjust them to your experience.',
            size: 14, color: muted),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, box) {
          final n = box.maxWidth > 800 ? 3 : 1;
          final width = (box.maxWidth - (n - 1) * 16) / n;
          return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: routines
                  .map((r) => SizedBox(
                      width: width,
                      child: panel(Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                                r['kind'] == 'Home'
                                    ? Icons.home_outlined
                                    : r['kind'] == 'Cardio'
                                        ? Icons.directions_walk
                                        : Icons.fitness_center,
                                color: green,
                                size: 30),
                            const SizedBox(height: 16),
                            tag(r['kind']),
                            const SizedBox(height: 14),
                            txt(r['title'], size: 21, weight: FontWeight.w700),
                            const SizedBox(height: 8),
                            txt('${r['minutes']} min · ${(r['exercises'] as List).length} exercises',
                                size: 14, color: muted),
                            const SizedBox(height: 15),
                            for (final e in (r['exercises'] as List))
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: txt('• ${e['name']}',
                                      size: 14, color: muted)),
                            const SizedBox(height: 18),
                            OutlinedButton(
                                onPressed: () => editWorkout(template: r),
                                child: const Text('Customize & schedule')),
                          ]))))
                  .toList());
        }),
      ]);
  Future<void> deleteWorkout(Map<String, dynamic> workout) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Remove this workout?'),
                content: Text(workout['title']),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Keep')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Remove'))
                ]));
    if (yes == true) {
      setState(() => workouts.removeWhere((w) => w['id'] == workout['id']));
      await persist();
    }
  }

  Future<void> logWeight() async {
    final result = await showDialog<Map<String, dynamic>>(
        context: context, builder: (ctx) => WeightDialog(initialDate: date));
    if (result != null) {
      setState(() {
        weights.removeWhere((w) => w['date'] == result['date']);
        weights.add(result);
      });
      if (await persist()) toast('Weight entry saved');
    }
  }

  Widget progressPage() {
    final days =
        List.generate(7, (i) => DateTime.now().subtract(Duration(days: 6 - i)));
    final loggedDays =
        days.where((d) => meals.any((m) => m['date'] == dayKey(d))).length;
    final sessions = workouts
        .where(
            (w) => w['done'] == true && days.any((d) => w['date'] == dayKey(d)))
        .length;
    final entries = [...weights]
      ..sort((a, b) => (a['date'] as String).compareTo(b['date']));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      section('See the habits taking shape.',
          action: FilledButton.icon(
              onPressed: logWeight,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Log weight'))),
      txt('Your last seven days, at a glance.', color: muted),
      const SizedBox(height: 24),
      Wrap(spacing: 16, runSpacing: 16, children: [
        statCard(
            'Days with meals', '$loggedDays / 7', Icons.restaurant_outlined),
        statCard('Workouts completed', '$sessions', Icons.fitness_center),
        statCard(
            'Latest weight',
            entries.isEmpty ? 'Not logged' : '${entries.last['kg']} kg',
            Icons.monitor_weight_outlined),
      ]),
      const SizedBox(height: 26),
      panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        section('Calories logged'),
        txt('Missing bars mean no food was logged, not zero food eaten.',
            size: 13, color: muted),
        const SizedBox(height: 22),
        SizedBox(
            height: 205,
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: days.map((d) {
                  final kcal = meals
                      .where((m) => m['date'] == dayKey(d))
                      .fold<int>(0, (v, m) => v + (m['kcal'] as num).round());
                  final maxValue = days
                      .map((x) => meals
                          .where((m) => m['date'] == dayKey(x))
                          .fold<int>(
                              0, (v, m) => v + (m['kcal'] as num).round()))
                      .fold<int>(profile['calories'], (a, b) => a > b ? a : b);
                  return Expanded(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                        txt(kcal == 0 ? '—' : '$kcal', size: 12, color: muted),
                        const SizedBox(height: 8),
                        Container(
                            width: 32,
                            height: kcal == 0 ? 3 : 140 * kcal / maxValue,
                            decoration: BoxDecoration(
                                color: kcal == 0 ? line : green,
                                borderRadius: BorderRadius.circular(7))),
                        const SizedBox(height: 12),
                        txt(['M', 'T', 'W', 'T', 'F', 'S', 'S'][d.weekday - 1],
                            size: 12, color: muted),
                      ]));
                }).toList())),
      ])),
      const SizedBox(height: 24),
      panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        section('Weight history'),
        if (entries.isEmpty)
          txt('Add your first entry when you’re ready.', color: muted),
        for (final w in entries.reversed.take(12))
          ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${w['kg']} kg'),
              subtitle: Text(w['date']),
              trailing: IconButton(
                  tooltip: 'Remove weight entry',
                  onPressed: () async {
                    setState(() =>
                        weights.removeWhere((x) => x['date'] == w['date']));
                    await persist();
                  },
                  icon: const Icon(Icons.close, size: 18))),
      ])),
    ]);
  }

  Widget statCard(String label, String value, IconData icon) => SizedBox(
      width: 240,
      child:
          panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: green),
        const SizedBox(height: 16),
        txt(value, size: 27, weight: FontWeight.w700),
        const SizedBox(height: 8),
        txt(label, size: 14, color: muted)
      ])));

  Widget preferences() => Preferences(
        profile: profile,
        onSave: (p) async {
          setState(() => profile = p);
          if (await persist()) {
            toast('Your preferences are saved');
            setState(() => page = 0);
          }
        },
      );
  void showFood(Food f) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(f.name),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: photo(f.image, height: 190, width: 400),
                ),
                const SizedBox(height: 18),
                txt(f.desc),
                const SizedBox(height: 14),
                txt(
                  '${f.kcal} kcal · ${f.p} g protein · ${f.c} g carbs · ${f.f} g fat',
                  size: 14,
                  color: green,
                ),
                const SizedBox(height: 14),
                txt(
                  'Why this meal? ${List<String>.from(profile['cuisines']).contains(f.cuisine) ? 'It matches your taste for ${f.cuisine} food.' : 'A new cuisine to explore.'} Ready in about ${f.minutes} minutes.',
                  size: 14,
                  color: muted,
                ),
                const SizedBox(height: 10),
                txt(
                  'Illustrative recipe and photo. Nutrition is sample data; confirm ingredients before eating.',
                  size: 12,
                  color: muted,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                scheduleMeal(selectedFood: f);
              },
              child: const Text('Plan this meal')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              showAdd(selected: f);
            },
            child: const Text('Log this meal'),
          ),
        ],
      ),
    );
  }

  void showAdd({
    bool photoMode = false,
    String group = 'Lunch',
    Food? selected,
  }) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => MealDialog(
        date: dayKey(date),
        initialGroup: group,
        photoMode: photoMode,
        selected: selected,
      ),
    );
    if (result != null) await add(result);
  }

  void showEdit(Map<String, dynamic> meal) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => MealDialog(
        date: meal['date'],
        initialGroup: meal['group'],
        existing: meal,
      ),
    );
    if (result != null) {
      setState(
        () => meals[meals.indexWhere((m) => m['id'] == meal['id'])] = result,
      );
      if (await persist()) toast('Meal updated');
    }
  }

  void deleteMeal(Map<String, dynamic> m) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this meal?'),
        content: Text(m['name']),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep meal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes == true) {
      setState(() => meals.removeWhere((x) => x['id'] == m['id']));
      await persist();
    }
  }
}

class MealDialog extends StatefulWidget {
  final String date, initialGroup;
  final bool photoMode;
  final Food? selected;
  final Map<String, dynamic>? existing;
  const MealDialog({
    super.key,
    required this.date,
    required this.initialGroup,
    this.photoMode = false,
    this.selected,
    this.existing,
  });
  @override
  State<MealDialog> createState() => _MealDialogState();
}

class _MealDialogState extends State<MealDialog> {
  late String group, mode;
  Food? food;
  Uint8List? image;
  bool sample = false;
  List<Map<String, dynamic>> ingredients = [];
  String query = '';
  String? error;
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      kcal = TextEditingController(),
      p = TextEditingController(),
      c = TextEditingController(),
      f = TextEditingController(),
      servings = TextEditingController(text: '1');
  @override
  void initState() {
    super.initState();
    group = widget.initialGroup;
    mode = widget.photoMode
        ? 'Photo'
        : widget.existing != null
            ? 'Custom'
            : 'Search';
    if (widget.selected != null) choose(widget.selected!);
    if (widget.existing != null) {
      final m = widget.existing!;
      name.text = m['name'];
      kcal.text = m['kcal'].toString();
      p.text = m['p'].toString();
      c.text = m['c'].toString();
      f.text = m['f'].toString();
      servings.text = '1';
    }
  }

  void choose(Food v) {
    ingredients = [];
    sample = false;
    food = v;
    name.text = v.name;
    kcal.text = v.kcal.toString();
    p.text = v.p.toString();
    c.text = v.c.toString();
    f.text = v.f.toString();
    servings.text = '1';
  }

  @override
  void dispose() {
    for (final t in [name, kcal, p, c, f, servings]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> pick() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 80,
      );
      if (x != null) {
        final bytes = await x.readAsBytes();
        if (bytes.length > 8 * 1024 * 1024) {
          setState(() => error = 'Please choose an image smaller than 8 MB.');
          return;
        }
        setState(() {
          image = bytes;
          error = null;
        });
      }
    } catch (_) {
      setState(() => error = 'Could not open that image. Try another photo.');
    }
  }

  void applyIngredients() {
    double sum(String key) => ingredients.fold<double>(
        0, (sum, i) => sum + (i['grams'] as num) * (i[key] as num) / 100);
    kcal.text = sum('kcal100').round().toString();
    p.text = sum('p100').round().toString();
    c.text = sum('c100').round().toString();
    f.text = sum('f100').round().toString();
  }

  Widget ingredientReview() => Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 18),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Review ingredients & portions',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text(
            'Illustrative ingredients, not detected from your photo. Changing grams recalculates the sample nutrition.',
            style: TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 12),
        for (final ingredient in ingredients)
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Expanded(
                    child: Text(ingredient['name'],
                        style: const TextStyle(fontSize: 14))),
                const SizedBox(width: 12),
                SizedBox(
                    width: 105,
                    child: TextFormField(
                        key: ValueKey(ingredient['name']),
                        initialValue: '${ingredient['grams']}',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Grams'),
                        validator: (s) => number(s, positive: true),
                        onChanged: (s) {
                          final n = double.tryParse(s);
                          if (n != null && n.isFinite && n > 0 && n <= 10000)
                            setState(() {
                              ingredient['grams'] = n;
                              applyIngredients();
                            });
                        })),
              ])),
      ]));
  String? number(String? s, {bool positive = false}) {
    final n = double.tryParse(s ?? '');
    return n == null ||
            !n.isFinite ||
            n < 0 ||
            (positive && n == 0) ||
            n > 10000
        ? 'Enter a valid amount'
        : null;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.existing != null
                    ? 'Edit your meal'
                    : 'Add a little nourishment',
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.existing == null)
                    Wrap(
                      spacing: 8,
                      children: ['Search', 'Photo', 'Custom']
                          .map(
                            (s) => ChoiceChip(
                              label: Text(s),
                              selected: mode == s,
                              onSelected: (_) => setState(() => mode = s),
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 18),
                  if (mode == 'Photo') ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F6F1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          if (image != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                image!,
                                height: 140,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            const Icon(
                              Icons.add_a_photo_outlined,
                              size: 36,
                              color: green,
                            ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: pick,
                            icon: const Icon(Icons.upload_outlined),
                            label: Text(
                              image == null
                                  ? 'Choose a meal photo'
                                  : 'Choose another photo',
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Photo flow demo',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Your photo stays on this device. This prototype does not analyze it. Choose a sample result to test the review flow.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: muted),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              choose(foods[1]);
                              ingredients = [
                                {
                                  'name': 'Cooked rice',
                                  'grams': 150.0,
                                  'kcal100': 130.0,
                                  'p100': 2.7,
                                  'c100': 28.0,
                                  'f100': 0.3
                                },
                                {
                                  'name': 'Cooked lentils',
                                  'grams': 150.0,
                                  'kcal100': 116.0,
                                  'p100': 9.0,
                                  'c100': 20.0,
                                  'f100': 0.4
                                },
                                {
                                  'name': 'Cooking oil',
                                  'grams': 5.0,
                                  'kcal100': 884.0,
                                  'p100': 0.0,
                                  'c100': 0.0,
                                  'f100': 100.0
                                },
                              ];
                              sample = true;
                              applyIngredients();
                            }),
                            child: const Text('Use sample: dal & rice →'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (sample) ingredientReview(),
                    if (sample)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Sample result — review and correct below.',
                          style: TextStyle(
                            color: green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                  if (mode == 'Search') ...[
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search meals, ingredients or cuisines',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => setState(() => query = v.toLowerCase()),
                    ),
                    const SizedBox(height: 12),
                    ...foods
                        .where(
                          (v) =>
                              ('${v.name} ${v.cuisine}').toLowerCase().contains(
                                    query,
                                  ),
                        )
                        .take(4)
                        .map(
                          (v) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              v.name,
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              '${v.cuisine} · ${v.kcal} kcal',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Icon(
                              food == v
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              color: green,
                            ),
                            onTap: () => setState(() => choose(v)),
                          ),
                        ),
                    if (!foods.any(
                      (v) => ('${v.name} ${v.cuisine}')
                          .toLowerCase()
                          .contains(query),
                    ))
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('No match. Use Custom to enter your meal.'),
                      ),
                    const Divider(height: 26),
                  ],
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Meal name'),
                    validator: (s) =>
                        (s ?? '').trim().isEmpty ? 'Enter a meal name' : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: group,
                          decoration:
                              const InputDecoration(labelText: 'Meal time'),
                          items: ['Breakfast', 'Lunch', 'Dinner', 'Snacks']
                              .map(
                                (g) =>
                                    DropdownMenuItem(value: g, child: Text(g)),
                              )
                              .toList(),
                          onChanged: (v) => group = v!,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: servings,
                          decoration: InputDecoration(
                            labelText: widget.existing != null
                                ? 'Portion multiplier'
                                : 'Servings',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (s) => number(s, positive: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.existing != null
                        ? 'Nutrition for the current entry'
                        : 'Nutrition per serving',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      numInput('Calories', kcal),
                      const SizedBox(width: 12),
                      numInput('Protein (g)', p),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      numInput('Carbs (g)', c),
                      const SizedBox(width: 12),
                      numInput('Fat (g)', f),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Sample values are editable. Confirm portions and ingredients before saving.',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              final s = double.parse(servings.text);
              Navigator.pop(context, {
                ...?widget.existing,
                if (ingredients.isNotEmpty) 'ingredients': ingredients,
                if (sample) 'source': 'sample_ingredient_estimate',
                'id': widget.existing?['id'] ??
                    DateTime.now().microsecondsSinceEpoch.toString(),
                'date': widget.date,
                'name': name.text.trim(),
                'group': group,
                'servings': widget.existing != null
                    ? (widget.existing!['servings'] as num) * s
                    : s,
                'cuisine':
                    food?.cuisine ?? widget.existing?['cuisine'] ?? 'Custom',
                'image': food?.image ??
                    widget.existing?['image'] ??
                    'mediterranean-salad.jpg',
                'kcal': (double.parse(kcal.text) * s).round(),
                'p': (double.parse(p.text) * s).round(),
                'c': (double.parse(c.text) * s).round(),
                'f': (double.parse(f.text) * s).round(),
              });
            },
            child:
                Text(widget.existing != null ? 'Save changes' : 'Add to diary'),
          ),
        ],
      );
  Widget numInput(String label, TextEditingController controller) => Expanded(
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          keyboardType: TextInputType.number,
          validator: (s) => number(s),
        ),
      );
}

class Preferences extends StatefulWidget {
  final Map<String, dynamic> profile;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const Preferences({super.key, required this.profile, required this.onSave});
  @override
  State<Preferences> createState() => _PreferencesState();
}

class _PreferencesState extends State<Preferences> {
  late Map<String, dynamic> p;
  late TextEditingController name, cal, protein, carbs, fat;
  final form = GlobalKey<FormState>();
  bool busy = false;
  @override
  void initState() {
    super.initState();
    p = {
      ...widget.profile,
      'cuisines': List<String>.from(widget.profile['cuisines']),
    };
    name = TextEditingController(text: p['name']);
    cal = TextEditingController(text: '${p['calories']}');
    protein = TextEditingController(text: '${p['protein']}');
    carbs = TextEditingController(text: '${p['carbs']}');
    fat = TextEditingController(text: '${p['fat']}');
  }

  @override
  void dispose() {
    for (final t in [name, cal, protein, carbs, fat]) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Healthy looks different on everyone.',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              const Text(
                'Let’s find what feels right for you.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'What should we call you?',
                      ),
                      validator: (s) =>
                          (s ?? '').trim().isEmpty ? 'Enter your name' : null,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'What brings you here?',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'Feel balanced',
                        'More protein',
                        'Build a routine'
                      ]
                          .map(
                            (s) => ChoiceChip(
                              label: Text(s),
                              selected: p['goal'] == s,
                              onSelected: (_) => setState(() => p['goal'] = s),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Your food preferences',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: ['Everything', 'Vegetarian']
                          .map(
                            (s) => ChoiceChip(
                              label: Text(s),
                              selected: p['diet'] == s,
                              onSelected: (_) => setState(() => p['diet'] = s),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Cuisines you love',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Indian', 'Italian', 'Japanese', 'American']
                          .map(
                            (s) => FilterChip(
                              label: Text(s),
                              selected: (p['cuisines'] as List).contains(s),
                              onSelected: (v) => setState(
                                () => v
                                    ? (p['cuisines'] as List).add(s)
                                    : (p['cuisines'] as List).remove(s),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Your daily targets',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Demo defaults, not a personalized dietary prescription. Set your own targets.',
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        field('Calories (kcal)', cal),
                        const SizedBox(width: 14),
                        field('Protein (g)', protein),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        field('Carbs (g)', carbs),
                        const SizedBox(width: 14),
                        field('Fat (g)', fat),
                      ],
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: busy
                            ? null
                            : () async {
                                if (!form.currentState!.validate()) return;
                                setState(() => busy = true);
                                await widget.onSave({
                                  ...p,
                                  'name': name.text.trim(),
                                  'calories': int.parse(cal.text),
                                  'protein': int.parse(protein.text),
                                  'carbs': int.parse(carbs.text),
                                  'fat': int.parse(fat.text),
                                  'done': true,
                                });
                                if (mounted) setState(() => busy = false);
                              },
                        child: Text(busy ? 'Saving…' : 'Save my preferences'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  Widget field(String label, TextEditingController c) => Expanded(
        child: TextFormField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label),
          validator: (s) {
            final n = int.tryParse(s ?? '');
            return n == null || n <= 0 || n > 10000 ? 'Enter 1–10,000' : null;
          },
        ),
      );
}
