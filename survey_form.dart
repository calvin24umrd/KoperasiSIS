import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'restapi.dart';
import 'config.dart';

class SurveyForm extends StatefulWidget {
  final String loanId;
  const SurveyForm({Key? key, required this.loanId}) : super(key: key);
  @override
  State<SurveyForm> createState() => _SurveyFormState();
}

class _SurveyFormState extends State<SurveyForm> {
  final _noteCtrl = TextEditingController();
  bool _isSubmitting = false;
  XFile? _locationPhoto;
  XFile? _collateralPhoto;
  final ImagePicker _picker = ImagePicker();

  // 5C Criteria Checkboxes
  final Map<String, Map<String, dynamic>> _criteria = {
    'Character': {
      'title': 'Character (Sifat & Kepribadian)',
      'items': [
        {'Member kooperatif dan menjawab pertanyaan dengan jujur': false},
        {'Data identitas sesuai dengan kondisi lapangan': false},
        {'Riwayat pinjaman sebelumnya tidak bermasalah': false},
        {'Memiliki reputasi baik di lingkungan tempat tinggal': false},
      ]
    },
    'Capacity': {
      'title': 'Capacity (Kemampuan Membayar)',
      'items': [
        {'Memiliki penghasilan tetap setiap bulan': false},
        {'Penghasilan mencukupi untuk membayar cicilan': false},
        {'Rasio cicilan tidak melebihi 30% dari penghasilan': false},
        {'Sumber penghasilan masih aktif dan berjalan': false},
      ]
    },
    'Capital': {
      'title': 'Capital (Modal / Aset Pribadi)',
      'items': [
        {'Memiliki aset pribadi (rumah, kendaraan, atau tabungan)': false},
        {'Aset digunakan untuk menunjang kegiatan ekonomi': false},
        {'Kondisi aset layak dan bernilai ekonomis': false},
        {'Modal usaha berasal dari dana pribadi, bukan utang': false},
      ]
    },
    'Collateral': {
      'title': 'Collateral (Jaminan)',
      'items': [
        {'Jaminan fisik tersedia dan dapat ditunjukkan': false},
        {'Kepemilikan jaminan sah atas nama member': false},
        {'Nilai jaminan sebanding dengan pinjaman': false},
        {'Dokumen jaminan lengkap dan valid': false},
      ]
    },
    'Condition': {
      'title': 'Condition (Kondisi Usaha & Ekonomi)',
      'items': [
        {'Usaha masih berjalan secara aktif': false},
        {'Tidak terdampak langsung krisis ekonomi': false},
        {'Lokasi usaha mendukung keberlangsungan usaha': false},
        {'Permintaan pasar terhadap usaha masih stabil': false},
      ]
    },
  };

  int get _calculatedScore {
    int totalChecked = 0;
    _criteria.forEach((key, value) {
      List<Map<String, bool>> items = value['items'];
      totalChecked += items.where((item) => item.values.first).length;
    });
    return totalChecked * 5; // Each checkbox = 5 points
  }

  String get _eligibilityStatus {
    int score = _calculatedScore;
    if (score >= 80) return 'LAYAK';
    if (score >= 65) return 'CUKUP LAYAK';
    if (score >= 50) return 'DIPERTIMBANGKAN';
    return 'TIDAK LAYAK';
  }

