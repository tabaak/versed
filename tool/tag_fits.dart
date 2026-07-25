// Tags real outfit photos with a genre by hand and enters them into the arena.
//
// Terminal prompts are the wrong tool for this: judging a fit's genre means
// looking at it. So this serves a small page on localhost that shows one photo
// at a time with a button per genre. Choosing one uploads that photo straight
// away — the fit is in the arena before you have finished looking at the next
// photo — so quitting halfway loses nothing.
//
// Fits need owners other than you (cast_vote() refuses votes on your own
// fits), so the photos are spread across throwaway accounts using the same
// naming convention as tool/seed_arena.dart. That means `seed_arena --clean`
// removes these too.
//
// Matchmaking pairs within a genre, so a genre holding fits from only one
// person can never produce a battle. The tool spreads each genre's photos
// across as many owners as it has, and warns about genres left with one.
//
// Requires the service-role key, which bypasses RLS. It is read from
// `.env.local` at the project root (SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY),
// or from environment variables of the same name, which win. Never commit it,
// and never point this at production.
//
//   dart run tool/tag_fits.dart --images ~/outfits
//   dart run tool/tag_fits.dart --images ~/outfits --owners 8
//   dart run tool/tag_fits.dart --images ~/outfits --all   # include photos
//                                                          # already uploaded
//
// Photos already entered are recorded in `.versed-tagged.json` inside the
// image directory and skipped next run, so a big directory can be worked
// through over several sittings. Re-tagging one from the page updates the
// genre of the fit it already created rather than uploading it again.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:supabase/supabase.dart';
import 'package:versed/features/fits/models/fit_genre.dart';

import 'seed_identities.dart';
import 'tool_env.dart';

const _bucket = 'fits';

const _manifestName = '.versed-tagged.json';

const _contentTypes = <String, String>{
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
};

final _random = Random();

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);

  final credentials = readSupabaseCredentials();
  if (credentials == null) {
    _fail(missingCredentialsMessage);
  }

  // Said out loud because the service-role key bypasses RLS: whatever project
  // this names is about to be written to.
  stdout.writeln('Using ${credentials.url} (from ${credentials.source}).');

  final directory = Directory(options.imageDirectory);
  if (!directory.existsSync()) {
    _fail('No such directory: ${options.imageDirectory}');
  }

  final manifest = _Manifest.load(directory);
  final photos = _readPhotos(directory);

  if (photos.isEmpty) {
    _fail(
      'No images found in ${options.imageDirectory}. '
      'Supported: ${_contentTypes.keys.join(', ')}.',
    );
  }

  final queue = options.includeAll
      ? photos
      : photos.where((photo) => !manifest.contains(photo.name)).toList();

  if (queue.isEmpty) {
    stdout.writeln(
      'All ${photos.length} photos in ${options.imageDirectory} are already in '
      'the arena.\nRe-run with --all to review or re-tag them.',
    );
    return;
  }

  final skipped = photos.length - queue.length;
  stdout.writeln(
    'Found ${photos.length} photos in ${options.imageDirectory}'
    '${skipped > 0 ? ', $skipped already entered' : ''}.',
  );

  final client = SupabaseClient(
    credentials.url,
    credentials.serviceKey,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  try {
    final owners = await ensureSeedOwners(
      client,
      options.ownerCount,
      log: stdout.writeln,
    );
    if (owners.length < 2) {
      _fail(
        'Need at least 2 owner accounts so a genre can hold two people\'s '
        'fits, but only ${owners.length} could be created.',
      );
    }

    final session = _TagSession(
      client: client,
      owners: owners..shuffle(),
      manifest: manifest,
      queue: queue,
    );

    await _serve(session, options);
  } finally {
    await client.dispose();
  }
}

// ---------------------------------------------------------------------------
// Tagging session
// ---------------------------------------------------------------------------

/// Holds everything the page acts on: the photo queue, the owner pool, and the
/// record of what has already been entered.
class _TagSession {
  _TagSession({
    required this.client,
    required this.owners,
    required this.manifest,
    required this.queue,
  });

  final SupabaseClient client;

  /// The test accounts the fits are handed to, in a per-session random order so
  /// repeated runs over the same photos do not always load up the same people.
  final List<SeedOwner> owners;
  final _Manifest manifest;
  final List<_Photo> queue;

