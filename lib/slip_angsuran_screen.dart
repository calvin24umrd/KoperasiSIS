import 'transaction_model.dart';
import 'status_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'data_service.dart';
import 'loan_model.dart';
import 'utils.dart';
import 'payment_upload_screen.dart';

class SlipAngsuranScreen extends StatefulWidget {
  const SlipAngsuranScreen({Key? key}) : super(key: key);

  @override
  State<SlipAngsuranScreen> createState() => _SlipAngsuranScreenState();
}

class _SlipAngsuranScreenState extends State<SlipAngsuranScreen> {
  List<LoanModel> _approvedLoans = [];
  bool _isLoading = true;
  int _refreshCounter = 0; // Counter untuk memaksa refresh FutureBuilder

  @override
  void initState() {
    super.initState();
    _fetchApprovedLoans();
  }

  Future<void> _fetchApprovedLoans() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.currentUser == null) return;

    final allLoans = await AppRepository().getMyLoans(auth.currentUser!.id);
    if (mounted) {
      setState(() {
        _approvedLoans = allLoans
            .where((l) => l.status == 'approved' || l.status == 'disbursed')
            .toList();
        _isLoading = false;
        _refreshCounter++; // Paksa refresh FutureBuilder
      });
    }
  }

  // Fungsi untuk menampilkan dialog peringatan jika sudah bayar tapi pending
  void _showPendingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sentiment_very_satisfied, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            const Text("Pembayaran Diproses",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            const Text(
              "Anda sudah mengirim bukti pembayaran untuk bulan ini. Mohon tunggu konfirmasi dari Admin ya, Kak!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: const StadiumBorder(),
              ),
              child: const Text("Oke, Saya Paham", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3E8FF),
      appBar: AppBar(
        title: const Text("Slip Angsuran"),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _refreshCounter++;
                _isLoading = true;
              });
              _fetchApprovedLoans();
            },
            tooltip: "Refresh Data",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _approvedLoans.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                      SizedBox(height: 20),
                      Text("Belum ada pinjaman yang disetujui",
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _approvedLoans.length,
                  itemBuilder: (ctx, i) {
                    final loan = _approvedLoans[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 20),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Pinjaman ${loan.purpose}",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF7C3AED),
                                      ),
                                    ),
                                    Text(
                                      "Rp ${Utils.formatCurrency(loan.amount)}",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: StatusHelper.getStatusColor(loan.status)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    StatusHelper.getStatusLabel(loan.status)
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: StatusHelper.getStatusColor(loan.status),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _summaryItem("Tenor", "${loan.tenor} Bulan"),
                                _summaryItem("Bunga", "${loan.interest}%/bulan"), // Diubah ke /bulan agar sesuai DB
                                _summaryItem("Penalty", "${loan.penalty}%"),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "Jadwal Angsuran",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildInstallmentSchedule(loan),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      ],
    );
  }

  Widget _buildInstallmentSchedule(LoanModel loan) {
    return FutureBuilder<List<TransactionModel>>(
      key: ValueKey('installments_${loan.id}_$_refreshCounter'), // Key unik untuk memaksa refresh
      future: AppRepository().getLoanTransactions(loan.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading transactions: ${snapshot.error}'),
          );
        }

        final transactions = snapshot.data ?? [];

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: loan.tenor,
          itemBuilder: (ctx, month) {
            final installmentData = transactions.firstWhere(
              (tx) => tx.installmentMonth == (month + 1) && tx.type.toLowerCase() == 'installment',
              orElse: () => TransactionModel(
                id: '', userId: '', loanId: '',
                amount: loan.amount / loan.tenor,
                type: 'installment', status: 'unpaid',
                timestamp: DateTime.now()
              ),
            );

            double monthlyPayment = installmentData.amount;
            String rawStatus = installmentData.status.toLowerCase();
            
            bool isPaid = (rawStatus == 'success' || rawStatus == 'approved');
            bool isPending = (rawStatus == 'pending');

            DateTime dueDate = loan.createdAt.add(Duration(days: (month + 1) * 30));

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isPaid ? Colors.green.withOpacity(0.05) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isPaid ? Colors.green.withOpacity(0.3) : Colors.grey.shade200,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Angsuran Bulan ${month + 1}", 
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text("Jatuh Tempo: ${Utils.formatDate(dueDate)}", 
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text("Rp ${Utils.formatCurrency(monthlyPayment)}",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Di dalam itemBuilder ListView.builder pada slip_angsuran_screen.dart

                      ElevatedButton.icon(

                        onPressed: () {
                          // Blokir keras untuk pending status
                          if (isPending) {
                            _showPendingDialog();
                            return;
                          }

                          // Jika sudah lunas, tidak lakukan apa-apa
                          if (isPaid) {
                            return;
                          }

                          // Jika unpaid, masuk ke upload screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaymentUploadScreen(
                                loan: loan,
                                installmentNumber: month + 1,
                                amountToPay: monthlyPayment,
                              ),
                            ),
                          ).then((_) {
                            setState(() {
                              _refreshCounter++; // Naikkan counter
                            });
                            _fetchApprovedLoans(); // Ambil ulang data pinjaman
                          });
                        },

                        icon: Icon(

                          isPending ? Icons.hourglass_empty : Icons.payments_outlined,

                          size: 16,

                        ),

                        label: Text(

                          isPaid ? "LUNAS" : isPending ? "PENDING" : "BAYAR ANGSURAN"

                        ),

                        style: ElevatedButton.styleFrom(

                          backgroundColor: isPaid ? Colors.grey : isPending ? Colors.orange : Colors.green,

                          foregroundColor: Colors.white,

                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),

                        ),

                      ),
                      const SizedBox(height: 4),
                      Text(
                        isPaid ? "SUDAH LUNAS" : (isPending ? "KONFIRMASI ADMIN" : "BELUM BAYAR"),
                        style: TextStyle(
                          color: isPaid ? Colors.green : (isPending ? Colors.orange : Colors.red),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


}