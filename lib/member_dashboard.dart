import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'data_service.dart'; // AppRepository
import 'loan_model.dart';
import 'utils.dart';
import 'profile_screen.dart';
import 'transaction_screen.dart'; // Riwayat Pembayaran
import 'kyc_form.dart';
import 'status_helper.dart';
import 'slip_angsuran_screen.dart';

class MemberDashboard extends StatefulWidget {
  const MemberDashboard({Key? key}) : super(key: key);
  @override
  State<MemberDashboard> createState() => _MemberDashboardState();
}

class _MemberDashboardState extends State<MemberDashboard> {
  int _selectedIndex = 0;
  List<LoanModel> _loans = [];
  bool _hasNotification = false;
  List<dynamic> _userTransactions = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.currentUser == null) return;

    // Refresh user data to get latest SHU information
    await auth.refreshCurrentUser();

    final data = await AppRepository().getMyLoans(auth.currentUser!.id);
    final transactions = await AppRepository().getUserTransactions(auth.currentUser!.id);

    // Store transactions for later use in calculating remaining amounts
    _userTransactions = transactions;

    if (mounted) {
      setState(() {
        _loans = data;
        // Notifikasi nyala jika ada pinjaman yang SUDAH DIPROSES (bukan pending)
        _hasNotification = data.any((l) => StatusHelper.isProcessed(l.status));
      });
    }
  }

  void _showNotifications() {
    // Tampilkan List Pinjaman yang sudah ada statusnya
    final updates = _loans.where((l) => l.status != 'pending').toList();

    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => Container(
              padding: const EdgeInsets.all(20),
              height: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Notifikasi",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Divider(),
                  if (updates.isEmpty)
                    const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Text("Belum ada pemberitahuan baru."))
                  else
                    Expanded(
                      child: ListView.builder(
                          itemCount: updates.length,
                          itemBuilder: (ctx, i) {
                            final l = updates[i];
                            String title;
                            IconData icon;
                            Color color;
                            // Ganti blok if-else di dalam ListView.builder notifikasi dengan ini:
if (l.status == 'approved') {
  title = "DISETUJUI (AMBIL DI KANTOR)";
  icon = Icons.check_circle;
  color = Colors.green;
}
// 1. Label saat Admin klik "Proses Survey" (Status: surveyed)
else if (l.status == 'surveyed') {
  title = "Dalam Proses Survey"; // Tampilan baru agar tidak membingungkan
  icon = Icons.directions_run; // Icon orang berjalan
  color = Colors.blue;
}
// 2. Label saat Surveyor sudah kirim laporan (Status: survey_completed)
else if (l.status == 'survey_completed') {
  title = "Selesai Disurvey";
  icon = Icons.assignment_turned_in;
  color = Colors.blue;
}
// 3. Label saat pinjaman sudah dicairkan (Status: disbursed)
else if (l.status == 'disbursed') {
  title = "Sudah Dicairkan";
  icon = Icons.monetization_on;
  color = Colors.green;
}
else {
  title = "Pinjaman Ditolak";
  icon = Icons.cancel;
  color = Colors.red;
}
                            return ListTile(
                              leading: Icon(icon, color: color),
                              title: Text(title),
                              subtitle: Text(
                                  "Rp ${Utils.formatCurrency(l.amount)} - ${l.purpose}"),
                            );
                          }),
                    )
                ],
              ),
            ));
  }

  void _onAjukanPinjaman() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    if (user != null && user.isVerified) {
      // Sudah diverifikasi admin, langsung ke form pinjaman
      Navigator.pushNamed(context, '/loan-application')
          .then((_) => _fetchData());
    } else if (user != null && user.nik.isNotEmpty && user.address.isNotEmpty && user.job.isNotEmpty) {
      // Sudah kirim KYC, tapi belum diverifikasi admin
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Verifikasi Data Diri"),
          content: const Text("Admin sedang memverifikasi data Anda.Mohon bersabar.😊"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } else {
      // Belum isi KYC
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Lengkapi Data Diri (KYC) Terlebih Dahulu!")));
      Navigator.push(
              context, MaterialPageRoute(builder: (_) => const KYCFormScreen()))
          .then((_) => _fetchData());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final pages = [
      _buildHome(auth),
      const TransactionScreen(), // Riwayat Pembayaran
      const ProfileScreen()
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF3E8FF),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        selectedItemColor: const Color(0xFF8B5CF6),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long), label: 'History'), // Icon diubah
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile')
        ],
      ),
    );
  }

  Widget _buildHome(AuthService auth) {
    // Calculate total active loan by subtracting only the principal portions of successful installment payments from disbursed loans
    double totalLoan = _loans
        .where((l) => l.status == 'disbursed')
        .fold(0.0, (sum, loan) {
          // Count successful installments
          int paidInstallments = _userTransactions
              .where((tx) => tx.loanId == loan.id && tx.type.toLowerCase() == 'installment' && tx.status.toLowerCase() == 'success')
              .length;
          // Calculate principal per installment (rounded for consistency)
          double principalPerInstallment = (loan.amount / loan.tenor).roundToDouble();
          // Calculate total paid principal
          double paidPrincipal = paidInstallments * principalPerInstallment;
          // Calculate remaining balance
          double remaining = loan.amount - paidPrincipal;
          // Ensure it doesn't go below 0
          return sum + (remaining > 0 ? remaining : 0.0);
        });

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: SingleChildScrollView(
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 120),
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(30))),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Hello, ${auth.currentUser?.name}!",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                        Text(
                            auth.currentUser?.isVerified == true
                                ? "Member Verified"
                                : "Belum Verifikasi",
                            style: const TextStyle(color: Colors.white70)),
                      ]),
                  GestureDetector(
                    onTap: _showNotifications,
                    child: Stack(children: [
                      const Icon(Icons.notifications,
                          color: Colors.white, size: 30),
                      if (_hasNotification)
                        Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                    color: Colors.red, shape: BoxShape.circle)))
                    ]),
                  )
                ]),
          ),

          // Cards
          Transform.translate(
            offset: const Offset(0, -80),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Simpanan Card (Statis sesuai request)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: const Color(0xFFA78BFA),
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Icon(Icons.wallet, color: Colors.white),
                                SizedBox(height: 10),
                                Text("Simpanan Wajib",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                Text("Rp 1.000.000",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                              ]),
                          const Icon(Icons.savings,
                              size: 60, color: Colors.white24)
                        ]),
                  ),
                  const SizedBox(height: 15),
                  // Total Pinjaman Aktif (DINAMIS)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 10)
                        ]),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Total Pinjaman Aktif",
                                    style: TextStyle(color: Colors.grey)),
                                const SizedBox(height: 5),
                                // TAMPILKAN TOTAL YANG DISETUJUI ADMIN
                                Text("Rp ${Utils.formatCurrency(totalLoan)}",
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF7C3AED))),
                              ]),
                          const Icon(Icons.monetization_on,
                              size: 50, color: Color(0xFFF3E8FF))
                        ]),
                  ),
                  const SizedBox(height: 15),
                  // SHU Card (Dynamic)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 182, 186, 60),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 10)
                        ]),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("SHU Anda tahun ${auth.currentUser?.shuPeriode ?? '2024'}",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 5),
                                Text("Rp ${Utils.formatCurrency(double.tryParse(auth.currentUser?.shu ?? '0') ?? 0)}",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 5),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      auth.currentUser != null && DateTime.now().difference(auth.currentUser!.joinDate).inDays < 365
                                        ? "Status: Belum Berhak SHU"
                                        : auth.currentUser?.shuStatus == 'Sudah Dicairkan'
                                          ? "Status: Sudah Dicairkan"
                                          : "Status: ${auth.currentUser?.shuStatus ?? 'Belum Dicairkan'}",
                                      style: const TextStyle(
                                          color: Color.fromARGB(200, 255, 255, 255),
                                          fontSize: 12),
                                    ),
                                    if (auth.currentUser != null && DateTime.now().difference(auth.currentUser!.joinDate).inDays < 365)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Text(
                                          "*SHU akan tersedia setelah masa keanggotaan mencapai 1 tahun",
                                          style: TextStyle(
                                            color: Color.fromARGB(180, 237, 13, 13),
                                            fontSize: 10,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      )
                                    else if (auth.currentUser?.shuStatus == 'Belum Dicairkan' ||
                                        (auth.currentUser?.shuStatus == null && auth.currentUser?.shu != '0'))
                                      const Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Text(
                                          "*SHU sudah tersedia. Silahkan datang ke kantor koperasi untuk pencairan.",
                                          style: TextStyle(
                                            color: Color.fromARGB(180, 237, 13, 13),
                                            fontSize: 10,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ]),
                          const Icon(Icons.donut_large,
                              size: 50, color: Color.fromARGB(57, 0, 0, 0))
                        ]),
                  ),
                ],
              ),
            ),
          ),



          // Menu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _menuItem(Icons.add_circle_outline, "Ajukan\nPinjaman",
                    _onAjukanPinjaman),
                _menuItem(Icons.receipt_long, "Riwayat\nPembayaran",
                    () => setState(() => _selectedIndex = 1)),
                _menuItem(Icons.description, "Slip\nAngsuran",
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SlipAngsuranScreen()))),
              ],
            ),
          ),

          const SizedBox(height: 30),



          // Riwayat Pengajuan List
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Status Pengajuan Terkini",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                if (_loans.isEmpty)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text("Belum ada pengajuan.")))
                else
                  ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _loans.length,
                      itemBuilder: (ctx, i) {
                        final l = _loans[i];
                        Color color = StatusHelper.getStatusColor(l.status);
                        String statusText =
                            StatusHelper.getStatusLabel(l.status);

                        // Define title, icon based on status
                        String title;
                        IconData icon;
                        if (l.status == 'approved') {
                          title = "DISETUJUI (AMBIL DI KANTOR)";
                          icon = Icons.check_circle;
                        } else if (l.status == 'surveyed') {
                          title = "Dalam Proses Survey";
                          icon = Icons.directions_run;
                        } else if (l.status == 'survey_completed') {
                          title = "Selesai Disurvey";
                          icon = Icons.assignment_turned_in;
                        } else if (l.status == 'disbursed') {
                          title = "Sudah Dicairkan";
                          icon = Icons.monetization_on;
                        } else if (l.status == 'rejected') {
                          title = "Pinjaman Ditolak";
                          icon = Icons.cancel;
                        } else {
                          title = "Pengajuan Pending";
                          icon = Icons.hourglass_empty;
                        }

                        return Card(
                          elevation: 0,
                          color: Colors.grey[50],
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: color),
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Menampilkan nominal dan tujuan (Rp 150.000 - beli saham)
                                Text("Rp ${Utils.formatCurrency(l.amount)} - ${l.purpose}"),
                                
                                // TAMBAHKAN INI: Menampilkan alasan penolakan dari field 'notes'
                                if (l.status == 'rejected' && l.notes != null && l.notes!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      "Alasan: ${l.notes}",
                                      style: const TextStyle(
                                        color: Colors.red, 
                                        fontSize: 11, 
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      })
              ],
            ),
          )
        ]),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)
            ]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 30, color: const Color(0xFF7C3AED)),
          const SizedBox(height: 10),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
        ]),
      ),
    );
  }
}