  /// Where the next fit of each genre goes. Rotating per genre rather than
  /// globally is what guarantees a genre's fits land on different people:
  /// a global cursor would give one genre every third photo and could hand
  /// them all to the same owner.
  final _ownerCursors = <FitGenre, int>{};

  /// The owner a fit was entered under, when it is one of this session's.
  /// A fit entered before an account was renamed, or by a run with a smaller
  /// pool, is simply not named.
  SeedOwner? _ownerWithId(String id) {
    for (final owner in owners) {
      if (owner.id == id) return owner;
    }
    return null;
  }

  _Photo? photoNamed(String name) {
    for (final photo in queue) {
      if (photo.name == name) return photo;
    }
    return null;
  }

  /// Uploads [photo] and creates its fit, or moves an already-entered photo to
  /// a different genre.
  ///
  /// Re-tagging updates the existing row instead of uploading again, so
  /// correcting a mistake does not leave the same outfit in the arena twice.
  Future<_TagResult> tag(_Photo photo, FitGenre genre) async {
    final existing = manifest.entryFor(photo.name);

    if (existing != null) {
      await client
          .from('fits')
          .update({'genre': genre.value})
          .eq('id', existing.fitId);

      manifest.record(
        name: photo.name,
        fitId: existing.fitId,
        ownerId: existing.ownerId,
        genre: genre,
      );

      // The fit keeps the owner it was entered under: moving it would rewrite
      // whose win record the battles it already fought belong to.
      return _TagResult(
        genre: genre,
        owner: _ownerWithId(existing.ownerId),
        retagged: true,
      );
    }

    final cursor = _ownerCursors[genre] ?? _random.nextInt(owners.length);
    _ownerCursors[genre] = cursor + 1;
    final owner = owners[cursor % owners.length];

    final bytes = photo.file.readAsBytesSync();
    final path =
        '${owner.id}/${DateTime.now().microsecondsSinceEpoch}'
        '-${_random.nextInt(1 << 32)}.${photo.extension}';

    await client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: photo.contentType),
        );

    try {
      final row = await client
          .from('fits')
          .insert({
            'owner_id': owner.id,
            'image_path': path,
            'genre': genre.value,
          })
          .select('id')
          .single();

      manifest.record(
        name: photo.name,
        fitId: row['id'] as String,
        ownerId: owner.id,
        genre: genre,
      );

      return _TagResult(genre: genre, owner: owner, retagged: false);
    } catch (error) {
      // Do not leave the object behind if the row never happened, or the
      // bucket slowly fills with images nothing points at.
      await client.storage
          .from(_bucket)
          .remove([path])
          .catchError((_) => <FileObject>[]);
      rethrow;
    }
  }

  /// How many fits and distinct owners each genre holds arena-wide.
  ///
  /// Read from the database rather than from the manifest, because what
  /// matters is whether a genre can produce a matchup at all — and fits tagged
  /// in an earlier session, or from another directory, count towards that just
  /// as much as tonight's.
  Future<Map<FitGenre, _GenreTally>> tally() async {
    final rows = await client
        .from('fits')
        .select('genre, owner_id')
        .isFilter('deleted_at', null)
        .isFilter('hidden_at', null);

    final tallies = <FitGenre, _GenreTally>{};
    for (final row in rows) {
      final genre = FitGenre.fromValue(row['genre'] as String?);
      if (genre == null) continue;
      final tally = tallies.putIfAbsent(genre, _GenreTally.new);
      tally.fits++;
      tally.owners.add(row['owner_id'] as String);
    }

    return tallies;
  }
}

/// A genre's standing in the arena. Two owners is the threshold that matters:
/// matchmaking pairs within a genre and a battle is between two people, so a
/// genre held by one person never produces a matchup.
class _GenreTally {
  var fits = 0;
  final owners = <String>{};

  bool get canMatch => owners.length >= 2;
}

class _TagResult {
  _TagResult({
    required this.genre,
    required this.owner,
    required this.retagged,
  });

  final FitGenre genre;

  /// Who the fit belongs to, so the page can say whose it became. Null when the
  /// row predates this session's owner pool.
  final SeedOwner? owner;
  final bool retagged;
}

class _Photo {
  _Photo({required this.file, required this.name, required this.extension});

