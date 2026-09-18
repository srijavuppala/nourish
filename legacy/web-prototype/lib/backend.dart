import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'demo_data.dart';

class NourishBackend {
  static const demo = bool.fromEnvironment('DEMO_MODE');
  static const _demoKey = 'nourish_presentation_v1';
  static SupabaseClient? client;
  static String? initializationError;
  static bool get connected => client != null;
  static Future<void> initialize() async {
    if (demo) return;
    Map<String, dynamic> config = {};
    try {
      final r = await http
          .get(Uri.base.resolve('/api/config'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200)
        config = Map<String, dynamic>.from(jsonDecode(r.body));
    } catch (_) {
      return;
    }
    final url = config['supabaseUrl'] as String?;
    final key = config['supabasePublishableKey'] as String?;
    if (url == null || url.isEmpty || key == null || key.isEmpty) return;
    try {
      await Supabase.initialize(url: url, publishableKey: key);
      client = Supabase.instance.client;
    } catch (_) {
      initializationError =
          'Account services could not start. Please reload or contact the app owner.';
    }
  }

  static Future<Map<String, dynamic>?> load() async {
    if (demo) {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_demoKey);
      return value == null
          ? demoState(DateTime.now())
          : Map<String, dynamic>.from(jsonDecode(value));
    }
    if (client == null) {
      final r = await http.get(Uri.base.resolve('/api/state'));
      if (r.statusCode != 200) throw Exception('Could not load diary');
      final state = jsonDecode(r.body)['state'];
      return state == null ? null : Map<String, dynamic>.from(state);
    }
    final user = client!.auth.currentUser;
    if (user == null) throw Exception('Sign in required');
    final row = await client!
        .from('nourish_state')
        .select('data')
        .eq('user_id', user.id)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row['data']);
  }

  static Future<void> save(Map<String, dynamic> state) async {
    if (demo) {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_demoKey, jsonEncode(state))) {
        throw Exception('Could not save demo');
      }
      return;
    }
    if (client == null) {
      final r = await http.put(Uri.base.resolve('/api/state'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(state));
      if (r.statusCode != 200) throw Exception('Could not save diary');
      return;
    }
    final user = client!.auth.currentUser;
    if (user == null) throw Exception('Sign in required');
    await client!.from('nourish_state').upsert({
      'user_id': user.id,
      'data': state,
      'updated_at': DateTime.now().toUtc().toIso8601String()
    });
  }

  static Future<void> resetDemo() async {
    if (!demo) return;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(_demoKey)) throw Exception('Could not reset demo');
  }
}
