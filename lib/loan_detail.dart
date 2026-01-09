// loan_detail.dart
import 'package:flutter/material.dart';
import 'loan_model.dart';
import 'utils.dart';

class LoanDetail extends StatelessWidget {
  final LoanModel loan;
  const LoanDetail({Key? key, required this.loan}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Hitung Estimasi Bunga (Contoh: 2.5% Flat)
    double totalBunga = loan.amount * 0.025 * loan.tenor;
    double totalBayar = loan.amount + totalBunga;
    double cicilan = totalBayar / loan.tenor;

    return Scaffold(
      appBar: AppBar(title: const Text("Detail Pinjaman")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _row("Status", loan.status, color: Colors.blue),
                const Divider(),
                _row("Pokok Pinjaman", "Rp ${Utils.formatCurrency(loan.amount)}"),
                _row("Tenor", "${loan.tenor} Bulan"),
                _row("Tujuan", loan.purpose),
                const Divider(),
                _row("Estimasi Bunga", "Rp ${Utils.formatCurrency(totalBunga)}"),
                _row("Total Bayar", "Rp ${Utils.formatCurrency(totalBayar)}", isBold: true),
                _row("Cicilan/Bulan", "Rp ${Utils.formatCurrency(cicilan)}", isBold: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String val, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(val, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 16 : 14, color: color ?? Colors.black)),
        ],
      ),
    );
  }
}