import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'auth_service.dart';
import 'loan_model.dart';
import 'user_model.dart';
import 'utils.dart';
import 'data_service.dart';
import 'config.dart';
import 'status_helper.dart';
import 'restapi.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  final AppRepository _repo = AppRepository();
  List<LoanModel> _loans = [];
  List<UserModel> _users = [];
  List<Map<String, dynamic>> _transactions = [];

  bool _isLoading = true;
  int _selectedTab = 0;
  String _searchQuery = '';
  String _statusFilter = 'all';

  late TabController _tabController;

  Map<String, dynamic> _stats = {
    'totalLoans': 0,
    'pendingLoans': 0,
    'approvedLoans': 0,
    'rejectedLoans': 0,
    'totalUsers': 0,
    'verifiedUsers': 0,
    'totalAmount': 0.0,
    'monthlyGrowth': '+0%',
  };

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 4, vsync: this, initialIndex: _selectedTab);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging)
        setState(() => _selectedTab = _tabController.index);
    });
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _mapStatusToLabel(String status) {
  // 1. Cek jika datanya memang kosong atau null
  if (status == null || status.toString().isEmpty || status.toString() == 'null') {
    return 'KOSONG';
  }

  // 2. Bersihkan spasi dan ubah ke huruf kecil
  final String s = status.toString().toLowerCase().trim();

  if (s == 'unpaid') return 'Belum Bayar';

  // 3. Daftar kemungkinan status yang benar
  if (s == 'success' || s == 'approved' || s == '1' || s == 'lunas') return 'Berhasil';
  if (s == 'disbursed') return 'Sudah Dicairkan';
  if (s == 'pending' || s == '0') return 'Pending';
  if (s == 'rejected') return 'Ditolak';
  if (s == 'surveyed') return 'Disurvey';
  if (s == 'survey_completed') return 'Selesai Survey';

  // 4. Jika masih tidak kenal, tampilkan "ISI ASLINYA" agar kita tahu
  return 'ISINYA: ($status)';
}

  String _mapTransactionType(String type) {
    switch (type.toLowerCase()) {
      case 'payment':
      case 'installment':
      case 'angsuran':
        return 'Angsuran';
      case 'pencairan':
        return 'Pencairan';
      case 'simpanan_wajib':
        return 'Simpanan Wajib';
      case 'shu_pencairan':
        return 'Pencairan SHU';
      default:
        return type;
    }
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final allLoans = await _repo.getAllLoans();
      final users = await _repo.getAllUsers();
      final resStr = await _repo.getAllTransactionsRaw();
      final List rawTx = _repo.parseResponse(resStr);

      if (!mounted) return;

      List<Map<String, dynamic>> realTransactions = [];

      // 1. PROSES DATA DARI TABEL TRANSAKSI (Angsuran & Pencairan)
      for (var tx in rawTx) {
        String userName = "Unknown";
        try {
          final u = users.firstWhere((user) => user.id == tx['user_id']);
          userName = u.name;
        } catch (_) {}

        // PERBAIKAN NOMINAL: Hapus titik ribuan agar 7.015 tidak dianggap 7 rupiah
        String amountStr = (tx['amount'] ?? '0').toString().replaceAll('.', '');

        realTransactions.add({
          'id': tx['_id'] ?? tx['id'] ?? 'TRX-ERR',
          'userId': tx['user_id'] ?? '',
          'userName': userName,
          'amount': double.tryParse(amountStr) ?? 0.0,
          'type': _mapTransactionType(tx['type'] ?? ''),
          'rawType': tx['type'] ?? '',
          'status': _mapStatusToLabel(tx['status'] ?? 'pending'),
          'date': DateTime.tryParse(tx['timestamp'] ?? '') ?? DateTime.now(),
          'loanId': tx['loan_id'] ?? '',
          'rawStatus': tx['status'] ?? 'pending',
          'proofImage': tx['proof_image'] ?? '', // Menggunakan key proofImage sesuai widget detail
        });
      }

      // 2. GABUNGKAN DATA PINJAMAN (Agar lengkap seperti image_c48926.png)
      for (var loan in allLoans) {
        // Cek agar tidak dobel dengan transaksi pencairan
        bool isDuplicate = realTransactions.any((t) => t['loanId'] == loan.id && t['type'] == 'Pencairan');

        if (!isDuplicate) {
           String uName = "Unknown";
           try { uName = users.firstWhere((u) => u.id == loan.userId).name; } catch(_) {}

           realTransactions.add({
             'id': loan.id,
             'userId': loan.userId,
             'userName': uName,
             'amount': loan.amount,
             'type': 'Pengajuan',
             'rawType': '',
             'status': _mapStatusToLabel(loan.status),
             'date': loan.createdAt,
             'loanId': loan.id,
             'rawStatus': loan.status,
             'proofImage': '',
           });
        }
      }

      realTransactions.sort((a, b) => b['date'].compareTo(a['date']));

      setState(() {
        _loans = allLoans;
        _users = users;
        _transactions = realTransactions;
        _stats = {
          'totalLoans': allLoans.length,
          'pendingLoans': allLoans.where((l) => l.status == 'pending').length,
          'approvedLoans': allLoans.where((l) => l.status == 'approved' || l.status == 'disbursed').length,
          'rejectedLoans': allLoans.where((l) => l.status == 'rejected').length,
          'totalUsers': users.length,
          'verifiedUsers': users.where((u) => u.isVerified).length,
          'totalAmount': allLoans.fold(0.0, (sum, l) => sum + l.amount),
          'monthlyGrowth': '+5%',
          'currentCash': _calculateCurrentCash(),
        };
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading data: $e");
      if (mounted) setState(() => _isLoading = false);
    }

  }

  double _calculateCurrentCash() {
    double totalIn = 0; // Uang masuk (Angsuran + Simpanan Wajib)
    double totalOut = 0; // Uang keluar (Pencairan)

    for (var tx in _transactions) {
      if (tx['rawStatus'] == 'success' || tx['rawStatus'] == 'approved' || tx['rawStatus'] == 'disbursed') {
        String mappedType = _mapTransactionType(tx['rawType'] ?? '');
        if (mappedType == 'Angsuran' || mappedType == 'Simpanan Wajib') {
          totalIn += tx['amount'];
        } else if (mappedType == 'Pencairan' || mappedType == 'Pencairan SHU') {
          totalOut += tx['amount'];
        }
      }
    }

    // Add mandatory savings from verified members
    int verifiedMembers = _users.where((u) => u.isVerified).length;
    double mandatorySavings = verifiedMembers * 1000000.0;

    // Misal koperasi punya modal awal 100 juta
    double modalAwal = 20000000;
    return modalAwal + totalIn + mandatorySavings - totalOut;
  }

  void _updateStatus(String id, String status) async {
    try {
      await _repo.updateLoanStatus(id, status);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Status diubah menjadi: $status"),
          backgroundColor: status == 'approved' ? Colors.green : Colors.red,
        ));
        _loadAllData();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Gagal update"), backgroundColor: Colors.red));
    }
  }

  void _approveWithInterest(String loanId, int score) async {
    // Fixed rates: 1% interest and 0.5% penalty
    double fixedInterest = 0.01; // 1% flat
    double fixedPenalty = 0.005; // 0.5% flat

    // Calculate current cash
    double currentCash = _calculateCurrentCash();

    // Find the loan to get its amount
    LoanModel? loan;
    try {
      loan = _loans.firstWhere((l) => l.id == loanId);
    } catch (e) {
      loan = null;
    }

    bool isCashSufficient = loan != null && currentCash >= loan.amount;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi Persetujuan"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Skor Kelayakan: $score/100"),
            const SizedBox(height: 10),
            const Text("Bunga per bulan: 1% (flat)"),
            const Text("Denda keterlambatan: 0.5% (flat)"),
            const SizedBox(height: 10),
            if (!isCashSufficient) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "⚠️ PERINGATAN: Saldo Kas Tidak Cukup",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Saldo tersedia: Rp ${Utils.formatCurrency(currentCash)}",
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                    if (loan != null)
                      Text(
                        "Dibutuhkan: Rp ${Utils.formatCurrency(loan.amount)}",
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal")),
          ElevatedButton(
            onPressed: isCashSufficient ? () async {
              // 1. Simpan Bunga & Denda ke tabel Loans (fixed rates)
              await _repo.updateLoanField(loanId, 'interest_rate', fixedInterest.toString());
              await _repo.updateLoanField(loanId, 'penalty', fixedPenalty.toString());

              // 2. Update status jadi approved
              await _repo.updateLoanStatus(loanId, 'approved');

              // 3. Buat Jadwal Angsuran (Pokok + Bunga)
              await _repo.generateInstallments(loan!, fixedInterest);

              if (mounted) {
                Navigator.pop(context);
                _loadAllData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Berhasil Disetujui & Jadwal Dibuat!"), backgroundColor: Colors.green)
                );
              }
            } : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isCashSufficient ? null : Colors.grey,
            ),
            child: Text(isCashSufficient ? "Setujui & Cairkan" : "Saldo Tidak Cukup"),
          ),
        ],
      ),
    );
  }

  void _showLoanDetails(int index) {
    if (index < 0 || index >= _loans.length) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _buildLoanDetailSheet(_loans[index]),
    );
  }

  void _showUserDetails(UserModel user) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Detail Anggota: ${user.name}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (user.role == 'admin') ...[
                _buildDetailRow('ID Admin', user.id.length > 8 ? user.id.substring(0, 8) : user.id),
                _buildDetailRow('Username', user.name),
                _buildDetailRow('Nama Lengkap', user.name),
                _buildDetailRow('Email', user.email),
                _buildDetailRow('Role', 'Admin'),
                _buildDetailRow('Nomor Telepon', user.phone.isNotEmpty ? user.phone : '(Internal)'),
                _buildDetailRow('Status Akun', 'Aktif'),
                _buildDetailRow('Bergabung Pada', DateFormat('dd MMMM yyyy', 'id_ID').format(user.joinDate)),
              ] else if (user.role == 'surveyor') ...[
                _buildDetailRow('ID', user.id),
                _buildDetailRow('Nama', user.name),
                _buildDetailRow('Email', user.email),
                _buildDetailRow('Role', 'Surveyor'),
                _buildDetailRow('Telepon', user.phone.isNotEmpty ? user.phone : 'Internal'),
                _buildDetailRow('Area Kerja', user.address.isNotEmpty ? user.address : 'Indonesia'),
                _buildDetailRow('Status', user.isVerified ? 'Aktif' : 'Pending'),
                _buildDetailRow('Bergabung', DateFormat('dd MMM yyyy').format(user.joinDate)),
              ] else ...[
                _buildDetailRow('ID', user.id),
                _buildDetailRow('Nama', user.name),
                _buildDetailRow('Email', user.email),
                _buildDetailRow('Role', user.role),
                _buildDetailRow(
                    'Telepon', user.phone.isNotEmpty ? user.phone : '-'),
                _buildDetailRow('NIK', user.nik.isNotEmpty ? user.nik : '-'),
                _buildDetailRow(
                    'Alamat', user.address.isNotEmpty ? user.address : '-'),
                _buildDetailRow(
                    'Pekerjaan', user.job.isNotEmpty ? user.job : '-'),
                _buildDetailRow(
                    'Status KYC', user.isVerified ? 'Terverifikasi' : 'Belum'),
                _buildDetailRow(
                    'Bergabung', DateFormat('dd MMM yyyy').format(user.joinDate)),
              ],
            ],
          ),
        ),
        actions: [
          if (!user.isVerified)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: const StadiumBorder(),
              ),
              onPressed: () async {
                // Update verification status
                bool success = await _repo.updateUserVerification(user.id, true);
                if (success) {
                  // No transaction recording needed, cash updated via verified members count
                }
                if (mounted) {
                  Navigator.of(dialogContext).pop();
                  _loadAllData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Member berhasil diverifikasi! Kas bertambah Rp 1.000.000"))
                  );
                }
              },
              child: const Text("Verifikasi Anggota", style: TextStyle(color: Colors.white)),
            ),
          if (user.isVerified && user.role == 'member')
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: const StadiumBorder(),
              ),
              onPressed: () async {
                final TextEditingController shuController = TextEditingController(text: user.shu);
                final TextEditingController shuPeriodeController = TextEditingController(text: user.shuPeriode);
                final TextEditingController shuStatusController = TextEditingController(text: user.shuStatus);
                showDialog(
                  context: dialogContext,
                  builder: (shuDialogContext) => AlertDialog(
                    title: const Text("Update SHU"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Masukkan detail SHU baru untuk member ini:"),
                        const SizedBox(height: 10),
                        TextField(
                          controller: shuController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Nominal SHU (Rp)',
                            hintText: 'Contoh: 500000',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: shuPeriodeController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Periode',
                            hintText: 'Contoh: 2025',
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: shuStatusController.text.isEmpty ? 'Belum Dicairkan' : shuStatusController.text,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Status',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Belum Berhak SHU', child: Text('Belum Berhak SHU')),
                            DropdownMenuItem(value: 'Belum Dicairkan', child: Text('Belum Dicairkan')),
                            DropdownMenuItem(value: 'Sudah Dicairkan', child: Text('Sudah Dicairkan')),
                          ],
                          onChanged: (value) => shuStatusController.text = value ?? 'Belum Dicairkan',
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(shuDialogContext),
                        child: const Text("Batal"),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final newShu = shuController.text.trim();
                          final newPeriode = shuPeriodeController.text.trim();
                          final newStatus = shuStatusController.text.trim();
                          if (newShu.isEmpty || newPeriode.isEmpty || newStatus.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Harap isi semua field"),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          bool success = await _repo.updateUserSHU(user.id, newShu, periode: newPeriode, status: newStatus);
                          if (success) {
                            if (mounted) {
                              Navigator.pop(shuDialogContext);
                              Navigator.of(dialogContext).pop();
                              _loadAllData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("SHU berhasil diupdate!"))
                              );
                            }
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Gagal update SHU"),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        child: const Text("Update"),
                      ),
                    ],
                  ),
                );
              },
              child: const Text("Update SHU", style: TextStyle(color: Colors.white)),
            ),
          if (user.isVerified && user.role == 'member' && user.shuStatus == 'Belum Dicairkan' && user.shu != '0')
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: const StadiumBorder(),
              ),
              onPressed: () async {
                showDialog(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text("Konfirmasi Pencairan SHU"),
                    content: Text("Pastikan SHU sebesar Rp ${Utils.formatCurrency(double.tryParse(user.shu) ?? 0)} sudah diserahkan kepada member. Sistem akan mencatat pengeluaran kas."),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Batal")),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: () async {
                          try {
                            // Record transaction for SHU disbursement
                            await _repo.recordTransaction(
                              memberId: user.id,
                              loanId: '',
                              type: 'shu_pencairan',
                              amount: double.tryParse(user.shu) ?? 0,
                              note: 'Pencairan SHU di kantor koperasi',
                            );
                            // Update SHU status to "Sudah Dicairkan"
                            await _repo.updateUserSHU(user.id, user.shu, periode: user.shuPeriode, status: 'Sudah Dicairkan');

                            if (mounted) {
                              Navigator.pop(dialogContext);
                              Navigator.of(context).pop();
                              _loadAllData();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SHU berhasil dicairkan!"), backgroundColor: Colors.green));
                            }
                          } catch (e) {
                            print("Error disbursing SHU: $e");
                          }
                        },
                        child: const Text("Ya, Sudah Cair", style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
              child: const Text("Cairkan SHU", style: TextStyle(color: Colors.white)),
            ),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Tutup'))
        ],
      ),
    );
  }

   void _showSurveyResults(LoanModel loan) {
  // 1. Definisikan instance 'api' agar tidak error 'Undefined name'
  final api = DataService();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) {
      // 2. Gunakan <dynamic> supaya tidak error 'argument type'
      return FutureBuilder<dynamic>(
        future: api.selectWhere(token, project, 'surveyresults', appid, 'loan_id', loan.id),
        builder: (context, snapshot) {
          // loan.notes sekarang terbaca karena model sudah diupdate
          String noteText = (loan.notes == null || loan.notes!.isEmpty) ? "Tidak ada catatan surveyor" : loan.notes!;
          List<String> photoUrls = [];

          if (snapshot.hasData && snapshot.data != null && snapshot.data != '[]') {
            final List decoded = _repo.parseResponse(snapshot.data.toString());
            if (decoded.isNotEmpty) {
              final surveyData = decoded.first;
              final String photosRaw = surveyData['photos'] ?? '';
              if (photosRaw.isNotEmpty) {
                photoUrls = photosRaw.split('|').where((p) => p != 'no_image').map((p) => getFileUrl(p)).toList();
              }
            }
          }

          // LOGIKA SKOR: Rapat muncul jika skor < 80 (Sedang/Rendah)
          bool isTinggi = loan.score >= 80;

          return StatefulBuilder(
            builder: (context, setState) {
              String selectedMeetingDecision = '';
              TextEditingController meetingNotesController = TextEditingController();

              return Container(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Laporan Hasil Survey", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Divider(),
                      _buildDetailRow("Skor Survey", "${loan.score}/100"),
                      _buildDetailRow("Kategori", _getScoreCategory(loan.score)),
                      const SizedBox(height: 15),

                      const Text("Catatan Surveyor:", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(noteText, style: const TextStyle(color: Colors.black87)),
                      const SizedBox(height: 15),

                      const Text("Foto Bukti Lapangan:", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      if (photoUrls.isEmpty)
                        const Text("Tidak ada foto", style: TextStyle(color: Colors.grey, fontSize: 12))
                      else
                        SizedBox(
                          height: 150,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: photoUrls.length,
                            itemBuilder: (ctx, i) => Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(photoUrls[i], width: 200, fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(width: 200, color: Colors.grey[300], child: const Icon(Icons.broken_image))),
                              ),
                            ),
                          ),
                        ),

                      // --- OPSI RAPAT: SELALU MUNCUL ---
                      const SizedBox(height: 20),
                      const Divider(color: Colors.deepPurple, thickness: 1.5),
                      const Text("🔘 OPSI RAPAT PENGURUS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Keputusan Rapat'),
                        items: const [
                          DropdownMenuItem(value: 'meeting_approved', child: Text('Disetujui melalui rapat pengurus')),
                          DropdownMenuItem(value: 'conditional', child: Text('Disetujui bersyarat')),
                          DropdownMenuItem(value: 'pending_info', child: Text('Pending menunggu kelengkapan')),
                          DropdownMenuItem(value: 'reject_risk', child: Text('Ditolak karena risiko tinggi')),
                        ],
                        onChanged: (val) => setState(() => selectedMeetingDecision = val ?? ''),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: meetingNotesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Meeting Notes',
                          hintText: 'Tuliskan poin penting hasil rapat...'
                        ),
                      ),

                      const SizedBox(height: 25),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text("Konfirmasi Penolakan"),
                                    content: const Text("Apakah Anda yakin ingin menolak pengajuan pinjaman ini?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogContext),
                                        child: const Text("Batal"),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        onPressed: () async {
                                          Navigator.pop(dialogContext); // Tutup dialog konfirmasi
                                          // Ambil alasan dari dropdown/textfield rapat
                                          String alasanTolak = "Ditolak: $selectedMeetingDecision - ${meetingNotesController.text}";

                                          // Simpan alasannya dulu ke field 'notes'
                                          await _repo.updateLoanField(loan.id, 'notes', alasanTolak);

                                          // Baru ubah status jadi rejected
                                          _updateStatus(loan.id, 'rejected');
                                        },
                                        child: const Text("Ya, Tolak", style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: const Text("Tolak", style: TextStyle(color: Colors.red)),
                            ),
                          ),
                          
                          const SizedBox(width: 10),
                          Expanded(child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: isTinggi ? Colors.green : Colors.green),
                            onPressed: () => _approveWithInterest(loan.id, loan.score),
                            child: Text(isTinggi ? "Setujui Langsung" : "Setujui"),
                          )),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );
}
  void _showDisbursementDialog(LoanModel loan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi Pencairan"),
        content: Text(
            "Pastikan uang tunai sebesar Rp ${Utils.formatCurrency(loan.amount)} sudah diserahkan kepada member. Sistem akan mencatat pengeluaran kas."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              try {
                // 1. Catat transaksi pencairan ke database
                await _repo.recordTransaction(
                  memberId: loan.userId,
                  loanId: loan.id,
                  type: 'pencairan',
                  amount: loan.amount,
                  note: 'Pencairan tunai di kantor koperasi',
                );
                // 2. Update status pinjaman menjadi disbursed (sudah cair)
                await _repo.updateLoanStatus(loan.id, 'disbursed');

                if (mounted) {
                  Navigator.pop(context); // Tutup dialog
                  Navigator.pop(context); // Tutup bottom sheet detail
                  _loadAllData(); // Refresh data tampilan
                }
              } catch (e) {
                print("Error disbursement: $e");
              }
            },
            child: const Text("Ya, Sudah Cair", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  void _showTransactionDetails(Map<String, dynamic> tx) {
    final String imageLink = tx['proofImage']?.toString() ?? '';
    
    // DEBUG: Cek di terminal VS Code kamu saat klik Maulana
    print("DEBUG: Tipe Transaksi: '${tx['type']}' | Status: '${tx['rawStatus']}'");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Detail ${tx['type']}"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow("Member", tx['userName'] ?? 'Unknown'),
              _buildDetailRow("Nominal", "Rp ${Utils.formatCurrency(tx['amount'])}"),
              _buildDetailRow("Tanggal", DateFormat('dd MMM yyyy').format(tx['date'])),
              _buildDetailRow("Status", tx['status'] ?? '-'),
              const SizedBox(height: 15),
              
              if (imageLink.isNotEmpty) ...[
                const Text("Bukti Transfer:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 200, width: 300,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageLink, fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) =>
                          progress == null ? child : const Center(child: CircularProgressIndicator()),
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 100,
                          width: double.infinity,
                          color: Colors.grey[200],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.broken_image, color: Colors.grey),
                              Text("Gagal memuat gambar", style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          // Tombol Verifikasi Lunas (Hijau) - hanya untuk status pending
          if ((tx['rawStatus'] == 'pending' || tx['status'] == 'Pending') &&
               (tx['type'].toString().toLowerCase().trim() == 'angsuran' || tx['type'].toString().toLowerCase().trim() == 'installment'))
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                try {
                  // Ubah status transaksi menjadi 'success'
                  await _repo.updateTransactionStatus(tx['id'], 'success');

                  if (mounted) {
                    Navigator.pop(context);
                    _loadAllData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Pembayaran berhasil diverifikasi sebagai LUNAS!"),
                        backgroundColor: Colors.green
                      )
                    );
                  }
                } catch (e) {
                  print("Gagal verifikasi pembayaran: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Gagal memverifikasi pembayaran"),
                        backgroundColor: Colors.red
                      )
                    );
                  }
                }
              },
              child: const Text("Verifikasi Lunas", style: TextStyle(color: Colors.white)),
            ),

          // Tombol Tutup (selalu ada)
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tutup")),
        ],
      ),
    );
  }


  int _calculateEligibilityScore(LoanModel loan) {
    // This is a simplified calculation - in real app, this would be more complex
    // Based on survey criteria: Character, Capacity, Capital, Collateral, Conditions
    int baseScore = loan.score; // Assuming loan.score is the survey score

    // Additional factors could be added here
    // For now, return the survey score as eligibility score
    return baseScore.clamp(0, 100);
  }

  String _getScoreCategory(int score) {
    if (score >= 80) return 'Tinggi';
    if (score >= 60) return 'Sedang';
    return 'Rendah';
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child: Text('$label:',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildLoanDetailSheet(LoanModel loan) {
    UserModel? user;
    try {
      user = _users.firstWhere((u) => u.id == loan.userId);
    } catch (e) {
      user = null;
    }

    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Detail Pengajuan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(),
          if (user != null) ...[
            ListTile(
              leading: const Icon(Icons.person, color: Colors.blue),
              title: Text(user.name),
              subtitle: Text(user.email),
              trailing: Chip(
                label: Text(user.isVerified ? 'Verified' : 'Unverified'),
                backgroundColor:
                    user.isVerified ? Colors.green[100] : Colors.orange[100],
              ),
            ),
            const Divider(),
          ],
          _buildDetailRow('ID Pinjaman',
              loan.id.length > 8 ? loan.id.substring(0, 8) : loan.id),
          _buildDetailRow('Tanggal',
              DateFormat('dd MMM yyyy HH:mm').format(loan.createdAt)),
          _buildDetailRow('Jumlah', 'Rp ${Utils.formatCurrency(loan.amount)}'),
          _buildDetailRow('Tenor', '${loan.tenor} Bulan'),
          _buildDetailRow('Tujuan', loan.purpose),
          if (loan.score > 0)
            _buildDetailRow('Skor Survey', '${loan.score} / 100'),
          // PASTE KODE INI:
Container(
  margin: const EdgeInsets.symmetric(vertical: 10),
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: _getStatusColor(loan.status),
    borderRadius: BorderRadius.circular(20),
  ),
  // Logika: Hanya bisa diklik jika sudah selesai (survey_completed)
  child: loan.status == 'survey_completed' 
    ? InkWell(
        onTap: () => _showSurveyResults(loan),
        child: const Text(
          'LIHAT HASIL SURVEY',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
          ),
        ),
      )
    : Text(
        // Jika masih 'surveyed', tampilkan teks label saja (tidak bisa diklik)
        StatusHelper.getStatusLabel(loan.status).toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
),
          const SizedBox(height: 20),
          if (loan.status == 'pending')
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  // Tombol Approve/Reject untuk pending loans
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.close, color: Colors.red),
                          label: const Text('Tolak',
                              style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () {
                            final TextEditingController reasonController = TextEditingController();

                            showDialog(
                              context: context,
                              builder: (reasonDialogContext) => AlertDialog(
                                title: const Text("Alasan Penolakan"),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text("Masukkan alasan penolakan pengajuan pinjaman ini:"),
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: reasonController,
                                      maxLines: 3,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        hintText: 'Contoh: Dokumen tidak lengkap, skor kelayakan rendah, dll.',
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(reasonDialogContext),
                                    child: const Text("Batal"),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      final reason = reasonController.text.trim();
                                      if (reason.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text("Harap isi alasan penolakan"),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }

                                      Navigator.pop(reasonDialogContext); // Tutup dialog alasan

                                      // Tampilkan dialog konfirmasi
                                      showDialog(
                                        context: context,
                                        builder: (confirmDialogContext) => AlertDialog(
                                          title: const Text("Konfirmasi Penolakan"),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text("Apakah Anda yakin ingin menolak pengajuan pinjaman ini?"),
                                              const SizedBox(height: 10),
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.red[50],
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.red[300]!),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      "Alasan:",
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      reason,
                                                      style: const TextStyle(color: Colors.red),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(confirmDialogContext),
                                              child: const Text("Batal"),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                              onPressed: () async {
                                                Navigator.pop(confirmDialogContext); // Tutup dialog konfirmasi

                                                // Simpan alasan ke field notes
                                                await _repo.updateLoanField(loan.id, 'notes', 'Ditolak: $reason');

                                                // Update status jadi rejected
                                                _updateStatus(loan.id, 'rejected');
                                              },
                                              child: const Text("Ya, Tolak", style: TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: const Text("Lanjutkan"),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: const Text('Setujui',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () => _approveWithInterest(loan.id, loan.score),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Tombol Proses Survey tetap ada
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.assignment, color: Colors.blue),
                      label: const Text('Proses Survey',
                          style: TextStyle(color: Colors.blue)),
                      onPressed: () => _updateStatus(loan.id, 'surveyed'),
                    ),
                  ),
                ],
              ),
            ),
            // TOMBOL BARU: Muncul jika sudah disetujui
          if (loan.status == 'approved')
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  icon: const Icon(Icons.payments, color: Colors.white),
                  label: const Text('CATAT PENCAIRAN TUNAI',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () => _showDisbursementDialog(loan), // Panggil fungsi di atas
                ),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'disbursed': // Tambahkan ini agar hijau
        return Colors.green;
      case 'approved':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'surveyed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    return StatusHelper.getStatusIcon(status);
  }

  List<LoanModel> get _filteredLoans {
    return _loans.where((loan) {
      bool matchesSearch = true;
      if (_searchQuery.isNotEmpty) {
        matchesSearch = loan.id.contains(_searchQuery) ||
            loan.userId.contains(_searchQuery);
      }
      if (_statusFilter != 'all')
        return matchesSearch && loan.status == _statusFilter;
      return matchesSearch;
    }).toList();
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatCard(
                  'Total Pinjaman',
                  '${_stats['totalLoans']}',
                  Icons.attach_money,
                  Colors.blue,
                  'Rp ${Utils.formatCurrency(_stats['totalAmount'])}'),
              _buildStatCard('Pending', '${_stats['pendingLoans']}',
                  Icons.pending_actions, Colors.orange, 'Menunggu'),
              _buildStatCard('Disetujui', '${_stats['approvedLoans']}',
                  Icons.check_circle, Colors.green, 'Aktif'),
              _buildStatCard('Anggota', '${_stats['totalUsers']}', Icons.people,
                  Colors.purple, '${_stats['verifiedUsers']} Verified'),
              _buildStatCard(
                  'Saldo Kas',
                  'Rp ${Utils.formatCurrency(_stats['currentCash'])}',
                  Icons.account_balance_wallet,
                  Colors.teal,
                  'Tersedia untuk Cair'),
              _buildStatCard(
                  'SHU Terkumpul (2025)',
                  'Rp 4.000.000',
                  Icons.account_balance,
                  Colors.green,
                  'Ditentukan melalui RAT'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Aktivitas Terkini',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ..._loans
                        .take(5)
                        .map((loan) => _buildActivityItem(loan))
                        .toList(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoansTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
                hintText: 'Cari ID Pinjaman...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder()),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: ['all', 'pending', 'surveyed', 'survey_completed', 'approved', 'disbursed', 'rejected']
                .map((status) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(status.toUpperCase()),
                  selected: _statusFilter == status,
                  onSelected: (val) => setState(() => _statusFilter = status),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _filteredLoans.length,
            itemBuilder: (context, index) =>
                _buildActivityItem(_filteredLoans[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildUsersTab() {
    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: user.isVerified
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.orange.withValues(alpha: 0.2),
              child: Icon(Icons.person,
                  color: user.isVerified ? Colors.green : Colors.orange),
            ),
            title: Text(user.name),
            subtitle: Text(user.email),
            trailing:
                Chip(label: Text(user.role), backgroundColor: Colors.blue[50]),
            onTap: () => _showUserDetails(user),
          ),
        );
      },
    );
  }

  Widget _buildTransactionsTab() {
    return ListView.builder(
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        // Cek apakah transaksi ini adalah pencairan yang sudah sukses
        final bool isSuccess = tx['rawStatus'] == 'approved' || tx['rawStatus'] == 'disbursed';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSuccess
                  ? Colors.green.withOpacity(0.2) // Hijau jika sukses cair
                  : Colors.orange.withOpacity(0.2),
              child: Icon(
                isSuccess ? Icons.arrow_downward : Icons.access_time,
                color: isSuccess ? Colors.green : Colors.orange,
              ),
            ),
            title: Text(tx['userName']),
            subtitle: Text(
                '${tx['type']} • ${DateFormat('dd MMM').format(tx['date'])}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Rp ${Utils.formatCurrency(tx['amount'])}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  // GANTI BAGIAN INI: Pakai fungsi pemetaan kita yang baru
                  _mapStatusToLabel(tx['rawStatus']),
                  style: TextStyle(
                    fontSize: 10,
                    // Pastikan warnanya hijau jika 'success'
                    color: (tx['rawStatus'] == 'success' || tx['rawStatus'] == 'approved')
                           ? Colors.green
                           : Colors.orange,
                  ),
                ),
              ],
            ),
            onTap: () => _showTransactionDetails(tx),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color, String subtitle) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 5),
            Text(title,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(subtitle, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(LoanModel loan) {
  UserModel? user;
  try {
    user = _users.firstWhere((u) => u.id == loan.userId);
  } catch (_) {}

  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: _getStatusColor(loan.status).withOpacity(0.1),
        child: Icon(_getStatusIcon(loan.status),
            color: _getStatusColor(loan.status)),
      ),
      // GUNAKAN CROSSAXISALIGNMENT START AGAR RAPI
      title: Text(
        user?.name ?? 'User ${loan.userId.substring(0, 4)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis, // Jika nama terlalu panjang jadi titik-titik
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        'Rp ${Utils.formatCurrency(loan.amount)} • ${loan.tenor} Bulan',
        style: const TextStyle(fontSize: 12),
      ),
      // CHIP STATUS TETAP DI KANAN
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getStatusColor(loan.status).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          StatusHelper.getStatusLabel(loan.status).toUpperCase(),
          style: TextStyle(
              color: _getStatusColor(loan.status),
              fontSize: 10,
              fontWeight: FontWeight.bold),
        ),
      ),
      onTap: () => _showLoanDetails(_loans.indexOf(loan)),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Admin Dashboard',
            style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData),
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => Utils.confirmLogout(context, auth)),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Home'),
            Tab(icon: Icon(Icons.attach_money), text: 'Pinjaman'),
            Tab(icon: Icon(Icons.people), text: 'Anggota'),
            Tab(icon: Icon(Icons.history), text: 'Transaksi'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(),
                _buildLoansTab(),
                _buildUsersTab(),
                _buildTransactionsTab(),
              ],
            ),
    );
  }
}
