import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'data_service.dart';
import 'loan_model.dart';
import 'utils.dart';

class PaymentUploadScreen extends StatefulWidget {
  final LoanModel loan;
  final int installmentNumber;
  final double amountToPay;

  const PaymentUploadScreen({
    Key? key,
    required this.loan,
    required this.installmentNumber,
    required this.amountToPay,
  }) : super(key: key);

  @override
  State<PaymentUploadScreen> createState() => _PaymentUploadScreenState();
}

class _PaymentUploadScreenState extends State<PaymentUploadScreen> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _isSuccess = false; // Tambahan untuk logika tampilan sukses
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Mengisi otomatis nominal berdasarkan data dari DB
    _amountController.text = Utils.formatCurrency(widget.amountToPay);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _submitPayment() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih foto bukti pembayaran')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final imageUrl = await AppRepository().uploadPaymentProof(_selectedImage!);
      final auth = Provider.of<AuthService>(context, listen: false);
      
      // Ambil angka murni untuk dikirim ke DB
      final numericAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final amount = double.tryParse(numericAmount) ?? 0;

      await AppRepository().submitPayment(
        loanId: widget.loan.id,
        userId: auth.currentUser!.id,
        amount: amount,
        proofImageUrl: imageUrl,
        installmentMonth: widget.installmentNumber,
      );

      if (mounted) {
        setState(() {
          _isUploading = false;
          _isSuccess = true; // Berpindah ke tampilan Avatar Bahagia
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // WIDGET BARU: Tampilan Sukses dengan Avatar Bahagia
  Widget _buildSuccessView() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sentiment_very_satisfied, size: 120, color: Colors.green),
              const SizedBox(height: 24),
              const Text(
                "Terima Kasih, Kak!",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 12),
              const Text(
                "Bukti pembayaran bulan ini sudah kami terima. Mohon tunggu konfirmasi dari Admin ya!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text("KEMBALI KE SLIP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Jika sukses, tampilkan view bahagia
    if (_isSuccess) return _buildSuccessView();

    return Scaffold(
      backgroundColor: const Color(0xFFF3E8FF),
      appBar: AppBar(
        title: const Text('Upload Bukti Pembayaran'),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Loan Info Card (Struktur aslimu)
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Angsuran Bulan ke-${widget.installmentNumber}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                    ),
                    const SizedBox(height: 8),
                    Text('Pinjaman: Rp ${Utils.formatCurrency(widget.loan.amount)}', style: const TextStyle(fontSize: 14)),
                    Text('Tenor: ${widget.loan.tenor} Bulan', style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Amount Input (Read Only)
            TextField(
              controller: _amountController,
              readOnly: true, // Kunci agar nominal tidak diubah Maulana
              decoration: InputDecoration(
                labelText: 'Jumlah Pembayaran (Rp)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.money),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 16),

            // Description Input
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Deskripsi (Opsional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Foto Bukti Pembayaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // Penampil Gambar (Universal HP & Web)
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey.withOpacity(0.05),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: kIsWeb 
                        ? Image.network(_selectedImage!.path, fit: BoxFit.cover) 
                        : Image.file(_selectedImage!, fit: BoxFit.cover),
                    )
                  : const Center(child: Icon(Icons.image, size: 50, color: Colors.grey)),
            ),
            const SizedBox(height: 16),

            // Tombol Kamera & Galeri
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Kamera'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeri'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Info Box (Struktur aslimu)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Text("Informasi Pembayaran", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "• Pastikan foto bukti transfer terlihat jelas\n• Pastikan nominal sesuai dengan tagihan",
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade800, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _submitPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Kirim Pembayaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}