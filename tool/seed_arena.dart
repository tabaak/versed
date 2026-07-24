// Fills the arena with synthetic users, fits and votes so the app has
// something to show during development.
//
// The arena cannot be seeded from your own account: cast_vote() refuses votes
// on your own fits, so fits owned by you are invisible to you. This script
// therefore creates throwaway auth users and gives the fits to them.
//
// Requires the service-role key, which bypasses RLS. Never commit it, and
// never point this at production.
//
//   export SUPABASE_URL='https://<project>.supabase.co'
//   export SUPABASE_SERVICE_ROLE_KEY='<service-role key>'
//
//   dart run tool/seed_arena.dart                    # 8 users x 3 fits + votes
//   dart run tool/seed_arena.dart --users 20 --fits 4
//   dart run tool/seed_arena.dart --download 30      # fetch placeholder photos
//   dart run tool/seed_arena.dart --images ~/outfits # use your own directory
//   dart run tool/seed_arena.dart --clean --yes      # remove everything seeded
//
// Seeded accounts are recognised by their email domain, so --clean can never
// touch a real user.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase/supabase.dart';

/// Every synthetic account uses this domain. `.invalid` is reserved by RFC
/// 2606 and can never be a real address, which is what makes --clean safe.
const seedEmailDomain = 'versed-seed.invalid';

const seedHandlePrefix = 'arena_seed_';

const _bucket = 'fits';

const _displayNames = [
  'Nova Reyes',
  'Kit Alvarez',
  'Juno Park',
  'Remy Okafor',
  'Sasha Lindqvist',
  'Theo Marchetti',
  'Wren Castillo',
  'Idris Bello',
  'Mika Tanaka',
  'Lior Ben-Ari',
  'Priya Raman',
  'Dax Ferreira',
];

final _random = Random();

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);

  final url = Platform.environment['SUPABASE_URL'];
  final serviceKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];

  if (url == null || url.isEmpty || serviceKey == null || serviceKey.isEmpty) {
    _fail(
      'Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY before running.\n'
      'Find both under Project Settings > API in the Supabase dashboard.',
    );
  }

  final client = SupabaseClient(
    url,
    serviceKey,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  try {
    if (options.clean) {
      await _clean(client, confirmed: options.yes);
    } else {
      await _seed(client, options);
    }
  } finally {
    await client.dispose();
  }
}

Future<void> _seed(SupabaseClient client, _Options options) async {
  final images = options.downloadCount > 0
      ? await _downloadImages(options.downloadCount)
      : _readImages(options.imageDirectory);

  if (images.isEmpty) {
    _fail(
      'No images found in ${options.imageDirectory}. '
      'Point --images at a directory of photos, or use --download N.',
    );
  }

  stdout.writeln(
    'Seeding ${options.userCount} users x ${options.fitsPerUser} fits '
    'from ${images.length} source images…',
  );

  final fitIdsByOwner = <String, List<String>>{};
  var imageCursor = 0;

  for (var index = 0; index < options.userCount; index++) {
    final suffix = DateTime.now().millisecondsSinceEpoch % 100000;
    final handle = '$seedHandlePrefix${suffix}_$index';
    final email = '$handle@$seedEmailDomain';

    final response = await client.auth.admin.createUser(
      AdminUserAttributes(
        email: email,
        password: _randomPassword(),
        emailConfirm: true,
        userMetadata: {
          'full_name': _displayNames[index % _displayNames.length],
        },
      ),
    );

    final user = response.user;
    if (user == null) {
      stderr.writeln('  ! could not create $email, skipping');
      continue;
    }

    // The on_auth_user_created trigger already made the profile row; it just
    // has no handle, because Google sign-in never supplies one either.
    await client
        .from('profiles')
        .update({'username': handle.substring(0, min(handle.length, 20))})
        .eq('id', user.id);

    final fitIds = <String>[];
    for (var fitIndex = 0; fitIndex < options.fitsPerUser; fitIndex++) {
      final image = images[imageCursor++ % images.length];
      final path =
          '${user.id}/${DateTime.now().microsecondsSinceEpoch}'
          '-${_random.nextInt(1 << 32)}.${image.extension}';

      await client.storage
          .from(_bucket)
          .uploadBinary(
            path,
            image.bytes,
            fileOptions: FileOptions(contentType: image.contentType),
          );

      final row = await client
          .from('fits')
          .insert({'owner_id': user.id, 'image_path': path})
          .select('id')
          .single();

      fitIds.add(row['id'] as String);
    }

    fitIdsByOwner[user.id] = fitIds;
    stdout.writeln('  + @$handle with ${fitIds.length} fits');
  }

  if (options.voteCount > 0) {
    final cast = await _seedVotes(client, fitIdsByOwner, options.voteCount);
    stdout.writeln('  + $cast votes');
  }

  stdout.writeln(
    '\nDone. Sign in with your own account and the arena will pair these '
    'fits for you.',
  );
}

