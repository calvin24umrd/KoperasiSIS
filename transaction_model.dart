class TransactionModel {
  final String id;
  final String loanId;
  final String userId;
  final String type;
  final double amount;
  final String? proofImage;
  final int? installmentMonth;
  final String status;
  final DateTime timestamp;

  TransactionModel({
    required this.id,
    required this.loanId,
    required this.userId,
    required this.type,
    required this.amount,
    this.proofImage,
    this.installmentMonth,
    required this.status,
    required this.timestamp,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] ?? '',
      loanId: map['loan_id'] ?? '',
      userId: map['user_id'] ?? '',
      type: map['type'] ?? '',
      amount: double.tryParse(map['amount']?.toString() ?? '0') ?? 0.0,
      proofImage: map['proof_image'],
      installmentMonth: int.tryParse(map['installment_month']?.toString() ?? '0'),
      status: map['status'] ?? 'pending',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'loan_id': loanId,
      'user_id': userId,
      'type': type,
      'amount': amount.toString(),
      'proof_image': proofImage,
      'installment_month': installmentMonth?.toString(),
      'status': status,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
