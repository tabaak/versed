import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:versed/core/services/storage_service.dart';
import 'package:versed/features/auth/controllers/auth_controller.dart';
import 'package:versed/features/auth/models/auth_model.dart';
import 'package:versed/features/fits/models/fit.dart';
import 'package:versed/features/fits/services/fit_service.dart';
import 'package:versed/features/profile/models/profile_model.dart';
import 'package:versed/features/profile/presentation/pages/public_profile_page.dart';
import 'package:versed/features/profile/services/profile_service.dart';

class _FakeAuthController extends AuthController {
  @override
  Future<AuthModel?> build() async => const AuthModel(
    id: 'me',
    email: 'ada@example.com',
    displayName: 'Ada Lovelace',
    avatarUrl: null,
  );
}

/// Serves one profile and its record. A null [profile] stands for an account
/// that is gone, which is the case the page has to name rather than blame on
/// the network.
class _FakeProfileService implements ProfileService {
  _FakeProfileService({this.profile, this.stats = ProfileStats.empty});

  final Profile? profile;
  final ProfileStats stats;

  @override
  Future<Profile?> fetchProfileById(String id) async => profile;

  @override
  Future<ProfileStats> fetchStats(String id) async => stats;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeFitService implements FitService {
  _FakeFitService(this.fits);

  final List<Fit> fits;

  /// The ids the page asked for, so a test can assert it read the profile it
  /// was pushed for rather than the signed-in user's.
  final List<String> requestedOwners = [];

  @override
  Future<List<Fit>> fetchOwnedBy(String ownerId) async {
    requestedOwners.add(ownerId);
    return fits;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// The grid only ever turns a path into a URL; the photos never load in a
/// test.
class _FakeStorageService implements StorageService {
  @override
  String fitImageUrl(String path) => 'https://cdn.test/fits/$path';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

final _nova = Profile.empty.copyWith(
  id: 'nova',
  username: 'nova',
  displayName: 'Nova',
  createdAt: DateTime.utc(2026, 3, 1),
);

final _novaFit = Fit.empty.copyWith(
  id: 'fit-1',
  ownerId: 'nova',
  imagePath: 'nova/one.jpg',
  wins: 3,
  losses: 1,
);

Future<_FakeFitService> _pumpProfile(
  WidgetTester tester, {
  Profile? profile,
  ProfileStats stats = ProfileStats.empty,
  List<Fit> fits = const [],
  String userId = 'nova',
}) async {
  final fitService = _FakeFitService(fits);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_FakeAuthController.new),
        storageServiceProvider.overrideWithValue(_FakeStorageService()),
        profileServiceProvider.overrideWithValue(
          _FakeProfileService(profile: profile, stats: stats),
        ),
        fitServiceProvider.overrideWithValue(fitService),
      ],
      child: CupertinoApp(home: PublicProfilePage(userId: userId)),
    ),
  );

  await tester.pumpAndSettle();
  return fitService;
}

void main() {
  testWidgets('shows the visited profile, not the signed-in one', (
    tester,
  ) async {
    final fitService = await _pumpProfile(tester, profile: _nova);

    expect(find.text('Nova'), findsOneWidget);
    // Once in the title bar, once in the header.
    expect(find.text('@nova'), findsNWidgets(2));
    expect(find.text('Ada Lovelace'), findsNothing);
    expect(fitService.requestedOwners, ['nova']);
  });

  testWidgets('shows their battle record', (tester) async {
    await _pumpProfile(
      tester,
      profile: _nova,
      stats: const ProfileStats(wins: 9, losses: 3, bestStreak: 4),
    );

    expect(find.text('9'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('offers no way to edit someone else\'s profile', (tester) async {
    await _pumpProfile(tester, profile: _nova);

    expect(find.text('Edit profile'), findsNothing);
  });

  testWidgets('shows their fits', (tester) async {
    await _pumpProfile(tester, profile: _nova, fits: [_novaFit]);

    expect(find.text('Fits'), findsOneWidget);
    // 3 wins from 4 battles.
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('No fits yet'), findsNothing);
  });

  testWidgets('says so when they have nothing in the arena', (tester) async {
    await _pumpProfile(tester, profile: _nova);

    expect(find.text('No fits yet'), findsOneWidget);
  });

  testWidgets('names a profile that is no longer there', (tester) async {
    await _pumpProfile(tester);

    expect(find.text('Profile unavailable'), findsOneWidget);
    expect(find.text('This account is no longer around.'), findsOneWidget);
    // Retrying cannot bring a deleted account back, so nothing offers to.
    expect(find.text('Try again'), findsNothing);
  });
}