/// Writes votes straight to the table rather than through cast_vote().
///
/// The RPC reads auth.uid() to identify the voter, and the service-role key
/// has no user attached, so it would always raise 'not authenticated'. Writing
/// directly means reproducing what the function guarantees: normalised pair
/// order, no self-voting, and both counters moved.
Future<int> _seedVotes(
  SupabaseClient client,
  Map<String, List<String>> fitIdsByOwner,
  int target,
) async {
  final owners = fitIdsByOwner.keys.toList();
  if (owners.length < 2) return 0;

  final ownerOfFit = <String, String>{
    for (final entry in fitIdsByOwner.entries)
      for (final fitId in entry.value) fitId: entry.key,
  };
  final allFits = ownerOfFit.keys.toList();

  final used = <String>{};
  var cast = 0;
  var attempts = 0;

  while (cast < target && attempts < target * 10) {
    attempts++;

    final voter = owners[_random.nextInt(owners.length)];
    final winner = allFits[_random.nextInt(allFits.length)];
    final loser = allFits[_random.nextInt(allFits.length)];

    if (winner == loser) continue;
    if (ownerOfFit[winner] == voter || ownerOfFit[loser] == voter) continue;

    // Canonical order: the smaller uuid is always fit_a. Postgres orders
    // uuids byte-wise, which for lowercase canonical text matches a plain
    // string comparison.
    final fitA = winner.compareTo(loser) < 0 ? winner : loser;
    final fitB = winner.compareTo(loser) < 0 ? loser : winner;

    if (!used.add('$voter:$fitA:$fitB')) continue;

    await client.from('votes').insert({
      'voter_id': voter,
      'fit_a_id': fitA,
      'fit_b_id': fitB,
      'winner_id': winner,
    });

    await _bumpCounter(client, fitId: winner, column: 'wins');
    await _bumpCounter(client, fitId: loser, column: 'losses');
    cast++;
  }

  return cast;
}

Future<void> _bumpCounter(
  SupabaseClient client, {
  required String fitId,
  required String column,
}) async {
  final row = await client.from('fits').select(column).eq('id', fitId).single();

  await client
      .from('fits')
      .update({column: (row[column] as int) + 1})
      .eq('id', fitId);
}

Future<void> _clean(SupabaseClient client, {required bool confirmed}) async {
  final users = await client.auth.admin.listUsers(perPage: 1000);
  final seeded = users
      .where((user) => user.email?.endsWith('@$seedEmailDomain') ?? false)
      .toList();

  if (seeded.isEmpty) {
    stdout.writeln('No seeded accounts found. Nothing to remove.');
    return;
  }

  if (!confirmed) {
    stdout.writeln(
      'Would delete ${seeded.length} seeded accounts and every fit, vote and '
      'photo belonging to them.\nRe-run with --yes to go ahead.',
    );
    return;
  }

  for (final user in seeded) {
    // Deleting the auth user cascades to profiles, fits and votes. Storage
    // objects are not covered by that cascade, so remove them first.
    try {
      final objects = await client.storage.from(_bucket).list(path: user.id);
      if (objects.isNotEmpty) {
        await client.storage
            .from(_bucket)
            .remove(
              objects.map((object) => '${user.id}/${object.name}').toList(),
            );
      }
    } catch (error) {
      stderr.writeln('  ! could not clear photos for ${user.email}: $error');
    }

    await client.auth.admin.deleteUser(user.id);
    stdout.writeln('  - ${user.email}');
  }

  stdout.writeln('\nRemoved ${seeded.length} seeded accounts.');
}

