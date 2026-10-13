import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:wonky_client/wonky_client.dart';

import '../data/collab_repositories.dart';

/// State of the notifications popover (suite 07 §4): the loaded page(s),
/// the unread count, the All/Unread filter and paging. Live events from
/// `notification.watch` are fed in with [onEvent].
class NotificationsController extends ChangeNotifier {
  NotificationsController(this._repo, {this.pageSize = 30});

  final NotificationRepository _repo;
  final int pageSize;

  List<NotificationView> _items = const [];
  int _unread = 0;
  bool _unreadOnly = false;
  bool _loading = false;
  bool _loadingMore = false;
  Object? _error;
  String? _cursor;
  int _generation = 0;

  List<NotificationView> get items => _items;
  int get unreadCount => _unread;
  bool get unreadOnly => _unreadOnly;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  Object? get error => _error;
  bool get hasMore => _cursor != null;

  /// Loads the first page (again).
  Future<void> load() async {
    final gen = ++_generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await _repo.list(limit: pageSize, unreadOnly: _unreadOnly);
      if (gen != _generation) return;
      _items = page.items;
      _unread = page.unreadCount;
      _cursor = page.nextCursor;
    } catch (e) {
      if (gen == _generation) _error = e;
    } finally {
      if (gen == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Appends the next page.
  Future<void> loadMore() async {
    final cursor = _cursor;
    if (cursor == null || _loadingMore) return;
    final gen = _generation;
    _loadingMore = true;
    notifyListeners();
    try {
      final page = await _repo.list(
        cursor: cursor,
        limit: pageSize,
        unreadOnly: _unreadOnly,
      );
      if (gen != _generation) return;
      final known = {for (final n in _items) n.id};
      _items = [
        ..._items,
        for (final n in page.items)
          if (!known.contains(n.id)) n,
      ];
      _unread = page.unreadCount;
      _cursor = page.nextCursor;
    } catch (e) {
      _error = e;
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  /// Switches between all and unread notifications.
  Future<void> setUnreadOnly(bool value) async {
    if (value == _unreadOnly) return;
    _unreadOnly = value;
    await load();
  }

  /// Marks [n] read (optimistically; the server is told in the background).
  Future<void> markRead(NotificationView n) async {
    if (n.readAt != null) return;
    final now = clock.now();
    _items = [
      for (final x in _items) x.id == n.id ? x.copyWith(readAt: now) : x,
    ];
    _unread = (_unread - 1).clamp(0, 0x3FFFFFFF);
    notifyListeners();
    try {
      await _repo.markRead([n.id]);
    } catch (_) {
      // The next load shows the server state.
    }
  }

  Future<void> markAllRead() async {
    final now = clock.now();
    final beforeItems = _items;
    final beforeUnread = _unread;
    _items = [for (final x in _items) x.copyWith(readAt: x.readAt ?? now)];
    _unread = 0;
    notifyListeners();
    try {
      await _repo.markAllRead();
    } catch (e) {
      _items = beforeItems;
      _unread = beforeUnread;
      _error = e;
      notifyListeners();
    }
  }

  /// A live event: a new notification and/or a new unread count.
  void onEvent(NotificationEvent e) {
    _unread = e.unreadCount;
    final n = e.notification;
    if (n != null && !_items.any((x) => x.id == n.id)) {
      _items = [n, ..._items];
    }
    notifyListeners();
  }
}
