import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';

/// A drive that fails like the network while [offline].
class _Network implements DriveRepository {
  _Network(this.inner);

  final FakeDriveRepository inner;
  bool offline = false;
  final List<String> calls = [];

  Future<T> _net<T>(String name, Future<T> Function() f) async {
    if (offline) throw const OfflineException('offline');
    calls.add(name);
    return f();
  }

  @override
  Future<DriveItemView> get(UuidValue uuid) =>
      _net('get', () => inner.get(uuid));

  @override
  Future<DriveItemView> rename(UuidValue uuid, String name) =>
      _net('rename', () => inner.rename(uuid, name));

  @override
  Future<DriveItemView> setStarred(UuidValue uuid, bool starred) =>
      _net('setStarred', () => inner.setStarred(uuid, starred));

  @override
  Future<void> trash(List<UuidValue> uuids) =>
      _net('trash', () => inner.trash(uuids));

  @override
  Future<DriveItemView> createDocument({
    UuidValue? parentUuid,
    required String name,
    UuidValue? templateUuid,
    String? initialMarkdown,
    UuidValue? documentUuid,
    UuidValue? itemUuid,
  }) => _net('createDocument', () async {
    if (parentUuid != null) {
      inner.item(parentUuid); // throws FakeNotFound for a missing folder
    }
    return inner.createDocument(
      parentUuid: parentUuid,
      name: name,
      documentUuid: documentUuid,
      itemUuid: itemUuid,
    );
  });

  @override
  Future<DriveItemView> registerPresentation({
    required UuidValue spaceUuid,
    UuidValue? parentUuid,
    required String name,
  }) => _net('registerPresentation', () async {
    if (parentUuid != null) inner.item(parentUuid);
    return inner.registerPresentation(
      spaceUuid: spaceUuid,
      parentUuid: parentUuid,
      name: name,
    );
  });

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late MemoryStore store;
  late FakeDriveRepository server;
  late _Network network;
  late ConnectivityService connectivity;
  UserSummary? me;

  CachedDriveRepository repo() => CachedDriveRepository(
    remote: network,
    cache: DriveCache(store),
    queue: PendingDriveOpQueue(store),
    connectivity: connectivity,
    currentUser: () => me,
  );

  setUp(() {
    store = MemoryStore();
    server = FakeDriveRepository();
    network = _Network(server);
    connectivity = ConnectivityService(ping: () async {});
    me = TestUsers.anna;
  });

  tearDown(() => Api.simulatedOffline = false);

  test('when offline then reads come from the cache without a call', () async {
    final item = server.seed(name: 'Plan');
    final r = repo();
    await r.init();
    await r.get(item.uuid);
    connectivity.forceOffline(true);
    network.calls.clear();
    final cached = await r.get(item.uuid);
    expect(cached.name, 'Plan');
    expect(network.calls, isEmpty);
    expect(
      () => r.get(UuidValue.fromString('00000000-0000-7000-8000-00000000beef')),
      throwsA(isA<OfflineException>()),
    );
  });

  test(
    'when queued operations replay after a restart then they run in order',
    () async {
      final a = server.seed(name: 'A');
      final r = repo();
      await r.init();
      await r.get(a.uuid);
      connectivity.forceOffline(true);
      network.offline = true;
      await r.rename(a.uuid, 'A2');
      await r.setStarred(a.uuid, true);
      await r.trash([a.uuid]);
      expect(r.pendingCount, 3);
      await r.cache.save();
      r.dispose();

      // Restart.
      final r2 = repo();
      await r2.init();
      expect(r2.pendingCount, 3);
      expect(r2.cache.item(a.uuid)!.name, 'A2');
      network.offline = false;
      connectivity.forceOffline(false);
      while (r2.pendingCount > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(network.calls.where((c) => c != 'get'), [
        'rename',
        'setStarred',
        'trash',
      ]);
      expect(server.item(a.uuid).name, 'A2');
      expect(server.item(a.uuid).starred, isTrue);
    },
  );

  test('when another user signs in then they see their own cache', () async {
    final a = server.seed(name: 'Anna’s');
    final r = repo();
    await r.init();
    await r.get(a.uuid);
    await r.cache.save();
    me = TestUsers.summary(id: 2, displayName: 'Bob');
    final r2 = repo();
    await r2.init();
    expect(r2.cache.item(a.uuid), isNull);
    me = TestUsers.anna;
    final r3 = repo();
    await r3.init();
    expect(r3.cache.item(a.uuid), isNotNull);
  });

  test('when a document created offline replays into a deleted folder then it '
      'is created in My Drive', () async {
    final r = repo();
    await r.init();
    connectivity.forceOffline(true);
    final created = await r.createDocument(
      parentUuid: UuidValue.fromString('00000000-0000-7000-8000-00000000dead'),
      name: 'Notes',
    );
    expect(r.isPendingCreate(created.uuid), isTrue);
    connectivity.forceOffline(false);
    await Future<void>.delayed(Duration.zero);
    await r.replay();
    expect(r.isPendingCreate(created.uuid), isFalse);
    final v = server.item(created.uuid);
    expect(v.name, 'Notes');
    expect(v.parentUuid, isNull);
    expect(v.contentRef, created.contentRef);
  });

  test('when a presentation created offline is registered then the item is '
      'optimistic, queued, and replays with the space as item uuid (into My '
      'Drive when its folder is gone)', () async {
    final r = repo();
    await r.init();
    connectivity.forceOffline(true);
    final space = UuidValue.fromString('0190a000-0000-7000-8000-0000000000d7');

    final local = await r.registerPresentation(
      spaceUuid: space,
      parentUuid: UuidValue.fromString('00000000-0000-7000-8000-00000000dead'),
      name: 'Pitch',
    );
    expect(local.uuid, space);
    expect(local.kind, DriveItemKind.presentation);
    expect(r.isPendingCreate(space), isTrue);
    expect(network.calls, isNot(contains('registerPresentation')));

    connectivity.forceOffline(false);
    await Future<void>.delayed(Duration.zero);
    await r.replay();

    expect(r.isPendingCreate(space), isFalse);
    final v = server.item(space);
    expect(v.name, 'Pitch');
    expect(v.contentRef, space);
    expect(v.parentUuid, isNull);
  });
}