  final File file;
  final String name;
  final String extension;

  String get contentType => _contentTypes[extension] ?? 'image/jpeg';
}

List<_Photo> _readPhotos(Directory directory) {
  final photos = <_Photo>[];

  for (final entity in directory.listSync()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    final extension = name.split('.').last.toLowerCase();
    if (!_contentTypes.containsKey(extension)) continue;
    photos.add(_Photo(file: entity, name: name, extension: extension));
  }

  photos.sort((a, b) => a.name.compareTo(b.name));
  return photos;
}

// ---------------------------------------------------------------------------
// Manifest
// ---------------------------------------------------------------------------

class _ManifestEntry {
  _ManifestEntry({
    required this.name,
    required this.fitId,
    required this.ownerId,
    required this.genre,
  });

  final String name;
  final String fitId;
  final String ownerId;
  final String genre;

  Map<String, dynamic> toJson() => {
    'name': name,
    'fit_id': fitId,
    'owner_id': ownerId,
    'genre': genre,
  };
}

/// Which photos in a directory are already in the arena, and as what.
///
/// Written next to the photos rather than in the project, so moving the
/// directory keeps its history and two directories never share one file.
/// Saved after every tag: the point is that quitting mid-session loses nothing.
class _Manifest {
  _Manifest(this._file, this._byName);

  factory _Manifest.load(Directory directory) {
    final file = File('${directory.path}/$_manifestName');
    final byName = <String, _ManifestEntry>{};

    if (file.existsSync()) {
      try {
        final decoded = jsonDecode(file.readAsStringSync());
        final rows = (decoded is Map ? decoded['fits'] : decoded) as List?;
        for (final row in rows ?? const []) {
          final map = row as Map<String, dynamic>;
          final entry = _ManifestEntry(
            name: map['name'] as String,
            fitId: map['fit_id'] as String,
            ownerId: map['owner_id'] as String,
            genre: map['genre'] as String,
          );
          byName[entry.name] = entry;
        }
      } catch (error) {
        // A corrupt manifest must not block tagging: worst case a photo is
        // offered again, which is visible on the page and easy to skip.
        stderr.writeln('  ! ignoring unreadable ${file.path}: $error');
      }
    }

    return _Manifest(file, byName);
  }

  final File _file;
  final Map<String, _ManifestEntry> _byName;

  Iterable<_ManifestEntry> get entries => _byName.values;

  bool contains(String name) => _byName.containsKey(name);

  _ManifestEntry? entryFor(String name) => _byName[name];

  void record({
    required String name,
    required String fitId,
    required String ownerId,
    required FitGenre genre,
  }) {
    _byName[name] = _ManifestEntry(
      name: name,
      fitId: fitId,
      ownerId: ownerId,
      genre: genre.value,
    );
    _save();
  }

  void _save() {
    final sorted = _byName.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    _file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({'fits': sorted.map((entry) => entry.toJson()).toList()})}\n',
    );
  }
}

// ---------------------------------------------------------------------------
// Local server
// ---------------------------------------------------------------------------

Future<void> _serve(_TagSession session, _Options options) async {
  final server = await HttpServer.bind(
    InternetAddress.loopbackIPv4,
    options.port,
  );

  final address = 'http://localhost:${server.port}';
  stdout.writeln(
    '\nTagger running at $address\n'
    '  ${session.queue.length} photos to go, '
    '${session.owners.length} owners in rotation\n'
    'Press 1-6 to pick a genre, S to skip, and Done when finished '
    '(or Ctrl-C here).\n',
  );

  if (options.openBrowser) {
    await Process.run('open', [
      address,
    ]).catchError((_) => ProcessResult(0, 0, '', ''));
  }

  final finished = Completer<void>();

  server.listen((request) async {
    try {
      await _route(request, session, finished);
    } catch (error) {
      stderr.writeln('  ! ${request.uri.path}: $error');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await _writeJson(request.response, {'error': '$error'});
      } catch (_) {
        // The response was already sent or closed; the log above is all the
        // caller gets.
      }
    }
  });

  await finished.future;
  await server.close(force: true);

  await _report(session);
}

