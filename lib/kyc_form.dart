import 'dart:io';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart'; 
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
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _nikCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _jobCtrl = TextEditingController();
  final _officeAddrCtrl = TextEditingController();
  
  XFile? _selfie;
  XFile? _ktp;
  // REMOVED: ImagePicker unused
  bool _isSubmitting = false;

  // Camera Vars
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraReady = false;
  bool _isShowingCamera = false;
  String? _currentPhotoType; 

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
    } catch (e) {
      // ignore: avoid_print
      print("Camera init error: $e");
    }
  }

  Future<void> _startCamera(String type) async {
    if (_cameras == null || _cameras!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kamera tidak ditemukan!")));
      return;
    }

    var camera = _cameras!.firstWhere(
      (c) => c.lensDirection == (type == 'selfie' ? CameraLensDirection.front : CameraLensDirection.back),
      orElse: () => _cameras![0],
    );

    _cameraController = CameraController(camera, ResolutionPreset.high, enableAudio: false);
    await _cameraController!.initialize();
    
    if (mounted) {
      setState(() {
        _isCameraReady = true;
        _isShowingCamera = true;
        _currentPhotoType = type;
      });
    }
  }

  Future<void> _takePicture() async {
    if (!_cameraController!.value.isInitialized) return;
    
    try {
      final image = await _cameraController!.takePicture();
      
      if (!mounted) return;
      showDialog(
        context: context, 
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator())
      );
      
      await Future.delayed(const Duration(seconds: 2)); 
      if (mounted) Navigator.pop(context); 

      if (mounted) {
        setState(() {
          if (_currentPhotoType == 'selfie') _selfie = image;
          else _ktp = image;
          _isShowingCamera = false;
          _isCameraReady = false;
        });
      }
      _cameraController?.dispose();

    } catch (e) {
      // ignore: avoid_print
      print(e);
    }
  }

  Future<void> _submitKYC() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selfie == null || _ktp == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Foto Selfie & KTP Wajib!"), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final api = DataService();

      String selfieUrl = await api.upload(await _selfie!.readAsBytes(), "selfie_${DateTime.now().millisecondsSinceEpoch}.jpg");
      String ktpUrl = await api.upload(await _ktp!.readAsBytes(), "ktp_${DateTime.now().millisecondsSinceEpoch}.jpg");

      UserModel updated = UserModel(
        id: auth.currentUser!.id,
        email: auth.currentUser!.email,
        password: auth.currentUser!.password,
        role: auth.currentUser!.role,
        name: auth.currentUser!.name,
        joinDate: auth.currentUser!.joinDate,
        phone: _phoneCtrl.text,
        nik: _nikCtrl.text,
        address: _addrCtrl.text,
        addressOffice: _officeAddrCtrl.text,
        job: _jobCtrl.text,
        selfieImage: selfieUrl,
        ktpImage: ktpUrl,
        isVerified: true, 
      );

      await auth.updateProfile(updated);
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("Verifikasi Berhasil", style: TextStyle(color: Colors.green)),
          content: const Text("Data diri Anda telah tersimpan."),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (mounted) Navigator.pushReplacementNamed(context, '/loan-application'); 
              },
              child: const Text("Lanjut"),
            )
          ],
        )
      );

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildCameraOverlay() {
    return Stack(
      children: [
        SizedBox(height: double.infinity, width: double.infinity, child: CameraPreview(_cameraController!)),
        ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.black54, BlendMode.srcOut),
          child: Stack(
            children: [
              Container(decoration: const BoxDecoration(color: Colors.transparent, backgroundBlendMode: BlendMode.dstOut)),
              Center(
                child: Container(
                  height: _currentPhotoType == 'ktp' ? 200 : 300,
                  width: _currentPhotoType == 'ktp' ? 320 : 300,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(_currentPhotoType == 'ktp' ? 10 : 200)),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 30, left: 0, right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FloatingActionButton(backgroundColor: Colors.red, child: const Icon(Icons.close), onPressed: () { setState(() { _isShowingCamera = false; _cameraController?.dispose(); }); }),
              const SizedBox(width: 40),
              FloatingActionButton(backgroundColor: Colors.white, onPressed: _takePicture, child: const Icon(Icons.camera, color: Colors.black, size: 30)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildPhotoBox(String label, XFile? file, String type) {
    return Column(children: [
      GestureDetector(
        onTap: () => _startCamera(type),
        child: Container(
          height: 100, width: 140,
          decoration: BoxDecoration(color: Colors.grey[100], border: Border.all(color: file == null ? Colors.grey : Colors.green), borderRadius: BorderRadius.circular(10)),
          child: file == null 
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.camera_alt, color: Colors.grey), Text("Scan Foto", style: TextStyle(fontSize: 10))])
            : ClipRRect(borderRadius: BorderRadius.circular(8), child: kIsWeb ? Image.network(file.path, fit: BoxFit.cover) : Image.file(File(file.path), fit: BoxFit.cover)),
        ),
      ),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_isShowingCamera && _isCameraReady) return Scaffold(body: _buildCameraOverlay());

    return Scaffold(
      backgroundColor: const Color(0xFFF3E8FF),
      appBar: AppBar(title: const Text("Verifikasi Data Diri"), backgroundColor: const Color(0xFF8B5CF6)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(children: [
            const Text("Lengkapi data untuk verifikasi otomatis", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _buildPhotoBox("Selfie Wajah", _selfie, 'selfie'),
              _buildPhotoBox("E-KTP", _ktp, 'ktp'),
            ]),
            const SizedBox(height: 20),
            TextFormField(controller: _nikCtrl, maxLength: 16, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: "NIK", border: OutlineInputBorder(), counterText: ""), validator: (v) => v!.length != 16 ? "NIK harus 16 digit" : null),
            const SizedBox(height: 10),
            TextFormField(controller: _phoneCtrl, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: "No HP", border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? "Wajib diisi" : null),
            const SizedBox(height: 10),
            TextFormField(controller: _addrCtrl, maxLines: 2, decoration: const InputDecoration(labelText: "Alamat Domisili", border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? "Wajib diisi" : null),
            const SizedBox(height: 10),
            TextFormField(controller: _jobCtrl, decoration: const InputDecoration(labelText: "Pekerjaan", border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? "Wajib diisi" : null),
            const SizedBox(height: 10),
            TextFormField(controller: _officeAddrCtrl, decoration: const InputDecoration(labelText: "Alamat Kantor", border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? "Wajib diisi" : null),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _isSubmitting ? null : _submitKYC, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)), child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text("VERIFIKASI DATA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))
          ]),
        ),
      ),
    );
  }
}