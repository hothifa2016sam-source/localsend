import 'dart:async';

import 'package:localsend_app/model/persistence/send_history_entry.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Stores outgoing transfer history locally with configurable retention.
final sendHistoryProvider = ReduxProvider<SendHistoryService, List<SendHistoryEntry>>((ref) {
  return SendHistoryService(ref.read(persistenceProvider));
});

class SendHistoryService extends ReduxNotifier<List<SendHistoryEntry>> {
  final PersistenceService _persistence;

  SendHistoryService(this._persistence);

  @override
  List<SendHistoryEntry> init() {
    final stored = _persistence.getSendHistory();
    final cleaned = _removeExpired(stored);
    if (cleaned.length != stored.length) {
      // Clean expired records on startup as well as when new transfers are recorded.
      unawaited(_persistence.setSendHistory(cleaned));
    }
    return cleaned;
  }

  List<SendHistoryEntry> _removeExpired(Iterable<SendHistoryEntry> entries) {
    final days = _persistence.getSendHistoryRetentionDays();
    final cutoff = days == 0 ? null : DateTime.now().toUtc().subtract(Duration(days: days));
    final result = entries.where((entry) => cutoff == null || !entry.timestamp.isBefore(cutoff)).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return result;
  }
}

/// Adds or updates the history records for files in a completed send session.
class AddSendHistoryEntriesAction extends AsyncReduxAction<SendHistoryService, List<SendHistoryEntry>> {
  final List<SendHistoryEntry> entries;

  AddSendHistoryEntriesAction(this.entries);

  @override
  Future<List<SendHistoryEntry>> reduce() async {
    final byId = <String, SendHistoryEntry>{
      for (final entry in state) entry.id: entry,
      for (final entry in entries) entry.id: entry,
    };
    final days = notifier._persistence.getSendHistoryRetentionDays();
    final cutoff = days == 0 ? null : DateTime.now().toUtc().subtract(Duration(days: days));
    final updated = byId.values.where((entry) => cutoff == null || !entry.timestamp.isBefore(cutoff)).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    await notifier._persistence.setSendHistory(updated);
    return updated;
  }
}

class RemoveSendHistoryEntryAction extends AsyncReduxAction<SendHistoryService, List<SendHistoryEntry>> {
  final String entryId;

  RemoveSendHistoryEntryAction(this.entryId);

  @override
  Future<List<SendHistoryEntry>> reduce() async {
    final updated = state.where((entry) => entry.id != entryId).toList();
    await notifier._persistence.setSendHistory(updated);
    return updated;
  }
}

class RemoveAllSendHistoryEntriesAction extends AsyncReduxAction<SendHistoryService, List<SendHistoryEntry>> {
  @override
  Future<List<SendHistoryEntry>> reduce() async {
    await notifier._persistence.setSendHistory([]);
    return [];
  }
}

/// Updates retention and immediately removes records older than the new limit.
class SetSendHistoryRetentionAction extends AsyncReduxAction<SendHistoryService, List<SendHistoryEntry>> {
  final int days;

  SetSendHistoryRetentionAction(this.days);

  @override
  Future<List<SendHistoryEntry>> reduce() async {
    if (![0, 30, 90].contains(days)) return state;
    await notifier._persistence.setSendHistoryRetentionDays(days);
    final updated = notifier._removeExpired(state);
    await notifier._persistence.setSendHistory(updated);
    return updated;
  }
}