Future<void> _route(
  HttpRequest request,
  _TagSession session,
  Completer<void> finished,
) async {
  final path = request.uri.path;

  if (request.method == 'GET' && (path == '/' || path == '/index.html')) {
    request.response.headers.contentType = ContentType.html;
    request.response.write(_pageHtml(session));
    await request.response.close();
    return;
  }

  if (request.method == 'GET' && path == '/api/photo') {
    final name = request.uri.queryParameters['name'];
    final photo = name == null ? null : session.photoNamed(name);

    if (photo == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    request.response.headers.contentType = ContentType.parse(photo.contentType);
    request.response.add(photo.file.readAsBytesSync());
    await request.response.close();
    return;
  }

  if (request.method == 'POST' && path == '/api/tag') {
    final body =
        jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>;
    final photo = session.photoNamed(body['name'] as String);
    final genre = FitGenre.fromValue(body['genre'] as String?);

    if (photo == null || genre == null) {
      request.response.statusCode = HttpStatus.badRequest;
      await _writeJson(request.response, {'error': 'unknown photo or genre'});
      return;
    }

    final result = await session.tag(photo, genre);
    stdout.writeln(
      '  ${result.retagged ? '~' : '+'} ${photo.name} → ${genre.label}'
      '${result.owner == null ? '' : ' · ${result.owner!.atHandle}'}',
    );

    await _writeJson(request.response, {
      'ok': true,
      'retagged': result.retagged,
      'owner': result.owner?.atHandle,
    });
    return;
  }

  if (request.method == 'POST' && path == '/api/quit') {
    await _writeJson(request.response, {'ok': true});
    if (!finished.isCompleted) finished.complete();
    return;
  }

  request.response.statusCode = HttpStatus.notFound;
  await request.response.close();
}

Future<void> _writeJson(HttpResponse response, Object body) async {
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
  await response.close();
}

Future<void> _report(_TagSession session) async {
  final Map<FitGenre, _GenreTally> tallies;
  try {
    tallies = await session.tally();
  } catch (error) {
    stderr.writeln('\nCould not read the arena back: $error');
    return;
  }

  stdout.writeln('\nIn the arena:');
  for (final genre in FitGenre.values) {
    final tally = tallies[genre];
    if (tally == null) continue;
    stdout.writeln(
      '  ${genre.label.padRight(12)} ${tally.fits.toString().padLeft(3)} '
      '${tally.fits == 1 ? 'fit ' : 'fits'} from ${tally.owners.length} '
      '${tally.owners.length == 1 ? 'owner' : 'owners'}',
    );
  }

  final stuck = tallies.entries
      .where((entry) => !entry.value.canMatch)
      .map((entry) => entry.key.label)
      .toList();

  if (stuck.isNotEmpty) {
    stdout.writeln(
      '\n! ${stuck.join(', ')} ${stuck.length == 1 ? 'holds' : 'hold'} fits '
      'from a single owner, so ${stuck.length == 1 ? 'it produces' : 'they '
                'produce'} no matchups.\n'
      '  Tag more photos into ${stuck.length == 1 ? 'it' : 'them'} — the tool '
      'spreads a genre across owners as it fills.',
    );
  }

  final empty = FitGenre.values
      .where((genre) => !tallies.containsKey(genre))
      .map((genre) => genre.label)
      .toList();

  if (empty.isNotEmpty) {
    stdout.writeln('\nNothing tagged yet in: ${empty.join(', ')}.');
  }

  stdout.writeln(
    '\nSign in with your own account and the arena will pair these for you.',
  );
}

// ---------------------------------------------------------------------------
// The page
// ---------------------------------------------------------------------------

