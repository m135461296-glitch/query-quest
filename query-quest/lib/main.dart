import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

const ink = Color(0xFF13345B);
const blue = Color(0xFF3E8BEA);
const pale = Color(0xFFE9F4FF);
const canvas = Color(0xFFF4F9FF);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.isNotEmpty && key.isNotEmpty) {
    try {
      await Supabase.initialize(url: url, publishableKey: key);
    } catch (_) {
      // AuthGate reports the connection problem without exposing credentials.
    }
  }
  runApp(const QueryQuestApp());
}

class QueryQuestApp extends StatelessWidget {
  const QueryQuestApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Query Quest',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: canvas,
            colorScheme: ColorScheme.fromSeed(
                seedColor: blue, primary: blue, surface: Colors.white),
            fontFamily: 'monospace',
            inputDecorationTheme:
                const InputDecorationTheme(border: InputBorder.none)),
        home: const AuthGate(),
      );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Supabase.instance.isInitialized) return const _BackendSetupScreen();
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final user = client.auth.currentUser;
        if (user == null) return const LoginScreen();
        return GameHome(key: ValueKey(user.id));
      },
    );
  }
}

class _BackendSetupScreen extends StatelessWidget {
  const _BackendSetupScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFD5E9FC)),
              ),
              child: const Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.cloud_off_rounded, color: blue, size: 48),
                SizedBox(height: 14),
                Text('SUPABASE NOT CONNECTED',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 18)),
                SizedBox(height: 10),
                Text(
                    'Add your project URL and public publishable key to the app build. Then restart Query Quest to sign in.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ink, height: 1.5)),
              ]),
            ),
          ),
        ),
      );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool registering = false, busy = false, obscure = true;
  String? error, notice;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'Enter your email and password.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      if (registering) {
        final response = await auth.signUp(
            email: email.text.trim(), password: password.text);
        if (response.session == null && mounted) {
          setState(() => notice = 'Check your email to confirm your account.');
        }
      } else {
        await auth.signInWithPassword(
            email: email.text.trim(), password: password.text);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not connect. Check your network and try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFD5E9FC)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x143E8BEA), blurRadius: 22, offset: Offset(0, 10))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.storage_rounded, color: blue, size: 52),
                      const SizedBox(height: 10),
                      const Text('QUERY QUEST',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: ink, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 1.5)),
                      const SizedBox(height: 6),
                      Text(registering ? 'CREATE YOUR PLAYER ACCOUNT' : 'SIGN IN TO SAVE YOUR QUEST',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: blue, fontWeight: FontWeight.w800, fontSize: 12)),
                      const SizedBox(height: 26),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: _authDecoration('Email', Icons.alternate_email),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: password,
                        obscureText: obscure,
                        decoration: _authDecoration('Password', Icons.lock_outline).copyWith(
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => obscure = !obscure),
                            icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, color: blue),
                          ),
                        ),
                        onSubmitted: (_) => busy ? null : submit(),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 14),
                        Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ],
                      if (notice != null) ...[
                        const SizedBox(height: 14),
                        Text(notice!, style: const TextStyle(color: Colors.green, fontSize: 13)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: busy ? null : submit,
                        icon: busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Icon(registering ? Icons.person_add_alt_1 : Icons.login),
                        label: Text(registering ? 'CREATE ACCOUNT' : 'SIGN IN'),
                        style: FilledButton.styleFrom(backgroundColor: blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
                      TextButton(
                        onPressed: busy ? null : () => setState(() {
                          registering = !registering;
                          error = null;
                          notice = null;
                        }),
                        child: Text(registering ? 'Already have an account? Sign in' : 'New here? Create an account'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  InputDecoration _authDecoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: blue),
        filled: true,
        fillColor: pale,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      );
}

class QuestLevel {
  final String title, table, question, answer;
  final List<Map<String, Object>> rows;
  const QuestLevel(
      this.title, this.table, this.question, this.answer, this.rows);
}

const starterLevels = <QuestLevel>[
  QuestLevel('First SELECT', 'students',
      'Show every student. Start with SELECT *', 'SELECT * FROM students', [
    {'id': 1, 'name': 'Mia', 'grade': 'A'},
    {'id': 2, 'name': 'Leo', 'grade': 'B'},
    {'id': 3, 'name': 'Kai', 'grade': 'A'},
  ]),
  QuestLevel('Pick a column', 'students',
      'Show only the names of the students.', 'SELECT name FROM students', [
    {'id': 1, 'name': 'Mia', 'grade': 'A'},
    {'id': 2, 'name': 'Leo', 'grade': 'B'},
    {'id': 3, 'name': 'Kai', 'grade': 'A'},
  ]),
  QuestLevel('Filter time', 'students', 'Find students with grade A.',
      "SELECT name FROM students WHERE grade = 'A'", [
    {'id': 1, 'name': 'Mia', 'grade': 'A'},
    {'id': 2, 'name': 'Leo', 'grade': 'B'},
    {'id': 3, 'name': 'Kai', 'grade': 'A'},
  ]),
  QuestLevel('Top scorer', 'scores', 'Show the player with a score above 80.',
      'SELECT player FROM scores WHERE score > 80', [
    {'player': 'Mia', 'score': 95},
    {'player': 'Leo', 'score': 72},
    {'player': 'Kai', 'score': 88},
  ]),
  QuestLevel('Sort it out', 'scores', 'Show all players, highest score first.',
      'SELECT player, score FROM scores ORDER BY score DESC', [
    {'player': 'Mia', 'score': 95},
    {'player': 'Leo', 'score': 72},
    {'player': 'Kai', 'score': 88},
  ]),
  QuestLevel('Tiny list', 'snacks', 'Show the two cheapest snacks.',
      'SELECT item, price FROM snacks ORDER BY price ASC LIMIT 2', [
    {'item': 'Berry', 'price': 2},
    {'item': 'Cookie', 'price': 4},
    {'item': 'Mochi', 'price': 3},
  ]),
  QuestLevel(
      'Find the letter',
      'students',
      'Find students whose name starts with M.',
      "SELECT name FROM students WHERE name LIKE 'M%'", [
    {'id': 1, 'name': 'Mia', 'grade': 'A'},
    {'id': 2, 'name': 'Leo', 'grade': 'B'},
    {'id': 3, 'name': 'Kai', 'grade': 'A'},
  ]),
  QuestLevel('Final mix', 'scores', 'Get the top two scores, highest first.',
      'SELECT player, score FROM scores ORDER BY score DESC LIMIT 2', [
    {'player': 'Mia', 'score': 95},
    {'player': 'Leo', 'score': 72},
    {'player': 'Kai', 'score': 88},
  ]),
];

final levels = List<QuestLevel>.generate(100, (i) {
  final base = starterLevels[i % starterLevels.length];
  final round = i ~/ starterLevels.length;
  final rows = base.rows.map((row) => Map<String, Object>.from(row)).toList();
  const nameSets = [
    ['Mia', 'Leo', 'Kai'],
    ['Ava', 'Noah', 'Eli'],
    ['Milo', 'Luna', 'Ezra'],
    ['Maya', 'Liam', 'Kira'],
    ['Mina', 'Luca', 'Kian'],
  ];
  var question = base.question;
  var answer = base.answer;
  if (rows.first.containsKey('name')) {
    final names = nameSets[round % nameSets.length];
    for (var r = 0; r < rows.length; r++) {
      rows[r]['name'] = names[r % names.length];
    }
    if (i % starterLevels.length == 6) {
      final initial = names.first[0];
      question = 'Find students whose name starts with $initial.';
      answer = "SELECT name FROM students WHERE name LIKE '$initial%'";
    }
  }
  if (rows.first.containsKey('score')) {
    final shift = round * 3;
    for (final row in rows) {
      row['score'] = (row['score'] as int) + shift;
    }
    if (i % starterLevels.length == 3) {
      final threshold = 80 + shift;
      question = 'Show the player with a score above $threshold.';
      answer = 'SELECT player FROM scores WHERE score > $threshold';
    }
  }
  if (rows.first.containsKey('price')) {
    for (final row in rows) {
      row['price'] = (row['price'] as int) + round * 2;
    }
  }
  return QuestLevel(
      '${base.title} ${i + 1}', base.table, question, answer, rows);
});

String rankForLevel(int level) => level <= 20
    ? 'Data Newbie'
    : level <= 40
        ? 'Query Knight'
        : level <= 60
            ? 'Join Wizard'
            : level <= 80
                ? 'Schema Sage'
                : 'SQL Overlord';

class GameHome extends StatefulWidget {
  const GameHome({super.key});
  @override
  State<GameHome> createState() => _GameHomeState();
}

class _GameHomeState extends State<GameHome> {
  final input = TextEditingController();
  late String playerId;
  int unlocked = 1, selected = 0, lives = 5, streak = 0, gems = 0, xp = 0;
  final Map<int, int> hintsByLevel = {};
  String profileName = 'SQL Explorer', badge = 'None';
  String nameCard = 'Classic Blue';
  String? avatarPath;
  final Map<String, int> inventory = {
    'Hint Token': 0,
    'Skip Token': 0,
    'Combo Shield': 0,
    'XP Surge': 0
  };
  bool xpSurge = false;
  final Set<String> ownedNameCards = {};
  bool ready = false;
  final Set<int> complete = {};
  String? feedback;
  bool? correct;
  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final remoteUser = Supabase.instance.isInitialized
        ? Supabase.instance.client.auth.currentUser
        : null;
    Map<String, dynamic>? remoteProgress;
    if (remoteUser != null) {
      try {
        remoteProgress = await Supabase.instance.client
            .from('player_progress')
            .select()
            .eq('player_id', remoteUser.id)
            .maybeSingle();
      } catch (_) {
        // Keep device progress available if the network or table is unavailable.
      }
    }
    playerId = remoteUser?.id ??
        prefs.getString('player_id') ??
        'guest-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
    await prefs.setString('player_id', playerId);
    final saved = prefs.getStringList('completed_levels') ?? <String>[];
    final completed = saved
        .map((value) => int.tryParse(value))
        .whereType<int>()
        .toSet();
    if (remoteProgress != null) {
      final remoteCompleted = (remoteProgress['completed_levels'] as List? ?? [])
          .map((value) => (value as num).toInt() - 1)
          .where((value) => value >= 0 && value < levels.length)
          .toSet();
      completed.addAll(remoteCompleted);
      await prefs.setStringList(
          'completed_levels', completed.map((level) => '$level').toList());
      await prefs.setInt('unlocked_level', max(
          prefs.getInt('unlocked_level') ?? 1,
          (remoteProgress['unlocked_level'] as num?)?.toInt() ?? 1));
      await prefs.setInt('xp', max(prefs.getInt('xp') ?? 0,
          (remoteProgress['xp'] as num?)?.toInt() ?? 0));
      await prefs.setInt('gems', max(prefs.getInt('gems') ?? 0,
          (remoteProgress['coins'] as num?)?.toInt() ?? 0));
      final remoteInventory =
          (remoteProgress['inventory'] as Map?)?.cast<String, dynamic>();
      if (remoteInventory != null) {
        final localInventory = <String, dynamic>{};
        final savedInventory = prefs.getString('inventory');
        if (savedInventory != null) {
          localInventory.addAll(jsonDecode(savedInventory) as Map<String, dynamic>);
        }
        for (final entry in remoteInventory.entries) {
          localInventory[entry.key] = max(
              (localInventory[entry.key] as num?)?.toInt() ?? 0,
              (entry.value as num?)?.toInt() ?? 0);
        }
        await prefs.setString('inventory', jsonEncode(localInventory));
      }
      final remoteBadges = (remoteProgress['owned_badges'] as List? ?? [])
          .map((value) => value.toString());
      final remoteCards = (remoteProgress['owned_name_cards'] as List? ?? [])
          .map((value) => value.toString());
      await prefs.setStringList('owned_badges', {
        ...?prefs.getStringList('owned_badges'),
        ...remoteBadges,
      }.toList());
      await prefs.setStringList('owned_name_cards', {
        ...?prefs.getStringList('owned_name_cards'),
        ...remoteCards,
      }.toList());
      if (prefs.getString('profile_name') == null &&
          remoteProgress['profile_name'] is String) {
        await prefs.setString('profile_name', remoteProgress['profile_name'] as String);
      }
      if (prefs.getString('name_card') == null && remoteProgress['name_card'] is String) {
        await prefs.setString('name_card', remoteProgress['name_card'] as String);
      }
      if (prefs.getString('badge') == null && remoteProgress['equipped_badge'] is String) {
        await prefs.setString('badge', remoteProgress['equipped_badge'] as String);
      }
      if (prefs.getBool('xp_surge_armed') == null && remoteProgress['xp_surge_armed'] is bool) {
        await prefs.setBool('xp_surge_armed', remoteProgress['xp_surge_armed'] as bool);
      }
      if (prefs.getString('hints_by_level') == null && remoteProgress['hints_by_level'] is Map) {
        await prefs.setString('hints_by_level', jsonEncode(remoteProgress['hints_by_level']));
      }
    }
    if (!mounted) return;
    setState(() {
      complete
          .addAll(completed);
      unlocked =
          max(1, min(levels.length, prefs.getInt('unlocked_level') ?? 1));
      selected = min(unlocked - 1, max(0, prefs.getInt('selected_level') ?? 0));
      gems = prefs.getInt('gems') ?? complete.length * 20;
      xp = prefs.getInt('xp') ?? complete.length * 50;
      profileName = prefs.getString('profile_name') ?? 'SQL Explorer';
      avatarPath = prefs.getString('avatar_path');
      badge = prefs.getString('badge') ?? 'None';
      nameCard = prefs.getString('name_card') ?? 'Classic Blue';
      prefsBadges.addAll(prefs.getStringList('owned_badges') ?? const []);
      ownedNameCards
          .addAll(prefs.getStringList('owned_name_cards') ?? const []);
      xpSurge = prefs.getBool('xp_surge_armed') ?? false;
      final savedHints = prefs.getString('hints_by_level');
      if (savedHints != null) {
        for (final entry
            in (jsonDecode(savedHints) as Map<String, dynamic>).entries) {
          final index = int.tryParse(entry.key);
          if (index != null && index >= 0 && index < levels.length) {
            hintsByLevel[index] = entry.value as int;
          }
        }
      }
      final inv = prefs.getString('inventory');
      if (inv != null) {
        for (final e in (jsonDecode(inv) as Map<String, dynamic>).entries) {
          inventory[e.key] = e.value as int;
        }
      }
      ready = true;
    });
    if (remoteUser != null) _syncProgress();
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void submit() {
    final result = runPracticeSql(input.text, levels[selected]);
    final solved = result != null &&
        _sameRows(
          result,
          runPracticeSql(levels[selected].answer, levels[selected]) ?? [],
          ordered: RegExp(r'\border\s+by\b', caseSensitive: false)
              .hasMatch(levels[selected].answer),
        );
    setState(() {
      correct = solved;
      if (solved) {
        final firstClear = !complete.contains(selected);
        final earnedXp = max(
                10,
                (50 + min(streak, 10) * 5) *
                    (1 - min(hintsByLevel[selected] ?? 0, 3) * .18) *
                    (xpSurge ? 2 : 1))
            .round();
        final earnedCoins =
            max(5, 12 + min(streak, 10) - (hintsByLevel[selected] ?? 0) * 2)
                .toInt();
        feedback = firstClear
            ? 'NICE! Level ${selected + 1} badge earned! +$earnedXp XP  +$earnedCoins coins'
            : 'Level cleared!';
        if (firstClear) {
          xp += earnedXp;
          gems += earnedCoins;
          xpSurge = false;
        }
        complete.add(selected);
        unlocked = max(unlocked, min(levels.length, selected + 2));
        streak++;
        hintsByLevel.remove(selected);
      } else {
        feedback = result == null
            ? 'SQL not recognized. Try SELECT, WHERE, ORDER BY, or LIMIT; check the table and column names.'
            : 'Query ran, but the result is different. Check the selected columns, filter, or sort order.';
        lives = max(0, lives - 1);
        if ((inventory['Combo Shield'] ?? 0) > 0 && streak > 0) {
          inventory['Combo Shield'] = inventory['Combo Shield']! - 1;
          feedback = 'Shield saved your streak. Lost 1 heart.';
        } else {
          streak = 0;
        }
      }
    });
    _syncProgress();
  }

  bool _sameRows(List<Map<String, Object?>> a, List<Map<String, Object?>> b,
      {required bool ordered}) {
    if (a.length != b.length) return false;
    if (b.isEmpty) return a.isEmpty;
    // Grade only the columns required by the level's expected answer. A valid
    // SELECT * may return extra columns while still containing the right rows.
    final requiredColumns = b.first.keys.toList()..sort();
    if (b.any((row) => row.length != requiredColumns.length ||
        !requiredColumns.every(row.containsKey))) return false;
    if (a.any((row) => !requiredColumns.every(row.containsKey))) return false;
    String rowKey(Map<String, Object?> row) {
      return jsonEncode([
        for (final key in requiredColumns) [key, row[key]]
      ]);
    }

    if (ordered) {
      for (var i = 0; i < a.length; i++) {
        if (rowKey(a[i]) != rowKey(b[i])) return false;
      }
      return true;
    }
    // SQL does not promise row order unless ORDER BY is requested. Compare a
    // multiset so alternate valid sort orders pass while duplicate rows count.
    final counts = <String, int>{};
    for (final row in a) {
      final key = rowKey(row);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    for (final row in b) {
      final key = rowKey(row);
      final count = counts[key] ?? 0;
      if (count == 0) return false;
      counts[key] = count - 1;
    }
    return counts.values.every((count) => count == 0);
  }

  Future<void> _syncProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('unlocked_level', unlocked);
    await prefs.setInt('selected_level', selected);
    await prefs.setInt('gems', gems);
    await prefs.setInt('xp', xp);
    await prefs.setString('profile_name', profileName);
    await prefs.setString('badge', badge);
    await prefs.setString('name_card', nameCard);
    await prefs.setBool('xp_surge_armed', xpSurge);
    if (avatarPath != null) await prefs.setString('avatar_path', avatarPath!);
    await prefs.setString('inventory', jsonEncode(inventory));
    await prefs.setString(
        'hints_by_level',
        jsonEncode(
            {for (final e in hintsByLevel.entries) '${e.key}': e.value}));
    await prefs.setStringList('owned_badges', prefsBadges.toList());
    await prefs.setStringList('owned_name_cards', ownedNameCards.toList());
    await prefs.setStringList(
        'completed_levels', complete.map((level) => level.toString()).toList());
    try {
      if (Supabase.instance.isInitialized)
        await Supabase.instance.client.from('player_progress').upsert({
          'player_id': playerId,
          'unlocked_level': unlocked,
          'completed_levels': complete.map((n) => n + 1).toList(),
          'xp': xp,
          'coins': gems,
          'inventory': inventory,
          'profile_name': profileName,
          'equipped_badge': badge,
          'name_card': nameCard,
          'owned_badges': prefsBadges.toList(),
          'owned_name_cards': ownedNameCards.toList(),
          'xp_surge_armed': xpSurge,
          'hints_by_level': {
            for (final e in hintsByLevel.entries) '${e.key}': e.value
          },
          'updated_at': DateTime.now().toUtc().toIso8601String()
        });
    } catch (_) {
      /* Local play remains available without a configured backend. */
    }
  }

  Future<void> _openShop() async {
    const prices = {
      'Hint Token': 15,
      'Skip Token': 45,
      'Combo Shield': 30,
      'XP Surge': 35,
      'Blue Byte': 60,
      'Query Crown': 120,
      'Pixel Flame': 200,
      'Ocean Grid Card': 80,
      'Frost Byte Card': 140,
      'SQL Royal Card': 220
    };
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PIXEL SHOP   •   💎 $gems',
                      style: const TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 18)),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * .72),
                    child: SingleChildScrollView(
                      child: Column(
                          children: prices.entries.map((e) {
                        final nameCardCosmetic = e.key.endsWith(' Card');
                        final itemName = nameCardCosmetic
                            ? e.key.replaceFirst(' Card', '')
                            : e.key;
                        final cosmetic = nameCardCosmetic ||
                            ['Blue Byte', 'Query Crown', 'Pixel Flame']
                                .contains(e.key);
                        final owned = cosmetic &&
                            (nameCardCosmetic
                                ? (ownedNameCards.contains(itemName) ||
                                    nameCard == itemName)
                                : (prefsBadges.contains(e.key) ||
                                    badge == e.key));
                        return ListTile(
                          dense: true,
                          leading: Icon(
                              cosmetic ? Icons.workspace_premium : Icons.bolt,
                              color: blue),
                          title: Text(e.key,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(cosmetic
                              ? (owned
                                  ? ((nameCardCosmetic ? nameCard : badge) ==
                                          itemName
                                      ? 'Equipped'
                                      : 'Owned')
                                  : nameCardCosmetic
                                      ? 'HUD name card'
                                      : 'Equipable HUD badge')
                              : '${switch (e.key) {
                                  'Hint Token' =>
                                    'Query clue • max 3 per level',
                                  'Skip Token' =>
                                    'Skip next level • no XP or badge',
                                  'Combo Shield' =>
                                    'Auto-save streak on a wrong answer',
                                  _ => 'Double XP on your next uncleared level',
                                }} • Owned: ${inventory[e.key]}'),
                          trailing: TextButton(
                            onPressed: owned
                                ? ((nameCardCosmetic ? nameCard : badge) ==
                                        itemName
                                    ? null
                                    : () {
                                        setState(() {
                                          if (nameCardCosmetic) {
                                            nameCard = itemName;
                                          } else {
                                            badge = e.key;
                                          }
                                        });
                                        _syncProgress();
                                        refresh(() {});
                                      })
                                : (gems < e.value
                                    ? null
                                    : () {
                                        setState(() {
                                          gems -= e.value;
                                          if (nameCardCosmetic) {
                                            ownedNameCards.add(itemName);
                                          } else if (cosmetic) {
                                            prefsBadges.add(e.key);
                                          } else {
                                            inventory[e.key] =
                                                (inventory[e.key] ?? 0) + 1;
                                          }
                                        });
                                        _syncProgress();
                                        refresh(() {});
                                      }),
                            child: Text(owned
                                ? ((nameCardCosmetic ? nameCard : badge) ==
                                        itemName
                                    ? 'ON'
                                    : 'EQUIP')
                                : '💎 ${e.value}'),
                          ),
                        );
                      }).toList()),
                    ),
                  ),
                ]),
          ),
        ),
      ),
    );
  }

  final Set<String> prefsBadges = {};

  Future<void> _openProfile() async {
    final name = TextEditingController(text: profileName);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                22, 20, 22, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                onTap: () async {
                  final file = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 80,
                      maxWidth: 512);
                  if (file != null) {
                    final dir = await getApplicationDocumentsDirectory();
                    final saved = await File(file.path)
                        .copy('${dir.path}/query_quest_avatar.jpg');
                    setState(() => avatarPath = saved.path);
                    refresh(() {});
                  }
                },
                child: CircleAvatar(
                    radius: 43,
                    backgroundColor: pale,
                    backgroundImage:
                        avatarPath != null && File(avatarPath!).existsSync()
                            ? FileImage(File(avatarPath!))
                            : null,
                    child: avatarPath == null
                        ? const Icon(Icons.add_a_photo, color: blue)
                        : null),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Player name')),
              Text(rankForLevel(playerLevel),
                  style: const TextStyle(
                      color: blue, fontWeight: FontWeight.w900, fontSize: 18)),
              Text(
                  'Level $playerLevel  •  $xp XP  •  ${complete.length} puzzles cleared'),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: () {
                    setState(() => profileName = name.text.trim().isEmpty
                        ? 'SQL Explorer'
                        : name.text.trim());
                    _syncProgress();
                    Navigator.pop(ctx);
                  },
                  child: const Text('SAVE PROFILE')),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (Supabase.instance.isInitialized) {
                    await Supabase.instance.client.auth.signOut();
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('SIGN OUT'),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  int get playerLevel => min(100, xp ~/ 100 + 1);

  void _useHint() {
    if (complete.contains(selected)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Solved mo na ang level na ito—i-save ang Hint Token mo.')));
      return;
    }
    final levelHintsUsed = hintsByLevel[selected] ?? 0;
    if (levelHintsUsed >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Max 3 hints per level para manatiling may XP reward.')));
      return;
    }
    if ((inventory['Hint Token'] ?? 0) < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Walang Hint Token. Bilhin sa Shop.')));
      return;
    }
    final clue = _hintFor(levels[selected], levelHintsUsed);
    setState(() {
      inventory['Hint Token'] = inventory['Hint Token']! - 1;
      hintsByLevel[selected] = levelHintsUsed + 1;
      feedback = 'HINT ${levelHintsUsed + 1}/3: $clue';
      correct = null;
    });
    _syncProgress();
  }

  String _hintFor(QuestLevel level, int hintIndex) {
    if (hintIndex >= 2) return level.answer;
    if (hintIndex == 0) return 'Start with SELECT … FROM ${level.table}.';
    final where =
        RegExp(r'WHERE .+$', caseSensitive: false).firstMatch(level.answer);
    if (where != null) return 'Add a row filter: ${where.group(0)}.';
    final order =
        RegExp(r'ORDER BY .+$', caseSensitive: false).firstMatch(level.answer);
    if (order != null) return 'Sort the result: ${order.group(0)}.';
    final limit =
        RegExp(r'LIMIT \d+', caseSensitive: false).firstMatch(level.answer);
    if (limit != null) return 'Keep only ${limit.group(0)} after sorting.';
    return level.answer.contains('SELECT *')
        ? 'Use * after SELECT to return every column.'
        : 'Choose only the column the mission asks to display.';
  }

  void _useSkip() {
    if (complete.contains(selected)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cleared na ito. Gamitin ang Next Level button.')));
      return;
    }
    if ((inventory['Skip Token'] ?? 0) < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Walang Skip Token. Bilhin sa Shop.')));
      return;
    }
    if (selected >= levels.length - 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Final level na ito—walang susunod na level para i-skip.')));
      return;
    }
    setState(() {
      inventory['Skip Token'] = inventory['Skip Token']! - 1;
      unlocked = max(unlocked, min(100, selected + 2));
      selected++;
      input.clear();
      hintsByLevel.remove(selected - 1);
      streak = 0;
      feedback = 'Level skipped. Walang XP reward.';
      correct = null;
    });
    _syncProgress();
  }

  void _useXpSurge() {
    if (xpSurge) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Naka-ready na ang XP Surge sa next clear mo.')));
      return;
    }
    if ((inventory['XP Surge'] ?? 0) < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bumili muna ng XP Surge sa Shop.')));
      return;
    }
    if (complete.contains(selected)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Gamitin ang XP Surge sa level na hindi mo pa cleared.')));
      return;
    }
    setState(() {
      inventory['XP Surge'] = inventory['XP Surge']! - 1;
      xpSurge = true;
      feedback = 'XP Surge ready: doble XP sa susunod na clear!';
    });
    _syncProgress();
  }

  @override
  Widget build(BuildContext context) {
    final level = levels[selected];
    if (!ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
        body: SafeArea(
            child: CustomScrollView(slivers: [
      SliverToBoxAdapter(
          child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const PixelMark(),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('QUERY QUEST',
                                style: TextStyle(
                                    color: ink,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    letterSpacing: 1.2)),
                            Text(profileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: blue,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ])),
                      _pill('💎 $gems', blue),
                      IconButton(
                          tooltip: 'Shop',
                          onPressed: _openShop,
                          icon: const Icon(Icons.storefront_rounded,
                              color: blue)),
                      GestureDetector(
                          onTap: _openProfile,
                          child: CircleAvatar(
                              radius: 19,
                              backgroundColor: pale,
                              backgroundImage: avatarPath != null &&
                                      File(avatarPath!).existsSync()
                                  ? FileImage(File(avatarPath!))
                                  : null,
                              child: avatarPath == null
                                  ? const Icon(Icons.person,
                                      color: blue, size: 20)
                                  : null)),
                    ]),
                    Padding(
                        padding: const EdgeInsets.only(left: 48, top: 4),
                        child: Wrap(spacing: 7, runSpacing: 4, children: [
                          _nameCardChip(),
                          _pill('♥ $lives', const Color(0xFFE56B83)),
                          if (badge != 'None')
                            _pill('🏅 ${badge.split(' ').first}', blue),
                        ])),
                  ]))),
      SliverToBoxAdapter(
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: ink, borderRadius: BorderRadius.circular(18)),
                  child: Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              'LV $playerLevel  •  ${rankForLevel(playerLevel)}',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16)),
                          SizedBox(height: 6),
                          ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                  value: (xp % 100) / 100,
                                  minHeight: 7,
                                  backgroundColor: Color(0xFF315276),
                                  color: Color(0xFF8DC6FF))),
                          SizedBox(height: 4),
                          Text('$xp XP  •  ${xp % 100}/100 to next level',
                              style: TextStyle(
                                  color: Color(0xFFC9E4FF), fontSize: 11))
                        ])),
                    Text('${complete.length}/${levels.length} ✦',
                        style: const TextStyle(
                            color: Color(0xFFFFD776),
                            fontWeight: FontWeight.bold,
                            fontSize: 16))
                  ])))),
      SliverToBoxAdapter(
          child: SizedBox(
              height: 150,
              child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  itemCount: levels.length,
                  itemBuilder: (context, i) {
                    final open = i < unlocked,
                        done = complete.contains(i),
                        chosen = i == selected;
                    return Row(children: [
                      GestureDetector(
                          onTap: open
                              ? () {
                                  setState(() {
                                    selected = i;
                                    input.clear();
                                    feedback = null;
                                    correct = null;
                                  });
                                  _syncProgress();
                                }
                              : null,
                          child: Column(children: [
                            Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                    color: done
                                        ? const Color(0xFF61C6B5)
                                        : chosen
                                            ? blue
                                            : open
                                                ? Colors.white
                                                : const Color(0xFFDCEAF8),
                                    borderRadius: BorderRadius.circular(17),
                                    border: Border.all(
                                        color: chosen
                                            ? ink
                                            : const Color(0xFFC7DCF2),
                                        width: chosen ? 3 : 2),
                                    boxShadow: chosen
                                        ? [
                                            const BoxShadow(
                                                color: Color(0x553E8BEA),
                                                blurRadius: 0,
                                                offset: Offset(0, 5))
                                          ]
                                        : null),
                                child: Center(
                                    child: Text(
                                        done
                                            ? '🏅'
                                            : open
                                                ? '${i + 1}'
                                                : '🔒',
                                        style: TextStyle(
                                            color: chosen || done
                                                ? Colors.white
                                                : ink,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 19)))),
                            const SizedBox(height: 6),
                            Text('LV ${i + 1}',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: open ? ink : Colors.blueGrey,
                                    fontWeight: FontWeight.bold)),
                          ])),
                      if (i < levels.length - 1)
                        Container(
                            width: 20,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 20),
                            color: i + 1 < unlocked
                                ? const Color(0xFF8AC9EE)
                                : const Color(0xFFDCEAF8)),
                    ]);
                  }))),
      SliverToBoxAdapter(
          child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(
                              'LEVEL ${selected + 1}  /  ${level.title.toUpperCase()}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: ink,
                                  letterSpacing: .6))),
                      _pill(
                          complete.contains(selected)
                              ? '🏅 LV BADGE'
                              : '🏅 BADGE REWARD',
                          blue),
                      if (streak > 1)
                        Text('🔥 $streak streak',
                            style: const TextStyle(
                                color: blue, fontWeight: FontWeight.bold))
                    ]),
                    const SizedBox(height: 10),
                    Container(
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFFD5E8FB), width: 2)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 12, 14, 8),
                                  child: Row(children: [
                                    const Icon(Icons.table_chart_rounded,
                                        color: blue, size: 18),
                                    const SizedBox(width: 7),
                                    Text('TABLE: ${level.table}',
                                        style: const TextStyle(
                                            color: ink,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12))
                                  ])),
                              _table(level.rows),
                            ])),
                    const SizedBox(height: 14),
                    Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: pale,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                                color: const Color(0xFFC9E3FC), width: 2)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('YOUR MISSION',
                                  style: TextStyle(
                                      color: blue,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1)),
                              const SizedBox(height: 5),
                              Text(level.question,
                                  style: const TextStyle(
                                      color: ink,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      height: 1.3))
                            ])),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: OutlinedButton.icon(
                              onPressed: _useHint,
                              icon: const Icon(Icons.lightbulb_outline),
                              label: Text('HINT ${inventory['Hint Token']}'))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: OutlinedButton.icon(
                              onPressed: selected < levels.length - 1
                                  ? _useSkip
                                  : null,
                              icon: const Icon(Icons.skip_next),
                              label: Text('SKIP ${inventory['Skip Token']}'))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: OutlinedButton.icon(
                              onPressed: _useXpSurge,
                              icon: const Icon(Icons.auto_awesome),
                              label: Text(xpSurge
                                  ? 'SURGE READY'
                                  : 'SURGE ${inventory['XP Surge']}')))
                    ]),
                    if ((inventory['Combo Shield'] ?? 0) > 0)
                      Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                              '🛡️ ${inventory['Combo Shield']} COMBO SHIELD • auto-saves your streak after a wrong answer',
                              style: const TextStyle(
                                  color: blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10))),
                    const SizedBox(height: 10),
                    Container(
                        decoration: BoxDecoration(
                            color: const Color(0xFF10233F),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: blue, width: 2)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                  padding: EdgeInsets.fromLTRB(14, 11, 14, 0),
                                  child: Text('⌨  TYPE YOUR QUERY',
                                      style: TextStyle(
                                          color: Color(0xFF8DC6FF),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 10,
                                          letterSpacing: 1))),
                              TextField(
                                  controller: input,
                                  minLines: 2,
                                  maxLines: 4,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      height: 1.4),
                                  decoration: const InputDecoration(
                                      contentPadding: EdgeInsets.all(14),
                                      hintText: 'SELECT * FROM students',
                                      hintStyle: TextStyle(
                                          color: Color(0xFF8096B4),
                                          fontSize: 12)),
                                  onSubmitted: (_) => submit()),
                            ])),
                    const SizedBox(height: 10),
                    SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                            onPressed: submit,
                            icon: const Icon(Icons.bolt_rounded),
                            label: const Text('RUN QUERY',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                elevation: 0))),
                    if (feedback != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: correct!
                                      ? const Color(0xFFE4F8F3)
                                      : const Color(0xFFFFEEF0),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text(feedback!,
                                  style: TextStyle(
                                      color: correct!
                                          ? const Color(0xFF208C7A)
                                          : const Color(0xFFB5465E),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)))),
                    if (correct == true && selected < levels.length - 1)
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextButton(
                              onPressed: () => setState(() {
                                    selected++;
                                    input.clear();
                                    feedback = null;
                                    correct = null;
                                  }),
                              child: const Text('NEXT LEVEL  →'))),
                    const SizedBox(height: 12),
                    const Text(
                        'TIP: SQL keywords are case-insensitive. Use single quotes for text values.',
                        style:
                            TextStyle(color: Color(0xFF6B87A4), fontSize: 10)),
                  ]))),
    ])));
  }

  Widget _pill(String text, Color color) => Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(14)),
      child: Text(text,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w900, fontSize: 12)));

  Widget _nameCardChip() {
    final cardColor = switch (nameCard) {
      'Ocean Grid' => const Color(0xFFD9EEFF),
      'Frost Byte' => const Color(0xFFE1F8FF),
      'SQL Royal' => const Color(0xFFE8E5FF),
      _ => pale,
    };
    final textColor = switch (nameCard) {
      'Ocean Grid' => const Color(0xFF246BB0),
      'Frost Byte' => const Color(0xFF167A9A),
      'SQL Royal' => const Color(0xFF5F53A8),
      _ => blue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: textColor.withValues(alpha: .45), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: textColor.withValues(alpha: .14),
              offset: const Offset(0, 2))
        ],
      ),
      child: Text('🎴 $nameCard • $profileName',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: textColor, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }

  Widget _table(List<Map<String, Object>> rows) {
    final cols = rows.first.keys.toList();
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
            horizontalMargin: 12,
            columnSpacing: 25,
            headingRowHeight: 34,
            dataRowMinHeight: 34,
            dataRowMaxHeight: 38,
            headingTextStyle: const TextStyle(
                color: blue, fontWeight: FontWeight.w900, fontSize: 11),
            dataTextStyle: const TextStyle(
                color: ink, fontSize: 12, fontWeight: FontWeight.w600),
            columns: cols
                .map((c) => DataColumn(label: Text(c.toUpperCase())))
                .toList(),
            rows: rows
                .map((r) => DataRow(
                    cells: cols.map((c) => DataCell(Text('${r[c]}'))).toList()))
                .toList()));
  }
}

