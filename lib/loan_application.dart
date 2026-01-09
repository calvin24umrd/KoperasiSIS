import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'data_service.dart';
import 'loan_model.dart';
import 'package:coopconnect/utils.dart';

class LoanApplication extends StatefulWidget {
  const LoanApplication({Key? key}) : super(key: key);
  @override
  State<LoanApplication> createState() => _LoanApplicationState();
}

class _LoanApplicationState extends State<LoanApplication> {
  final _amountController = TextEditingController();
  final _purposeController = TextEditingController();
  int _tenor = 3; // Default 3 bulan
  bool _isSubmitting = false;



  Future<void> _submitApplication() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.currentUser == null) return;

    String cleanAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    double finalAmount = double.tryParse(cleanAmount) ?? 0;

    if (finalAmount <= 0) return;

    setState(() => _isSubmitting = true);
    
    final newLoan = LoanModel(
      id: '',
      userId: auth.currentUser!.id,
      amount: finalAmount,
      tenor: _tenor,
      status: 'pending',
      createdAt: DateTime.now(),
      purpose: _purposeController.text,
    );

    bool success = await AppRepository().createLoan(newLoan);
    setState(() => _isSubmitting = false);
    
    if (mounted && success) {
       Navigator.pop(context); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Form Pinjaman")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: "Jumlah Pinjaman (Rp)"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),

            // Dropdown Tenor 1-6 bulan
            const Text("Tenor Pinjaman", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              value: _tenor,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              items: List.generate(6, (index) => index + 1)
                  .map((month) => DropdownMenuItem(
                        value: month,
                        child: Text("$month Bulan"),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _tenor = value ?? 3),
            ),
            const SizedBox(height: 20),

            // Informasi Bunga dan Denda
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Informasi Bunga & Denda",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text("Bunga per bulan:"),
                      Text("1%", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text("Denda keterlambatan:"),
                      Text("0.5%", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Estimasi Pembayaran
            Builder(
              builder: (context) {
                String cleanAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
                double amount = double.tryParse(cleanAmount) ?? 0;
                double interestRate = 0.01; // 1% per bulan
                double totalInterest = amount * interestRate * _tenor;
                double estimatedTotal = amount + totalInterest;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Estimasi Pembayaran",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Pokok Pinjaman:"),
                          Text("Rp ${Utils.formatCurrency(amount)}"),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Bunga (${_tenor} bulan x 1%):"),
                          Text("Rp ${Utils.formatCurrency(totalInterest)}"),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Total Estimasi:",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text("Rp ${Utils.formatCurrency(estimatedTotal)}",
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        "*Estimasi belum termasuk denda keterlambatan jika ada",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _purposeController,
              decoration: const InputDecoration(labelText: "Tujuan Pinjaman"),
              maxLines: 2,
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitApplication,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Ajukan Pinjaman", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}