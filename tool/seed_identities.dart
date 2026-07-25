// The throwaway accounts both development tools put fits on, and the handles
// they wear.
//
// Handles matter more than they look like they should: the arena shows a fit's
// owner, so `arena_seed_48213_0` tells anyone using the app that they are
// judging filler. These read like people instead, while the accounts stay
// recognisable to the tooling through their `@versed-seed.invalid` email —
// `.invalid` is reserved by RFC 2606 and can never belong to a real person,
// which is what makes `seed_arena --clean` safe.
//
// Nothing in the app exposes an account's email, so a plausible handle and a
// reserved address are not in tension.

import 'dart:convert';
import 'dart:math';

import 'package:supabase/supabase.dart';

/// Every synthetic account uses this domain, and it is the only thing that
/// identifies one. Never change it without updating `seed_arena --clean`.
const seedEmailDomain = 'versed-seed.invalid';

/// Handles the tools used before identities became plausible. Accounts wearing
/// one are renamed on sight rather than left looking like bots.
const legacySeedHandlePrefix = 'arena_seed_';

final _random = Random();

/// A handle and the name shown beside it.
///
/// Handles obey `profiles_username_format`: 3–20 characters of lowercase
/// letters, digits and underscores. Deliberately uneven — some full names, some
/// clipped, some with a number — because a column of `first_last` handles is
/// its own kind of tell.
class SeedIdentity {
  const SeedIdentity(this.handle, this.displayName);

  final String handle;
  final String displayName;
}

const seedIdentities = <SeedIdentity>[
  SeedIdentity('novareyes', 'Nova Reyes'),
  SeedIdentity('kit_alvarez', 'Kit Alvarez'),
  SeedIdentity('junoparked', 'Juno Park'),
  SeedIdentity('remy_okafor', 'Remy Okafor'),
  SeedIdentity('sashalq', 'Sasha Lindqvist'),
  SeedIdentity('theomarchetti', 'Theo Marchetti'),
  SeedIdentity('wren_c', 'Wren Castillo'),
  SeedIdentity('idrisbello', 'Idris Bello'),
  SeedIdentity('mika_tnk', 'Mika Tanaka'),
  SeedIdentity('liorbenari', 'Lior Ben-Ari'),
  SeedIdentity('priya_raman', 'Priya Raman'),
  SeedIdentity('daxfer', 'Dax Ferreira'),
  SeedIdentity('ellisvane', 'Ellis Vane'),
  SeedIdentity('noor_haddad', 'Noor Haddad'),
  SeedIdentity('tobiaskrag', 'Tobias Krag'),
  SeedIdentity('inesmartel', 'Inés Martel'),
  SeedIdentity('yuki_ando', 'Yuki Ando'),
  SeedIdentity('samirbenz', 'Samir Benzid'),
  SeedIdentity('marlowe22', 'Marlowe Quinn'),
  SeedIdentity('adaokonkwo', 'Ada Okonkwo'),
  SeedIdentity('feliceb', 'Felice Bianchi'),
  SeedIdentity('rune_dahl', 'Rune Dahl'),
  SeedIdentity('tashaobrien', 'Tasha O\'Brien'),
  SeedIdentity('kaimoreau', 'Kai Moreau'),
  SeedIdentity('zaravlk', 'Zara Vlk'),
  SeedIdentity('ottoberg', 'Otto Berg'),
  SeedIdentity('leni_soto', 'Leni Soto'),
  SeedIdentity('hugoward', 'Hugo Ward'),
  SeedIdentity('mirenaoki', 'Miren Aoki'),
  SeedIdentity('cassreid', 'Cass Reid'),
];

/// One of the throwaway accounts, with what the arena will show for it.
class SeedOwner {
  SeedOwner({
    required this.id,
    required this.handle,
    required this.displayName,
  });

  final String id;
  final String handle;
  final String displayName;

  String get atHandle => '@$handle';
}

/// Handles already in use, so a new account never collides with a real user's
/// or with an account an earlier run created.
Future<Set<String>> fetchTakenHandles(SupabaseClient client) async {
  final rows = await client.from('profiles').select('username');

  return {
    for (final row in rows)
      if (row['username'] != null) row['username'] as String,
  };
}