List<_SeedImage> _readImages(String directoryPath) {
  final directory = Directory(directoryPath);
  if (!directory.existsSync()) return const [];

  final images = <_SeedImage>[];
  for (final entity in directory.listSync()) {
    if (entity is! File) continue;
    final extension = entity.path.split('.').last.toLowerCase();
    if (!_contentTypes.containsKey(extension)) continue;
    images.add(
      _SeedImage(bytes: entity.readAsBytesSync(), extension: extension),
    );
  }

  images.sort((a, b) => a.bytes.length.compareTo(b.bytes.length));
  return images;
}

/// Pulls placeholder photos from Lorem Picsum at the arena's 4:5 ratio.
///
/// These are stock photographs, not outfits — useful for filling the board
/// and checking layout, not for judging how the app feels to actually use.
Future<List<_SeedImage>> _downloadImages(int count) async {
  stdout.writeln('Downloading $count placeholder photos…');

  final httpClient = HttpClient();
  final images = <_SeedImage>[];

  try {
    for (var index = 0; index < count; index++) {
      final uri = Uri.parse(
        'https://picsum.photos/1080/1350?random=${_random.nextInt(1 << 31)}',
      );
      final request = await httpClient.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != 200) {
        stderr.writeln('  ! ${response.statusCode} for photo $index, skipping');
        continue;
      }

      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }

      images.add(_SeedImage(bytes: builder.takeBytes(), extension: 'jpg'));
    }
  } finally {
    httpClient.close();
  }

  return images;
}

String _randomPassword() {
  final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
  return base64Url.encode(bytes);
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}

const _contentTypes = <String, String>{
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
};

class _SeedImage {
  _SeedImage({required this.bytes, required this.extension});

  final Uint8List bytes;
  final String extension;

  String get contentType => _contentTypes[extension] ?? 'image/jpeg';
}

class _Options {
  _Options({
    required this.userCount,
    required this.fitsPerUser,
    required this.voteCount,
    required this.imageDirectory,
    required this.downloadCount,
    required this.clean,
    required this.yes,
  });

  factory _Options.parse(List<String> args) {
    var userCount = 8;
    var fitsPerUser = 3;
    var voteCount = 40;
    var imageDirectory = 'assets/auth';
    var downloadCount = 0;
    var clean = false;
    var yes = false;

    for (var index = 0; index < args.length; index++) {
      switch (args[index]) {
        case '--users':
          userCount = int.parse(args[++index]);
        case '--fits':
          fitsPerUser = int.parse(args[++index]);
        case '--votes':
          voteCount = int.parse(args[++index]);
        case '--images':
          imageDirectory = args[++index];
        case '--download':
          downloadCount = int.parse(args[++index]);
        case '--clean':
          clean = true;
        case '--yes':
          yes = true;
        default:
          _fail('Unknown argument: ${args[index]}');
      }
    }

    return _Options(
      userCount: userCount,
      fitsPerUser: fitsPerUser,
      voteCount: voteCount,
      imageDirectory: imageDirectory,
      downloadCount: downloadCount,
      clean: clean,
      yes: yes,
    );
  }

  final int userCount;
  final int fitsPerUser;
  final int voteCount;
  final String imageDirectory;
  final int downloadCount;
  final bool clean;
  final bool yes;
}
