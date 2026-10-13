import 'package:flutter/foundation.dart';
import 'package:wonky_client/wonky_client.dart';

import '../data/collab_repositories.dart';

/// State of the activity dashboard dialog (suite 07 §6): the dashboard for
/// the selected period and the caller's "Show my view history" toggle.
class ActivityDashboardController extends ChangeNotifier {
  ActivityDashboardController(this._repo, this.itemUuid, {int days = 28})
    : _days = days; // ignore: prefer_initializing_formals

  /// The selectable periods in days.
  static const periods = [7, 28, 90];

  final ActivityRepository _repo;
  final UuidValue itemUuid;

  int _days;
  ActivityDashboard? _dashboard;
  bool _loading = false;
  Object? _error;
  bool? _showViewHistory;
  bool _savingSetting = false;
  Object? _settingError;
  int _generation = 0;
  bool _disposed = false;

  @override
  void notifyListeners() {
    // Requests finish after the popover/dialog closed.
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  int get days => _days;
  ActivityDashboard? get dashboard => _dashboard;
  bool get loading => _loading;
  Object? get error => _error;
  bool get savingSetting => _savingSetting;
  Object? get settingError => _settingError;

  /// The caller's setting (from the dashboard until changed here).
  bool get showViewHistory =>
      _showViewHistory ?? _dashboard?.showMyViewHistory ?? true;

  Future<void> load() async {
    final gen = ++_generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final d = await _repo.dashboard(itemUuid, days: _days);
      if (gen != _generation) return;
      _dashboard = d;
    } catch (e) {
      if (gen == _generation) _error = e;
    } finally {
      if (gen == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> setDays(int days) async {
    if (days == _days) return;
    _days = days;
    await load();
  }

  /// Turns "Show my view history" on or off; reverts on failure.
  Future<void> setShowViewHistory(bool show) async {
    final before = showViewHistory;
    _showViewHistory = show;
    _savingSetting = true;
    _settingError = null;
    notifyListeners();
    try {
      _showViewHistory = await _repo.setShowViewHistory(show);
    } catch (e) {
      _showViewHistory = before;
      _settingError = e;
    } finally {
      _savingSetting = false;
      notifyListeners();
    }
  }
}