/// Picks a free handle, adding a numeric suffix if every identity in the pool
/// is spoken for. [taken] is updated so consecutive calls cannot collide.
SeedIdentity claimIdentity(Set<String> taken) {
  final free = seedIdentities
      .where((identity) => !taken.contains(identity.handle))
      .toList();

  if (free.isNotEmpty) {
    final identity = free[_random.nextInt(free.length)];
    taken.add(identity.handle);
    return identity;
  }

  // Pool exhausted: reuse a name under a numbered handle. `mika_tnk2` still
  // reads like a person who found their first choice was gone.
  final base = seedIdentities[_random.nextInt(seedIdentities.length)];
  for (var suffix = 2; suffix < 1000; suffix++) {
    final trimmed = base.handle.substring(
      0,
      min(base.handle.length, 20 - '$suffix'.length),
    );
    final handle = '$trimmed$suffix';
    if (!taken.contains(handle)) {
      taken.add(handle);
      return SeedIdentity(handle, base.displayName);
    }
  }

  throw StateError('Could not find a free handle for ${base.handle}.');
}

/// Creates one throwaway account and gives its profile a handle and a name.
///
/// Returns null when the account could not be created, so callers can carry on
/// with the owners they have.
Future<SeedOwner?> createSeedOwner(
  SupabaseClient client, {
  required Set<String> taken,
}) async {
  final identity = claimIdentity(taken);

  final response = await client.auth.admin.createUser(
    AdminUserAttributes(
      email: '${identity.handle}@$seedEmailDomain',
      password: randomSeedPassword(),
      emailConfirm: true,
      userMetadata: {'full_name': identity.displayName},
    ),
  );

  final user = response.user;
  if (user == null) return null;

  // The on_auth_user_created trigger already made the profile row and copied
  // the name out of the metadata; it just has no handle, because Google
  // sign-in never supplies one either.
  await client
      .from('profiles')
      .update({
        'username': identity.handle,
        'display_name': identity.displayName,
      })
      .eq('id', user.id);

  return SeedOwner(
    id: user.id,
    handle: identity.handle,
    displayName: identity.displayName,
  );
}

/// Returns [count] throwaway accounts, reusing the ones earlier runs created
/// and topping up the difference.
///
/// Accounts still wearing a `arena_seed_*` handle from before the identity pool
/// existed are renamed as they are picked up, so an arena filled months ago
/// stops advertising itself.
Future<List<SeedOwner>> ensureSeedOwners(
  SupabaseClient client,
  int count, {
  void Function(String message)? log,
}) async {
  final report = log ?? (message) {};

  final users = await client.auth.admin.listUsers(perPage: 1000);
  final seededIds = users
      .where((user) => user.email?.endsWith('@$seedEmailDomain') ?? false)
      .map((user) => user.id)
      .toList();

  final taken = await fetchTakenHandles(client);
  final owners = <SeedOwner>[];

  if (seededIds.isNotEmpty) {
    final rows = await client
        .from('profiles')
        .select('id, username, display_name')
        .inFilter('id', seededIds);

    for (final row in rows.take(count)) {
      final id = row['id'] as String;
      final handle = row['username'] as String?;
      final displayName = row['display_name'] as String?;

      final isLegacy =
          handle == null || handle.startsWith(legacySeedHandlePrefix);

      if (!isLegacy) {
        owners.add(
          SeedOwner(id: id, handle: handle, displayName: displayName ?? handle),
        );
        continue;
      }

      if (handle != null) taken.remove(handle);
      final identity = claimIdentity(taken);

      await client
          .from('profiles')
          .update({
            'username': identity.handle,
            'display_name': identity.displayName,
          })
          .eq('id', id);

      report('  ~ ${handle ?? '(no handle)'} → @${identity.handle}');
      owners.add(
        SeedOwner(
          id: id,
          handle: identity.handle,
          displayName: identity.displayName,
        ),
      );
    }

    report('Reusing ${owners.length} existing test accounts.');
  }

  while (owners.length < count) {
    final owner = await createSeedOwner(client, taken: taken);
    if (owner == null) {
      break;
    }

    owners.add(owner);
    report('  + ${owner.atHandle}');
  }

  return owners;
}

String randomSeedPassword() {
  final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
  return base64Url.encode(bytes);
}
