/// Response from the batch ingestion API (202 Accepted).
class BatchResponse {
  final String batchId;
  final String receivedAt;
  final int accepted;
  final int rejected;
  final List<String> warnings;

  const BatchResponse({
    required this.batchId,
    required this.receivedAt,
    required this.accepted,
    required this.rejected,
    required this.warnings,
  });

  factory BatchResponse.fromJson(Map<String, dynamic> json) {
    return BatchResponse(
      batchId: json['batch_id'] as String,
      receivedAt: json['received_at'] as String,
      accepted: json['accepted'] as int,
      rejected: json['rejected'] as int,
      warnings: (json['warnings'] as List<dynamic>)
          .map((w) => w.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'batch_id': batchId,
        'received_at': receivedAt,
        'accepted': accepted,
        'rejected': rejected,
        'warnings': warnings,
      };
}
