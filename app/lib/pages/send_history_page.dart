import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:localsend_app/model/persistence/send_history_entry.dart';
import 'package:localsend_app/provider/send_history_provider.dart';
import 'package:localsend_app/widget/dialogs/history_clear_dialog.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:localsend_isolates/util/file_size_helper.dart';
import 'package:refena_flutter/refena_flutter.dart';

class SendHistoryPage extends StatelessWidget {
  const SendHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = context.watch(sendHistoryProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    String text(String arabic, String english) => isArabic ? arabic : english;

    return Scaffold(
      appBar: AppBar(
        title: Text(text('سجل الإرسال', 'Send history')),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              tooltip: text('حذف السجل', 'Clear history'),
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
              text('يتم حذف سجلات الإرسال تلقائياً بعد 30 يوماً.', 'Send records are automatically deleted after 30 days.'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Center(
                child: Text(
                  text('لا توجد عمليات إرسال مسجلة بعد', 'No sent files in history yet'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            )
          else
            ...entries.map((entry) => _SendHistoryTile(
                  entry: entry,
                  isArabic: isArabic,
                )),
        ],
      ),
    );
  }
}

class _SendHistoryTile extends StatelessWidget {
  final SendHistoryEntry entry;
  final bool isArabic;

  const _SendHistoryTile({
    required this.entry,
    required this.isArabic,
  });

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
        title: Text(
          entry.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${DateFormat.yMMMd().add_jm().format(entry.timestamp.toLocal())} · ${entry.fileSize.asReadableFileSize}\n${entry.receiverAlias} · $statusText',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          tooltip: isArabic ? 'خيارات' : 'Options',
          onSelected: (value) {
            if (value == 'delete') {
              context.redux(sendHistoryProvider).dispatchAsync(RemoveSendHistoryEntryAction(entry.id));
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'delete',
              child: Text(isArabic ? 'حذف من السجل' : 'Remove from history'),
            ),
          ],
        ),
      ),
    );
  }
}
