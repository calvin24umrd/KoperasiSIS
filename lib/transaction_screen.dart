import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'data_service.dart';
import 'transaction_model.dart';
import 'utils.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({Key? key}) : super(key: key);
  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  List<TransactionModel> _transactions = [];
  Map<String, List<TransactionModel>> _groupedTransactions = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.currentUser == null) return;

    // MENGAMBIL DATA RIWAYAT ASLI DARI DATABASE
    final data = await AppRepository().getUserTransactions(auth.currentUser!.id);

    if (mounted) {
      print("DEBUG: Total transactions fetched: ${data.length}");
      for (final tx in data) {
        print("DEBUG: Transaction - ID: ${tx.id}, LoanID: ${tx.loanId}, Type: ${tx.type}, Status: ${tx.status}, Amount: ${tx.amount}");
      }

      // Group transactions by loanId
      final grouped = <String, List<TransactionModel>>{};
      for (final tx in data) {
        if (!grouped.containsKey(tx.loanId)) {
          grouped[tx.loanId] = [];
        }
        grouped[tx.loanId]!.add(tx);
      }

      print("DEBUG: Number of loan groups: ${grouped.length}");
      grouped.forEach((loanId, txs) {
        print("DEBUG: Loan $loanId has ${txs.length} transactions");
      });

      // Sort each group by timestamp (newest first)
      grouped.forEach((loanId, txs) {
        txs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      });

      setState(() {
        _transactions = data;
        _groupedTransactions = grouped;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3E8FF),
      appBar: AppBar(
        title: const Text("Riwayat Transaksi"),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Menghilangkan tombol back jika jadi tab
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh), 
            onPressed: _fetchTransactions,
            tooltip: "Refresh Riwayat",
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _transactions.isEmpty 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.history_edu, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  Text("Belum ada riwayat transaksi", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ) 
          : RefreshIndicator(
              onRefresh: _fetchTransactions,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _groupedTransactions.length,
                itemBuilder: (ctx, i) {
                  final loanId = _groupedTransactions.keys.elementAt(i);
                  final loanTransactions = _groupedTransactions[loanId]!;

                  // Find the main transaction (prefer SUCCESS disbursement, fallback to any non-installment)
                  TransactionModel mainTx = loanTransactions.firstWhere(
                    (tx) => !tx.type.toLowerCase().contains('payment') &&
                           !tx.type.toLowerCase().contains('angsuran') &&
                           !tx.type.toLowerCase().contains('installment'),
                    orElse: () => loanTransactions.first, // fallback to first transaction if no non-installment found
                  );

                  // Get all installments for this loan (both SUCCESS and UNPAID)
                  final installments = loanTransactions.where(
                    (tx) => tx.type.toLowerCase().contains('payment') ||
                           tx.type.toLowerCase().contains('angsuran') ||
                           tx.type.toLowerCase().contains('installment')
                  ).toList();

                  // Sort installments by installment month
                  installments.sort((a, b) => (a.installmentMonth ?? 0).compareTo(b.installmentMonth ?? 0));

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        child: const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.blue,
                        ),
                      ),
                      title: Text(
                        mainTx.type.toLowerCase() == 'shu_pencairan' ? "Pencairan SHU" : "Pencairan Pinjaman",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(Utils.formatDate(mainTx.timestamp)),
                          Text(
                            mainTx.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: mainTx.status.toLowerCase() == 'success' ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      trailing: Text(
                        "Rp ${Utils.formatCurrency(mainTx.amount)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      children: installments.map((installment) {
                        final bool isSuccess = installment.status.toLowerCase() == 'success' ||
                                               installment.status.toLowerCase() == 'berhasil' ||
                                               installment.status.toLowerCase() == 'approved';

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: Colors.grey.shade200)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: isSuccess
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                                child: Icon(
                                  Icons.payments,
                                  size: 16,
                                  color: isSuccess ? Colors.green : Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Angsuran Bulan ke-${installment.installmentMonth}",
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      Utils.formatDate(installment.timestamp),
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                    Text(
                                      installment.status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isSuccess ? Colors.green : Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                "Rp ${Utils.formatCurrency(installment.amount)}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
    );
  }
}