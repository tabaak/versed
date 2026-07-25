// Where the development tools get their Supabase credentials.
//
// The environment wins, so a one-off `SUPABASE_URL=... dart run …` still
// overrides everything. Otherwise `.env.local` at the project root is read,
// because that is where the key already lives and asking for it to be exported
// by hand every session is friction for no safety: the file is gitignored, and
// exporting it puts the same secret in the shell's environment anyway.

import 'dart:io';

const _envFileName = '.env.local';

/// A Supabase project and a key with which to talk to it.
class SupabaseCredentials {
  SupabaseCredentials({
    required this.url,
    required this.serviceKey,
    required this.source,
  });

  final String url;
  final String serviceKey;

  /// Where the values came from, so the tool can say so before it starts
  /// writing to whatever project they point at.
  final String source;
}

/// Reads the project url and service-role key, or returns null when neither the
/// environment nor `.env.local` supplies both.
///
/// The file is looked for in the working directory and then in each parent, so
/// the tools work from anywhere inside the checkout.
SupabaseCredentials? readSupabaseCredentials() {
  final fromEnvironment = _credentialsFrom(
    Platform.environment,
    'the environment',
  );
  if (fromEnvironment != null) return fromEnvironment;

  final file = _findEnvFile(Directory.current);
  if (file == null) return null;

  return _credentialsFrom(_parseEnvFile(file), file.path);
}

SupabaseCredentials? _credentialsFrom(Map<String, String> values, String from) {
  final url = values['SUPABASE_URL'];
  final serviceKey = values['SUPABASE_SERVICE_ROLE_KEY'];

  if (url == null || url.isEmpty || serviceKey == null || serviceKey.isEmpty) {
    return null;
  }

  return SupabaseCredentials(url: url, serviceKey: serviceKey, source: from);
}

File? _findEnvFile(Directory from) {
  for (var directory = from; ; directory = directory.parent) {
    final file = File('${directory.path}/$_envFileName');
    if (file.existsSync()) return file;

    // `parent` of the root is the root itself, which is where the walk ends.
    if (directory.parent.path == directory.path) return null;
  }
}

/// Parses the `KEY=value` lines this project's `.env.local` holds.
///
/// Deliberately not a full dotenv implementation: no interpolation, no multi
/// line values. It understands comments, blank lines, a leading `export`, and
/// surrounding quotes, which is everything the file actually uses.
Map<String, String> _parseEnvFile(File file) {
  final values = <String, String>{};

  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;

    final separator = line.indexOf('=');
    if (separator <= 0) continue;

    var key = line.substring(0, separator).trim();
    if (key.startsWith('export ')) key = key.substring(7).trim();

    var value = line.substring(separator + 1).trim();
    if (value.length >= 2 &&
        (value.startsWith('"') && value.endsWith('"') ||
            value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }

    values[key] = value;
  }

  return values;
}

/// The message to print when no credentials could be found.
const missingCredentialsMessage =
    'Could not find your Supabase credentials.\n'
    'Put them in $_envFileName at the project root:\n'
    '\n'
    "  SUPABASE_URL='https://<project>.supabase.co'\n"
    "  SUPABASE_SERVICE_ROLE_KEY='<service-role key>'\n"
    '\n'
    'Both are under Project Settings > API in the Supabase dashboard. '
    'Environment variables of the same name take precedence.';
