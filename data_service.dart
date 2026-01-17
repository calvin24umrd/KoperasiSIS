import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'restapi.dart';
import 'config.dart';
import 'loan_model.dart';
import 'user_model.dart';
import 'transaction_model.dart';


class AppRepository {
  final DataService _api = DataService();

  // --- SMART PARSER ---
  List<dynamic> parseResponse(String resStr) {
    if (resStr == '[]' || resStr.isEmpty || resStr == 'null') return [];
    try {
      var decoded = json.decode(resStr);
      if (decoded is List) return decoded;
      if (decoded is Map) {
        // Handle new GoCloud format: {"limit":0,"offset":0,"total":X,"data":[...]}
        if (decoded.containsKey('data') && decoded['data'] is List) {
          return decoded['data'];
        }
        // Handle old format or single object
        return [decoded];
      }
      return [];
    } catch (e) {
      print("JSON Parse Error: $e");
      return [];
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    try {
      final resStr = await _api.selectAll(token, project, 'users', appid);
      final List res = parseResponse(resStr);
      return res.map((e) => UserModel.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> createLoan(LoanModel loan) async {
    print("CREATING LOAN: userId=${loan.userId}, amount=${loan.amount}, status=${loan.status}, purpose=${loan.purpose}");
    final res = await _api.insertLoans(
        appid,
        loan.userId,
        loan.amount.toString(),
        loan.tenor.toString(),
        '', // interest_rate - akan diisi admin nanti
        loan.status,
        loan.createdAt.toIso8601String(),
        loan.purpose);
    print("CREATE LOAN RESPONSE: $res");
    return res != '[]';
  }

  Future<List<LoanModel>> getMyLoans(String userId) async {
    try {
      final resStr = await _api.selectWhere(
          token, project, 'loans', appid, 'user_id', userId);
      final List res = parseResponse(resStr);
      return res.map((e) => LoanModel.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // --- USED BY SURVEYOR & ADMIN ---
  Future<List<LoanModel>> getAllLoans() async {
    try {
      final resStr = await _api.selectAll(token, project, 'loans', appid);
      // Debug: Check terminal to see if data arrives
      print("RAW LOANS DATA: $resStr");
      final List res = parseResponse(resStr);
      print("PARSED LOANS COUNT: ${res.length}");
      return res.map((e) => LoanModel.fromMap(e)).toList();
    } catch (e) {
      print("ERROR GETTING LOANS: $e");
      return [];
    }
  }

  // Fungsi baru untuk mengambil SEMUA transaksi tanpa filter user
  Future<String> getAllTransactionsRaw() async {
    try {
      // Kita meminjam _api yang sudah terdefinisi di class ini
      return await _api.selectAll(token, project, 'transactions', appid);
    } catch (e) {
      return '[]';
    }
  }

  Future<bool> updateLoanStatus(String id, String status) async {
    return await _api.updateId(
        'status', status, token, project, 'loans', appid, id);
  }

  // Fungsi untuk mencatat sejarah uang masuk/keluar (pencairan & angsuran)
  Future<bool> recordTransaction({
    required String memberId,
    required String loanId,
    required String type,
    required double amount,
    String note = '',
    String? proofImage,
  }) async {
    try {
      // Kita gunakan fungsi insertTransactions yang sudah ada di DataService kamu
      final res = await _api.insertTransactions(
          appid,
          loanId,
          memberId,
          type, // 'pencairan'
          amount.toString(),
          proofImage ?? '', // Link foto jika ada
          '0', // Untuk pencairan, bulan angsuran diisi 0
          'success', // Untuk pencairan admin langsung success
          DateTime.now().toIso8601String());
          
      return res != '[]'; // Mengembalikan true jika berhasil
    } catch (e) {
      print("Error recordTransaction: $e");
      return false;
    }
  }

  Future<bool> updateLoanField(
      String loanId, String fieldName, String value) async {
    return await _api.updateId(
        fieldName, value, token, project, 'loans', appid, loanId);
  }

  Future<bool> updateUserField(
      String userId, String fieldName, dynamic value) async {
    return await _api.updateId(
        fieldName, value.toString(), token, project, 'users', appid, userId);
  }

  Future<bool> updateUserVerification(String userId, bool isVerified) async {
    try {
      // Update the top-level isVerified field directly
      return await _api.updateId('isVerified', isVerified.toString(), token, project, 'users', appid, userId);
    } catch (e) {
      print("Error updating user verification: $e");
      return false;
    }
  }

  Future<bool> updateUserSHU(String userId, String shu, {String? periode, String? status}) async {
    try {
      // Update the SHU fields directly at top-level
      bool shuUpdated = await _api.updateId('shu', shu, token, project, 'users', appid, userId);

      // Update periode if provided
      bool periodeUpdated = true;
      if (periode != null) {
        periodeUpdated = await _api.updateId('shuPeriode', periode, token, project, 'users', appid, userId);
      }

      // Update status if provided
      bool statusUpdated = true;
      if (status != null) {
        statusUpdated = await _api.updateId('shuStatus', status, token, project, 'users', appid, userId);
      }

      return shuUpdated && periodeUpdated && statusUpdated;
    } catch (e) {
      print("Error updating user SHU: $e");
      return false;
    }
  }

  // --- PAYMENT METHODS ---
  // Fungsi ini sekarang mendukung Web dan HP
 // Gunakan fungsi upload dari DataService (GoCloud)
  // Pastikan import ini ada di paling atas:
  // import 'package:http/http.dart' as http;
  // import 'package:flutter/foundation.dart' show kIsWeb;

  Future<String> uploadPaymentProof(File imageFile) async {
    try {
      final String filename = 'pay_${DateTime.now().millisecondsSinceEpoch}.jpg';
      List<int> bytes;

      if (kIsWeb) {
        // Untuk Web: Ambil bytes menggunakan request network ke Blob URL picker
        final response = await http.get(Uri.parse(imageFile.path));
        bytes = response.bodyBytes;
      } else {
        // Untuk HP: Tetap gunakan cara biasa
        bytes = await imageFile.readAsBytes();
      }
      
      // Panggil fungsi upload milik DataService yang sudah ada di restapi.dart
      final result = await _api.upload(bytes, filename);
      
      if (result.isEmpty) throw Exception('Upload gagal ke server GoCloud');
      
      return 'https://files.247go.app/files/get/$result';
    } catch (e) {
      throw Exception('Gagal upload: $e');
    }
  }

  Future<bool> submitPayment({
    required String loanId,
    required String userId,
    required double amount,
    required String proofImageUrl,
    required int installmentMonth,
  }) async {
    try {
      // 1. Cari transaksi installment yang sudah ada dengan status unpaid
      final allTransactions = await getLoanTransactions(loanId);
      final existingInstallment = allTransactions.firstWhere(
        (tx) => tx.installmentMonth == installmentMonth &&
                tx.type.toLowerCase() == 'installment' &&
                tx.status.toLowerCase() == 'unpaid',
        orElse: () => TransactionModel(
          id: '', userId: '', loanId: '',
          amount: 0, type: '', status: '',
          timestamp: DateTime.now()
        ),
      );

      if (existingInstallment.id.isNotEmpty) {
        // 2. UPDATE transaksi yang sudah ada, bukan buat baru
        // Update status ke pending
        bool statusUpdated = await _api.updateId(
          'status', 'pending',
          token, project, 'transactions', appid, existingInstallment.id
        );

        // Update proof_image dengan link foto bukti
        bool proofUpdated = await _api.updateId(
          'proof_image', proofImageUrl,
          token, project, 'transactions', appid, existingInstallment.id
        );

        // Update timestamp pembayaran
        bool timestampUpdated = await _api.updateId(
          'timestamp', DateTime.now().toIso8601String(),
          token, project, 'transactions', appid, existingInstallment.id
        );

        return statusUpdated && proofUpdated && timestampUpdated;
      } else {
        print('Warning: No existing unpaid installment found for loan $loanId, month $installmentMonth');
        return false;
      }
    } catch (e) {
      print('Error submitting payment: $e');
      return false;
    }
  }

  Future<List<TransactionModel>> getLoanTransactions(String loanId) async {
    try {
      final resStr = await _api.selectWhere(
          token, project, 'transactions', appid, 'loan_id', loanId);
      final List res = parseResponse(resStr);
      return res.map((e) => TransactionModel.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<TransactionModel>> getUserTransactions(String userId) async {
    try {
      final resStr = await _api.selectWhere(
          token, project, 'transactions', appid, 'user_id', userId);
      final List res = parseResponse(resStr);
      return res.map((e) => TransactionModel.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> updateTransactionStatus(String transactionId, String status) async {
    return await _api.updateId(
        'status', status, token, project, 'transactions', appid, transactionId);
  }

  Future<void> generateInstallments(LoanModel loan, double interestRate) async {
  // RUMUS FLAT: (Pokok / Tenor) + (Pokok * Bunga Per Bulan)
  double monthlyPrincipal = loan.amount / loan.tenor;
  double monthlyInterest = loan.amount * interestRate; // interestRate sudah dalam desimal (misal 0.01)
  double totalMonthlyPayment = monthlyPrincipal + monthlyInterest;

  DateTime currentDate = DateTime.now();

  for (int i = 1; i <= loan.tenor; i++) {
    // Jatuh tempo setiap bulan berikutnya
    DateTime dueDate = DateTime(currentDate.year, currentDate.month + i, currentDate.day);

    await _api.insertTransactions(
  appid,
  loan.id,
  loan.userId,
  'installment', // Type harus konsisten
  totalMonthlyPayment.toStringAsFixed(0),
  '', 
  i.toString(), // <--- SEKARANG MENGIRIM NOMOR BULAN (1, 2, 3)
  'unpaid', 
  dueDate.toIso8601String(),
);
  }
}
}