String _pageHtml(_TagSession session) {
  final photos = jsonEncode(
    session.queue
        .map(
          (photo) => {
            'name': photo.name,
            'genre': session.manifest.entryFor(photo.name)?.genre,
          },
        )
        .toList(),
  );

  final genres = jsonEncode(
    FitGenre.values
        .map(
          (genre) => {
            'value': genre.value,
            'label': genre.label,
            'description': genre.description,
          },
        )
        .toList(),
  );

  // Colours and type mirror the app's dark theme, so a genre judged here looks
  // the way it will look in the arena.
  return '''
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>VERSED — tag fits</title>
<style>
  :root {
    --canvas: #0A0A0A;
    --surface: #1C1C1E;
    --divider: #2C2C2E;
    --text: #FFFFFF;
    --secondary: #8E8E93;
    --error: #FF453A;
    --success: #30D158;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    background: var(--canvas);
    color: var(--text);
    font: 15px/1.4 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    display: flex;
    flex-direction: column;
    align-items: center;
    /* Everything has to be reachable without scrolling: tagging is a rhythm
       of look-then-press, and a genre button below the fold breaks it. The
       photo is the only flexible element, so it absorbs the difference. */
    height: 100vh;
    overflow: hidden;
    padding: 16px 16px 20px;
    gap: 12px;
  }
  header {
    display: flex;
    align-items: baseline;
    gap: 12px;
    width: 100%;
    max-width: 520px;
  }
  .wordmark { font-weight: 800; letter-spacing: .18em; font-size: 13px; }
  .progress { color: var(--secondary); font-size: 13px; margin-left: auto; }
  .name {
    color: var(--secondary);
    font-size: 13px;
    font-variant-numeric: tabular-nums;
  }
  .stage-wrap {
    flex: 1 1 auto;
    min-height: 0;
    width: 100%;
    display: flex;
    justify-content: center;
  }
  .stage {
    position: relative;
    height: 100%;
    max-height: 100%;
    max-width: min(520px, 100%);
    /* The arena crops to 4:5, so the frame does too — a fit judged here is
       framed the way voters will see it. */
    aspect-ratio: 4 / 5;
    background: var(--surface);
    border: 1px solid var(--divider);
    border-radius: 8px;
    overflow: hidden;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .stage img { width: 100%; height: 100%; object-fit: cover; }
  .badge {
    position: absolute;
    top: 10px;
    left: 10px;
    background: rgba(10,10,10,.82);
    border: 1px solid var(--divider);
    border-radius: 6px;
    padding: 5px 9px;
    font-size: 12px;
    letter-spacing: .06em;
    text-transform: uppercase;
  }
  .genres {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 8px;
    width: 100%;
    max-width: 520px;
  }
  button {
    font: inherit;
    color: var(--text);
    background: var(--surface);
    border: 1px solid var(--divider);
    border-radius: 8px;
    padding: 11px 8px;
    cursor: pointer;
    text-align: center;
  }
  button:hover:not(:disabled) { border-color: var(--secondary); }
  button:disabled { opacity: .4; cursor: default; }
  button.current { background: #FFFFFF; color: #000000; border-color: #fff; }
  .key {
    display: block;
    font-size: 11px;
    color: var(--secondary);
    margin-top: 2px;
  }
  button.current .key { color: #000; opacity: .55; }
  .controls {
    display: flex;
    gap: 8px;
    width: 100%;
    max-width: 520px;
  }
  .controls button { flex: 1; }
  .hint, .status {
    max-width: 520px;
    width: 100%;
    color: var(--secondary);
    font-size: 13px;
    min-height: 18px;
  }
  /* A Postgres or storage error can be long. Clamp it so a failure never
     pushes the buttons off the page — the terminal has it in full. */
  .status {
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  .status.error { color: var(--error); }
  .status.ok { color: var(--success); }
  .done { text-align: center; padding: 40px 0; }
  .done h1 { font-size: 20px; margin: 0 0 8px; }
</style>
</head>
<body>
<header>
  <span class="wordmark">VERSED</span>
  <span class="name" id="name"></span>
  <span class="progress" id="progress"></span>
</header>

<div class="stage-wrap">
  <div class="stage" id="stage">
    <img id="photo" alt="">
    <span class="badge" id="badge" hidden></span>
  </div>
</div>

<div class="hint" id="hint"></div>
<div class="genres" id="genres"></div>
<div class="controls">
  <button id="back">← Back</button>
  <button id="skip">Skip (S)</button>
  <button id="quit">Done</button>
</div>
<div class="status" id="status"></div>

<script>
const photos = $photos;
const genres = $genres;

let index = 0;
let busy = false;

const el = (id) => document.getElementById(id);

genres.forEach((genre, position) => {
  const button = document.createElement('button');
  button.innerHTML =
    genre.label + '<span class="key">' + (position + 1) + '</span>';
  button.title = genre.description;
  button.onclick = () => tag(genre);
  el('genres').appendChild(button);
});

function render() {
  if (index >= photos.length) return finish();

  const photo = photos[index];
  el('photo').src = '/api/photo?name=' + encodeURIComponent(photo.name);
  el('photo').alt = photo.name;
  el('name').textContent = photo.name;
  el('progress').textContent = (index + 1) + ' / ' + photos.length;

  const current = genres.find((genre) => genre.value === photo.genre);
  el('badge').hidden = !current;
  if (current) el('badge').textContent = 'in arena · ' + current.label;
  el('hint').textContent = current
    ? 'Already entered — pick a genre to move it.'
    : 'Which genre does this outfit belong to?';

  [...el('genres').children].forEach((button, position) => {
    button.classList.toggle('current', genres[position].value === photo.genre);
    button.disabled = busy;
  });
  el('back').disabled = busy || index === 0;
  el('skip').disabled = busy;

  // Warms the next photo so it does not flash in blank after a tag.
  if (index + 1 < photos.length) {
    new Image().src =
      '/api/photo?name=' + encodeURIComponent(photos[index + 1].name);
  }
}

function status(message, kind) {
  el('status').textContent = message;
  el('status').className = 'status' + (kind ? ' ' + kind : '');
}

async function tag(genre) {
  if (busy) return;
  const photo = photos[index];

  busy = true;
  render();
  status('Uploading ' + photo.name + '…');

  try {
    const response = await fetch('/api/tag', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ name: photo.name, genre: genre.value }),
    });
    const result = await response.json();
    if (!response.ok || result.error) throw new Error(result.error || 'failed');

    photo.genre = genre.value;
    status(
      photo.name + (result.retagged ? ' moved to ' : ' entered as ') +
        genre.label + (result.owner ? ' for ' + result.owner : ''),
      'ok'
    );
    busy = false;
    index++;
  } catch (error) {
    // The photo stays on screen: nothing was entered, so it still needs a
    // decision (or a skip).
    busy = false;
    status(photo.name + ' failed — ' + error.message, 'error');
  }

  render();
}

el('skip').onclick = () => { if (!busy) { index++; status(''); render(); } };
el('back').onclick = () => {
  if (!busy && index > 0) { index--; status(''); render(); }
};
el('quit').onclick = finish;

document.addEventListener('keydown', (event) => {
  if (busy) return;
  const position = Number(event.key);
  if (position >= 1 && position <= genres.length) {
    tag(genres[position - 1]);
  } else if (event.key.toLowerCase() === 's') {
    el('skip').click();
  } else if (event.key === 'ArrowLeft') {
    el('back').click();
  }
});

async function finish() {
  await fetch('/api/quit', { method: 'POST' }).catch(() => {});
  const tagged = photos.filter((photo) => photo.genre).length;
  document.body.innerHTML =
    '<div class="done"><h1>Done — ' + tagged + ' of ' + photos.length +
    ' tagged.</h1><p class="hint">The tool has stopped. Check the terminal ' +
    'for the per-genre breakdown, then close this tab.</p></div>';
}

render();
</script>
</body>
</html>
''';
}

