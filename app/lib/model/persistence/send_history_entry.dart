class SendHistoryEntry {
  final String id;
  final String fileName;
  final int fileSize;
  final String receiverAlias;
  final DateTime timestamp;
  final bool succeeded;

  const SendHistoryEntry({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.receiverAlias,
    required this.timestamp,
    required this.succeeded,
  });

  factory SendHistoryEntry.fromJson(Map<String, dynamic> json) {
    return SendHistoryEntry(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      fileSize: (json['fileSize'] as num).toInt(),
      receiverAlias: json['receiverAlias'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String).toUtc(),
      succeeded: json['succeeded'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'fileSize': fileSize,
        'receiverAlias': receiverAlias,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'succeeded': succeeded,
      };
}
