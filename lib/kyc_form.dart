import 'dart:io';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk Filtering Angka
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'restapi.dart';
import 'user_model.dart';

class KYCFormScreen extends StatefulWidget {
  const KYCFormScreen({Key? key}) : super(key: key);
  @override
  State<KYCFormScreen> createState() => _KYCFormScreenState();
}

class _KYCFormScreenState extends State<KYCFormScreen> {
  // Kunci untuk Validasi Form
  final _formKey = GlobalKey<FormState>();

  final _phoneCtrl = TextEditingController();
  final _nikCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _jobCtrl = TextEditingController();
  final _officeAddrCtrl = TextEditingController();
  
  XFile? _selfie;
  XFile? _ktp;
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  Future<void> _submitKYC() async {
    // 1. CEK VALIDASI TEXT (NIK 16 digit, dll)
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Mohon perbaiki data yang merah/salah!"),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // 2. CEK VALIDASI FOTO
    if (_selfie == null || _ktp == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Foto Selfie & KTP Wajib Diambil!"),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final api = DataService();

      // Upload Foto
      String selfieUrl = await api.upload(await _selfie!.readAsBytes(), "selfie_${DateTime.now().millisecondsSinceEpoch}.jpg");
      String ktpUrl = await api.upload(await _ktp!.readAsBytes(), "ktp_${DateTime.now().millisecondsSinceEpoch}.jpg");

      if (selfieUrl.isEmpty || ktpUrl.isEmpty) {
        throw Exception("Gagal upload gambar ke server");
      }

      // Update User Profile
      UserModel updated = UserModel(
        id: auth.currentUser!.id,
        email: auth.currentUser!.email,
        password: auth.currentUser!.password,
        role: auth.currentUser!.role,
        name: auth.currentUser!.name,
        joinDate: auth.currentUser!.joinDate,
        
        // Data Penting:
        phone: _phoneCtrl.text,
        nik: _nikCtrl.text,
        address: _addrCtrl.text,
        addressOffice: _officeAddrCtrl.text,
        job: _jobCtrl.text,
        selfieImage: selfieUrl,
        ktpImage: ktpUrl,
        isVerified: true, // STATUS RESMI VERIFIED
      );

      await auth.updateProfile(updated);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Verifikasi Data Berhasil!")));
      Navigator.pushReplacementNamed(context, '/loan-application');

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Terjadi Kesalahan: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // Widget Pembantu untuk Kotak Foto
  Widget _buildPhotoBox(String label, XFile? file, VoidCallback onTap) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 110, width: 140,
            decoration: BoxDecoration(
              color: Colors.grey[100], 
              border: Border.all(color: file == null ? Colors.grey : Colors.green, width: 2),
              borderRadius: BorderRadius.circular(10)
            ),
            child: file == null 
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.camera_alt, color: Colors.grey, size: 30), Text("Ambil Foto", style: TextStyle(fontSize: 10))])
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: kIsWeb ? Image.network(file.path, fit: BoxFit.cover) : Image.file(File(file.path), fit: BoxFit.cover)
                ),
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3E8FF),
      appBar: AppBar(
        title: const Text("Verifikasi Data Diri (KYC)", style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: const Color(0xFF8B5CF6),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form( // WRAP DENGAN FORM AGAR BISA VALIDASI
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Data Identitas Wajib Diisi Lengkap", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              // FOTO SECTION
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _buildPhotoBox("Selfie dengan KTP", _selfie, () async {
                  final f = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);
                  if(f!=null) setState(()=>_selfie=f);
                }),
                _buildPhotoBox("Foto E-KTP Asli", _ktp, () async {
                  final f = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);
                  if(f!=null) setState(()=>_ktp=f);
                }),
              ]),
              const Divider(height: 40),

              // NIK (VALIDASI KETAT)
              TextFormField(
                controller: _nikCtrl,
                keyboardType: TextInputType.number,
                maxLength: 16, // Max 16 Digit
                inputFormatters: [FilteringTextInputFormatter.digitsOnly], // Cuma boleh angka
                decoration: const InputDecoration(
                  labelText: "Nomor Induk Kependudukan (NIK)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.credit_card),
                  counterText: "", // Sembunyikan counter 0/16
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return "NIK wajib diisi";
                  if (value.length != 16) return "NIK harus pas 16 digit!";
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // NO HP
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: "Nomor Handphone Aktif", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_android)),
                validator: (value) {
                  if (value == null || value.isEmpty) return "No HP wajib diisi";
                  if (value.length < 10) return "No HP minimal 10 digit";
                  if (value.length > 13) return "No HP maksimal 13 digit";
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // ALAMAT DOMISILI
              TextFormField(
                controller: _addrCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: "Alamat Domisili Lengkap", border: OutlineInputBorder(), prefixIcon: Icon(Icons.home)),
                validator: (v) => v!.isEmpty ? "Alamat wajib diisi lengkap (Jalan, RT/RW)" : null,
              ),
              const SizedBox(height: 15),

              // PEKERJAAN
              TextFormField(
                controller: _jobCtrl,
                decoration: const InputDecoration(labelText: "Pekerjaan Saat Ini", border: OutlineInputBorder(), prefixIcon: Icon(Icons.work)),
                validator: (v) => v!.isEmpty ? "Pekerjaan wajib diisi" : null,
              ),
              const SizedBox(height: 15),

              // ALAMAT KANTOR
              TextFormField(
                controller: _officeAddrCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: "Alamat Kantor / Tempat Usaha", border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_city)),
                validator: (v) => v!.isEmpty ? "Alamat kantor wajib diisi" : null,
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitKYC,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                  child: _isSubmitting 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("VERIFIKASI DATA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}