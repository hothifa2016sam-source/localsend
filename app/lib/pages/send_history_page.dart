import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:localsend_app/model/persistence/send_history_entry.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:localsend_app/provider/send_history_provider.dart';
import 'package:localsend_app/widget/dialogs/history_clear_dialog.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:localsend_isolates/util/file_size_helper.dart';
import 'package:refena_flutter/refena_flutter.dart';

enum _DateFilter { all, today, lastSeven, lastThirty }

class SendHistoryPage extends StatefulWidget {
  const SendHistoryPage({super.key});

  @override
  State<SendHistoryPage> createState() => _SendHistoryPageState();
}

class _SendHistoryPageState extends State<SendHistoryPage> {
  final _search = TextEditingController();
  _DateFilter _dateFilter = _DateFilter.all;
  int _retentionDays = 30;

  @override
  void initState() {
    super.initState();
    _search.addListener(_refresh);
    // Read the locally saved preference without changing any existing records.
    _retentionDays = context.read(persistenceProvider).getSendHistoryRetentionDays();
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _search.removeListener(_refresh);
    _search.dispose();
    super.dispose();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _matchesDate(DateTime date, DateTime now) {
    final local = date.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    return switch (_dateFilter) {
      _DateFilter.all => true,
      _DateFilter.today => _sameDay(day, today),
      _DateFilter.lastSeven => !day.isBefore(today.subtract(const Duration(days: 6))) && !day.isAfter(today),
      _DateFilter.lastThirty => !day.isBefore(today.subtract(const Duration(days: 29))) && !day.isAfter(today),
    };
  }

  String _dateLabel(DateTime date, DateTime now, bool ar) {
    final local = date.toLocal();
    if (_sameDay(local, now)) return ar ? 'اليوم' : 'Today';
    if (_sameDay(local, now.subtract(const Duration(days: 1)))) return ar ? 'أمس' : 'Yesterday';
    return DateFormat.yMMMMd(ar ? 'ar' : 'en').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final entries = context.watch(sendHistoryProvider);
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    String tr(String arabic, String english) => ar ? arabic : english;
    final now = DateTime.now();
    final filtered = entries.where((e) =>
        e.fileName.toLowerCase().contains(_search.text.trim().toLowerCase()) &&
        _matchesDate(e.timestamp, now)).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final groups = <DateTime, List<SendHistoryEntry>>{};
    for (final entry in filtered) {
      final local = entry.timestamp.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      groups.putIfAbsent(day, () => []).add(entry);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('سجل الإرسال', 'Send history')),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              tooltip: tr('حذف السجل', 'Clear history'),
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => const HistoryClearDialog(),
                );
                if (context.mounted && confirmed == true) {
                  await context.redux(sendHistoryProvider).dispatchAsync(RemoveAllSendHistoryEntriesAction());
                }
              },
            ),
        ],
      ),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              _retentionDays == 0
                  ? tr('يتم الاحتفاظ بالسجلات حتى حذفها يدوياً.', 'Records are kept until manually deleted.')
                  : tr('يتم حذف سجلات الإرسال تلقائياً بعد $_retentionDays يوماً.',
                      'Send records are automatically deleted after $_retentionDays days.'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: tr('بحث سريع باسم الملف', 'Search by file name'),
                border: const OutlineInputBorder(),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: tr('مسح البحث', 'Clear search'),
                        onPressed: _search.clear,
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<_DateFilter>(
                  value: _dateFilter,
                  onChanged: (value) {
                    if (value != null) setState(() => _dateFilter = value);
                  },
                  items: [
                    DropdownMenuItem(value: _DateFilter.all, child: Text(tr('كل التواريخ', 'All dates'))),
                    DropdownMenuItem(value: _DateFilter.today, child: Text(tr('اليوم', 'Today'))),
                    DropdownMenuItem(value: _DateFilter.lastSeven, child: Text(tr('آخر 7 أيام', 'Last 7 days'))),
                    DropdownMenuItem(value: _DateFilter.lastThirty, child: Text(tr('آخر 30 يوماً', 'Last 30 days'))),
                  ],
                ),
                const SizedBox(width: 10),
                Text(tr('حفظ السجل:', 'Keep history:')),
                DropdownButton<int>(
                  value: _retentionDays,
                  onChanged: (value) async {
                    if (value == null || value == _retentionDays) return;
                    final old = _retentionDays;
                    if (value != 0 && (old == 0 || value < old)) {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: Text(tr('تغيير مدة الحفظ', 'Change retention')),
                          content: Text(tr('سيتم حذف السجلات الأقدم من $value يوماً نهائياً. هل تريد المتابعة؟',
                              'Records older than $value days will be permanently removed. Continue?')),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(tr('إلغاء', 'Cancel'))),
                            TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(tr('متابعة', 'Continue'))),
                          ],
                        ),
                      );
                      if (confirm != true || !mounted) return;
                    }
                    await context.redux(sendHistoryProvider).dispatchAsync(SetSendHistoryRetentionAction(value));
                    if (mounted) setState(() => _retentionDays = value);
                  },
                  items: [
                    DropdownMenuItem(value: 30, child: Text(tr('30 يوماً', '30 days'))),
                    DropdownMenuItem(value: 90, child: Text(tr('90 يوماً', '90 days'))),
                    DropdownMenuItem(value: 0, child: Text(tr('دائماً', 'Forever'))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Center(
                child: Text(
                  entries.isEmpty
                      ? tr('لا توجد عمليات إرسال مسجلة بعد', 'No sent files in history yet')
                      : tr('لا توجد ملفات مطابقة', 'No matching files'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            )
          else
            for (final group in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
                child: Row(
                  children: [
                    Text('${_dateLabel(group.key, now, ar)} (${group.value.length})',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(width: 12),
                    const Expanded(child: Divider()),
                  ],
                ),
              ),
              for (final entry in group.value)
                _SendHistoryTile(entry: entry, isArabic: ar),
            ],
        ],
      ),
    );
  }
}

class _SendHistoryTile extends StatelessWidget {
  final SendHistoryEntry entry;
  final bool isArabic;

  const _SendHistoryTile({required this.entry, required this.isArabic});

  @override
  Widget build(BuildContext context) {
    final statusText = entry.succeeded
        ? (isArabic ? 'تم الإرسال' : 'Sent')
        : (isArabic ? 'فشل الإرسال' : 'Failed');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: ListTile(
        leading: Icon(
          entry.succeeded ? Icons.check_circle_outline : Icons.error_outline,
          color: entry.succeeded ? Colors.green : Theme.of(context).colorScheme.error,
          size: 30,
        ),
        title: Text(entry.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${DateFormat.yMMMd().add_jm().format(entry.timestamp.toLocal())} · ${entry.fileSize.asReadableFileSize}\n${entry.receiverAlias} · $statusText',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          tooltip: isArabic ? 'خيارات' : 'Options',
          onSelected: (value) async {
            if (value == 'copy') {
              await Clipboard.setData(ClipboardData(text: entry.fileName));
            } else if (value == 'delete') {
              if (context.mounted) {
                await context.redux(sendHistoryProvider).dispatchAsync(RemoveSendHistoryEntryAction(entry.id));
              }
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'copy', child: Text(isArabic ? 'نسخ اسم الملف' : 'Copy file name')),
            PopupMenuItem(value: 'delete', child: Text(isArabic ? 'حذف من السجل' : 'Remove from history')),
          ],
        ),
      ),
    );
  }
}