class PixelMark extends StatelessWidget {
  const PixelMark({super.key});
  @override
  Widget build(BuildContext context) => Container(
      width: 38,
      height: 38,
      decoration:
          BoxDecoration(color: blue, borderRadius: BorderRadius.circular(12)),
      child: const Center(
          child: Text('▦',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900))));
}

String? _stripSqlComments(String source) {
  final output = StringBuffer();
  String? quote;
  var i = 0;
  while (i < source.length) {
    final char = source[i];
    if (quote != null) {
      output.write(char);
      if (char == quote) {
        if (i + 1 < source.length && source[i + 1] == quote) {
          output.write(source[++i]);
        } else {
          quote = null;
        }
      }
      i++;
      continue;
    }
    if (char == "'" || char == '"') {
      quote = char;
      output.write(char);
      i++;
      continue;
    }
    if (source.startsWith('--', i)) {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
      output.write(' ');
      continue;
    }
    if (source.startsWith('/*', i)) {
      final end = source.indexOf('*/', i + 2);
      if (end < 0) return null;
      output.write(' ');
      i = end + 2;
      continue;
    }
    output.write(char);
    i++;
  }
  if (quote != null) return null;
  return output.toString();
}

List<Map<String, Object?>>? runPracticeSql(String raw, QuestLevel level) {
  var sql = _stripSqlComments(raw)?.trim();
  if (sql == null) return null;
  if (sql.endsWith(';')) sql = sql.substring(0, sql.length - 1).trimRight();
  if (sql.isEmpty || sql.contains(';')) {
    return null;
  }

  // Accept common SQL formatting, table aliases, DISTINCT, and qualified columns.
  final head = RegExp(
    r'^select\s+(distinct\s+)?(.+?)\s+from\s+(\w+)(?:\s+(?:as\s+)?(?!where\b|order\b|limit\b)(\w+))?(.*)$',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(sql);
  if (head == null ||
      head.group(3)!.toLowerCase() != level.table.toLowerCase()) {
    return null;
  }

  final alias = head.group(4)?.toLowerCase();
  final allowed = level.rows.first.keys.toSet();
  String? columnName(String token) {
    final pieces = token.trim().toLowerCase().split('.');
    if (pieces.length == 1) return pieces.single;
    if (pieces.length != 2 ||
        (pieces.first != level.table.toLowerCase() && pieces.first != alias)) {
      return null;
    }
    return pieces.last;
  }

  final selectText = head.group(2)!.trim();
  final selectAll = selectText == '*' ||
      selectText.toLowerCase() == '${alias ?? level.table}.*';
  final selectedColumns = <String>[];
  if (selectAll) {
    selectedColumns.addAll(allowed);
  } else {
    for (final part in selectText.split(',')) {
      final item = RegExp(
        r'^((?:\w+\.)?\w+)(?:\s+(?:as\s+)?(\w+))?$',
        caseSensitive: false,
      ).firstMatch(part.trim());
      if (item == null) return null;
      final column = columnName(item.group(1)!);
      if (column == null || !allowed.contains(column)) return null;
      selectedColumns
          .add(column); // Output aliases do not change the selected data.
    }
    if (selectedColumns.isEmpty ||
        selectedColumns.toSet().length != selectedColumns.length) {
      return null;
    }
  }

  var tail = head.group(5)!.trim();
  final where = RegExp(r'\bwhere\b([\s\S]*?)(?=\border\s+by\b|\blimit\b|$)',
          caseSensitive: false)
      .firstMatch(tail);
  final order =
      RegExp(r'\border\s+by\b([\s\S]*?)(?=\blimit\b|$)', caseSensitive: false)
          .firstMatch(tail);
  final limit =
      RegExp(r'\blimit\s+(\d+)\s*$', caseSensitive: false).firstMatch(tail);

  // Any clause the practice engine does not understand is rejected clearly.
  if (where != null) tail = tail.replaceFirst(where.group(0)!, ' ');
  if (order != null) tail = tail.replaceFirst(order.group(0)!, ' ');
  if (limit != null) tail = tail.replaceFirst(limit.group(0)!, ' ');
  if (tail.trim().isNotEmpty) return null;

  final conditionPattern = RegExp(
    r'^((?:\w+\.)?\w+)\s*(>=|<=|<>|!=|=|>|<|like)\s*(\x27[^\x27]*\x27|"[^"]*"|[-+]?(?:\d+(?:\.\d*)?|\.\d+)|[\w.%+-]+)$',
    caseSensitive: false,
  );
  if (where != null) {
    final orGroups =
        where.group(1)!.split(RegExp(r'\s+or\s+', caseSensitive: false));
    for (final group in orGroups) {
      for (final expression
          in group.split(RegExp(r'\s+and\s+', caseSensitive: false))) {
        final condition = conditionPattern.firstMatch(expression.trim());
        final key = condition == null ? null : columnName(condition.group(1)!);
        if (key == null || !allowed.contains(key)) return null;
      }
    }
  }

  bool matchesCondition(Map<String, Object?> row, String expression) {
    final condition = conditionPattern.firstMatch(expression.trim());
    if (condition == null) return false;
    final key = columnName(condition.group(1)!);
    if (key == null || !allowed.contains(key)) return false;
    final op = condition.group(2)!.toLowerCase();
    var value = condition.group(3)!;
    if ((value.startsWith("'") && value.endsWith("'")) ||
        (value.startsWith('"') && value.endsWith('"'))) {
      value = value.substring(1, value.length - 1);
    }
    final actual = row[key];
    if (op == 'like') {
      final pattern =
          '^${RegExp.escape(value).replaceAll('%', '.*').replaceAll('_', '.')}\$';
      return RegExp(pattern, caseSensitive: false).hasMatch('$actual');
    }
    final actualNumber = _num(actual);
    final expectedNumber = double.tryParse(value);
    final comparison = actualNumber != null && expectedNumber != null
        ? actualNumber.compareTo(expectedNumber)
        : '$actual'.toLowerCase().compareTo(value.toLowerCase());
    switch (op) {
      case '=':
        return actualNumber != null && expectedNumber != null
            ? actualNumber == expectedNumber
            : '$actual'.toLowerCase() == value.toLowerCase();
      case '!=':
      case '<>':
        return actualNumber != null && expectedNumber != null
            ? actualNumber != expectedNumber
            : '$actual'.toLowerCase() != value.toLowerCase();
      case '>':
        return comparison > 0;
      case '<':
        return comparison < 0;
      case '>=':
        return comparison >= 0;
      case '<=':
        return comparison <= 0;
      default:
        return false;
    }
  }

  bool matchesWhere(Map<String, Object?> row) {
    if (where == null) return true;
    // AND binds more tightly than OR, matching standard SQL predicate precedence.
    final orGroups =
        where.group(1)!.split(RegExp(r'\s+or\s+', caseSensitive: false));
    return orGroups.any((group) => group
        .split(RegExp(r'\s+and\s+', caseSensitive: false))
        .every((condition) => matchesCondition(row, condition)));
  }

  var result = level.rows
      .map((r) => Map<String, Object?>.from(r))
      .where(matchesWhere)
      .toList();

  if (order != null) {
    final terms = <(String, bool)>[];
    for (final part in order.group(1)!.split(',')) {
      final item =
          RegExp(r'^((?:\w+\.)?\w+)(?:\s+(asc|desc))?$', caseSensitive: false)
              .firstMatch(part.trim());
      if (item == null) return null;
      final key = columnName(item.group(1)!);
      if (key == null || !allowed.contains(key)) return null;
      terms.add((key, (item.group(2) ?? 'asc').toLowerCase() == 'desc'));
    }
    result.sort((a, b) {
      for (final (key, desc) in terms) {
        final x = _num(a[key]), y = _num(b[key]);
        final comparison = x != null && y != null
            ? x.compareTo(y)
            : '${a[key]}'.toLowerCase().compareTo('${b[key]}'.toLowerCase());
        if (comparison != 0) return desc ? -comparison : comparison;
      }
      return 0;
    });
  }

  if (limit != null) {
    final count = int.tryParse(limit.group(1)!);
    if (count == null || count < 0 || count > 100) return null;
    result = result.take(count).toList();
  }

  if (head.group(1) != null) {
    final seen = <String>{};
    result = result
        .where((row) =>
            seen.add(jsonEncode([for (final c in selectedColumns) row[c]])))
        .toList();
  }
  return result
      .map((row) => {for (final c in selectedColumns) c: row[c]})
      .toList();
}

double? _num(Object? x) => x is num ? x.toDouble() : double.tryParse('$x');