// ---------------------------------------------------------------------------
// Options
// ---------------------------------------------------------------------------

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}

class _Options {
  _Options({
    required this.imageDirectory,
    required this.ownerCount,
    required this.port,
    required this.includeAll,
    required this.openBrowser,
  });

  factory _Options.parse(List<String> args) {
    var imageDirectory = 'assets/auth';
    var ownerCount = 6;
    var port = 8787;
    var includeAll = false;
    var openBrowser = true;

    for (var index = 0; index < args.length; index++) {
      switch (args[index]) {
        case '--images':
          imageDirectory = args[++index];
        case '--owners':
          ownerCount = int.parse(args[++index]);
        case '--port':
          port = int.parse(args[++index]);
        case '--all':
          includeAll = true;
        case '--no-open':
          openBrowser = false;
        default:
          _fail('Unknown argument: ${args[index]}');
      }
    }

    if (ownerCount < 2) {
      _fail(
        '--owners must be at least 2: a battle is between two people, so a '
        'genre owned by one account produces no matchups.',
      );
    }

    return _Options(
      imageDirectory: imageDirectory,
      ownerCount: ownerCount,
      port: port,
      includeAll: includeAll,
      openBrowser: openBrowser,
    );
  }

  final String imageDirectory;
  final int ownerCount;
  final int port;
  final bool includeAll;
  final bool openBrowser;
}
