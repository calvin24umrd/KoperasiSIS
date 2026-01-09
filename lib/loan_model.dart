class LoanModel {
  final String id;
  final String userId;
  final double amount;
  final int tenor;
  final String status;
  final DateTime createdAt;
  final String purpose;
  final int score;
  final double interest;
  final double penalty;
  final String? notes; // TAMBAHKAN INI

  LoanModel({
    required this.id, required this.userId, required this.amount, 
    required this.tenor, required this.status, required this.createdAt,
    this.purpose = "Pinjaman",
    this.score = 0,
    this.interest = 0.0,
    this.penalty = 0.0,
    this.notes = "", // TAMBAHKAN INI
  });

  factory LoanModel.fromMap(Map<String, dynamic> map) {
  // Membersihkan nilai bunga jika ia disimpan sebagai persentase (misal "1.0")
  var rawInterest = map['interest_rate'] ?? map['interest'] ?? '0';
  double parsedInterest = double.tryParse(rawInterest.toString()) ?? 0.0;
  
  // Jika di database tersimpan 0.01 (untuk 1%), kita kalikan 100 agar muncul "1.0" di UI
  if (parsedInterest < 1.0 && parsedInterest > 0) {
    parsedInterest = parsedInterest * 100;
  }

  return LoanModel(
    id: map['_id'] ?? map['id'] ?? '',
    userId: map['user_id'] ?? '',
    amount: double.tryParse(map['amount']?.toString() ?? '0') ?? 0,
    tenor: int.tryParse(map['tenor']?.toString() ?? '0') ?? 0,
    status: map['status'] ?? 'pending',
    createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
    purpose: map['purpose'] ?? 'Pinjaman',
    score: int.tryParse(map['score']?.toString() ?? '0') ?? 0,
    interest: parsedInterest, // Gunakan hasil yang sudah dibersihkan
    penalty: double.tryParse(map['penalty']?.toString() ?? '0') ?? 0.0,
    notes: map['notes'] ?? "",
  );
}
}