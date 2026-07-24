import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class AppInitializer {
  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();

    if (_supabaseUrl.isEmpty || _supabasePublishableKey.isEmpty) {
      throw StateError(
        'Missing Supabase configuration. Run the app with '
        '--dart-define=SUPABASE_URL=... and '
        '--dart-define=SUPABASE_PUBLISHABLE_KEY=...',
      );
    }

    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabasePublishableKey,
    );
  }
}