  Future<void> _submit() async {
    // Validasi Input
    if (_calculatedScore == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wajib centang minimal satu kriteria!")));
      return;
    }

    setState(() => _isSubmitting = true);

    // 1. Upload Foto Bukti (Jika ada)
    String locationPhotoName = "no_image";
    String collateralPhotoName = "no_image";

    if (_locationPhoto != null) {
      final bytes = await _locationPhoto!.readAsBytes();
      locationPhotoName = await DataService().upload(bytes, "location_${DateTime.now().millisecondsSinceEpoch}.jpg");
    }

    if (_collateralPhoto != null) {
      final bytes = await _collateralPhoto!.readAsBytes();
      collateralPhotoName = await DataService().upload(bytes, "collateral_${DateTime.now().millisecondsSinceEpoch}.jpg");
    }

    // Combine photos for surveyresults
    String photos = "$locationPhotoName|$collateralPhotoName";

    // 2. Simpan Data Survey ke collection 'surveyresults'
    await DataService().insertSurveyresults(
      appid,
      widget.loanId,
      "surveyor_01", // ID Surveyor (Hardcode dulu)
      photos,
      _calculatedScore.toString()
    );

    // 3. UPDATE DATA LOAN (PENTING!)
    // Update status jadi 'survey_completed' agar masuk ke Admin sebagai Hasil Survey
    await DataService().updateId('status', 'survey_completed', token, project, 'loans', appid, widget.loanId);

    // Update skor ke tabel loans agar Admin bisa langsung lihat tanpa join tabel
    await DataService().updateId('score', _calculatedScore.toString(), token, project, 'loans', appid, widget.loanId);

    // Update catatan jika ada
    if (_noteCtrl.text.isNotEmpty) {
      await DataService().updateId('notes', _noteCtrl.text, token, project, 'loans', appid, widget.loanId);
    }

    setState(() => _isSubmitting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Laporan Terkirim! Menunggu Admin.")));
      Navigator.pop(context); // Kembali ke dashboard
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Form Hasil Survey"), backgroundColor: const Color(0xFF8B5CF6)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [


            // 5C Criteria Checkboxes
            ..._criteria.entries.map((entry) {
              String key = entry.key;
              Map<String, dynamic> value = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    ...value['items'].asMap().entries.map<Widget>((itemEntry) {
                      int index = itemEntry.key;
                      Map<String, bool> item = itemEntry.value;
                      String text = item.keys.first;
                      bool isChecked = item.values.first;
                      return CheckboxListTile(
                        title: Text(text, style: const TextStyle(fontSize: 14)),
                        value: isChecked,
                        onChanged: (bool? value) {
                          setState(() {
                            _criteria[key]!['items'][index][text] = value ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      );
                    }).toList(),
                  ],
                ),
              );
            }).toList(),

            // Input Catatan
            const Text("Catatan Hasil Wawancara", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: "Contoh: Member memiliki usaha toko kelontong yang ramai, namun jaminan berupa motor tua sehingga nilai agunan kecil.",
                border: OutlineInputBorder()
              ),
            ),

            const SizedBox(height: 20),

            // Upload Foto Lokasi
            const Text("Foto Lokasi Rumah/Usaha", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                final x = await _picker.pickImage(source: ImageSource.camera);
                if (x != null) setState(() => _locationPhoto = x);
              },
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey)
                ),
                child: _locationPhoto == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                        SizedBox(height: 5),
                        Text("Ambil Foto Lokasi", style: TextStyle(color: Colors.grey)),
                      ]
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: kIsWeb
                        ? Image.network(_locationPhoto!.path, fit: BoxFit.cover)
                        : Image.file(File(_locationPhoto!.path), fit: BoxFit.cover)
                    ),
              ),
            ),

            const SizedBox(height: 20),

            // Upload Foto Jaminan
            const Text("Foto Barang Jaminan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                final x = await _picker.pickImage(source: ImageSource.camera);
                if (x != null) setState(() => _collateralPhoto = x);
              },
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey)
                ),
                child: _collateralPhoto == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                        SizedBox(height: 5),
                        Text("Ambil Foto Jaminan", style: TextStyle(color: Colors.grey)),
                      ]
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: kIsWeb
                        ? Image.network(_collateralPhoto!.path, fit: BoxFit.cover)
                        : Image.file(File(_collateralPhoto!.path), fit: BoxFit.cover)
                    ),
              ),
            ),

            const SizedBox(height: 30),

            // Tombol Submit
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("KIRIM LAPORAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'LAYAK':
        return Colors.green;
      case 'CUKUP LAYAK':
        return Colors.orange;
      case 'DIPERTIMBANGKAN':
        return Colors.yellow[700]!;
      case 'TIDAK LAYAK':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}