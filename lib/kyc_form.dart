import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart'; // Tambahkan package camera
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
  final _phoneCtrl = TextEditingController();
  final _nikCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _jobCtrl = TextEditingController();
  final _officeAddrCtrl = TextEditingController();

  XFile? _selfie;
  XFile? _ktp;
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  // Variabel untuk controller kamera
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraReady = false;
  bool _isShowingCamera = false;
  String? _currentPhotoType; // Untuk menentukan foto selfie atau KTP

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0], // Gunakan kamera belakang default
          ResolutionPreset.high,
        );

        await _cameraController!.initialize();
        setState(() {
          _isCameraReady = true;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing camera: $e');
      }
    }
  }

  Future<void> _openCameraForPhoto(String photoType) async {
    setState(() {
      _currentPhotoType = photoType;
      _isShowingCamera = true;
    });
  }

  Future<void> _takePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final XFile photo = await _cameraController!.takePicture();

      setState(() {
        if (_currentPhotoType == 'selfie') {
          _selfie = photo;
        } else if (_currentPhotoType == 'ktp') {
          _ktp = photo;
        }
        _isShowingCamera = false;
        _currentPhotoType = null;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error taking photo: $e');
      }
    }
  }

  Future<void> _closeCamera() {
    setState(() {
      _isShowingCamera = false;
      _currentPhotoType = null;
    });
    return Future.value();
  }

  Future<void> _submitKYC() async {
    if (_selfie == null || _ktp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Foto Selfie & KTP Wajib!")));
      return;
    }
    setState(() => _isSubmitting = true);

    final auth = Provider.of<AuthService>(context, listen: false);
    final api = DataService();

    // 1. Upload Foto
    String selfieUrl = await api.upload(await _selfie!.readAsBytes(),
        "selfie_${DateTime.now().millisecondsSinceEpoch}.jpg");
    String ktpUrl = await api.upload(await _ktp!.readAsBytes(),
        "ktp_${DateTime.now().millisecondsSinceEpoch}.jpg");

    // 2. Update User Profile
    UserModel updated = UserModel(
      id: auth.currentUser!.id,
      email: auth.currentUser!.email,
      password: auth.currentUser!.password,
      role: auth.currentUser!.role,
      name: auth.currentUser!.name,
      joinDate: auth.currentUser!.joinDate,
      // Data Baru:
      phone: _phoneCtrl.text,
      nik: _nikCtrl.text,
      address: _addrCtrl.text,
      addressOffice: _officeAddrCtrl.text,
      job: _jobCtrl.text,
      selfieImage: selfieUrl,
      ktpImage: ktpUrl,
      isVerified: true, // Menandakan user sudah isi data lengkap
    );

    // FIX: Menggunakan nama method yang benar 'updateProfile'
    await auth.updateProfile(updated);

    setState(() => _isSubmitting = false);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Data Diri Lengkap! Silakan Ajukan Pinjaman.")));
    Navigator.pushReplacementNamed(context, '/loan-application');
  }

  Widget _buildPhotoBox(String label, XFile? file, String photoType) {
    return GestureDetector(
      onTap: () => _openCameraForPhoto(photoType),
      child: Column(children: [
        Container(
          height: 100,
          width: 100,
          decoration: BoxDecoration(
              color: Colors.grey[200], border: Border.all(color: Colors.grey)),
          child: file == null
              ? const Icon(Icons.camera_alt, color: Colors.grey)
              : (kIsWeb
                  ? Image.network(file.path, fit: BoxFit.cover)
                  : Image.file(File(file.path), fit: BoxFit.cover)),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 12))
      ]),
    );
  }

  Widget _buildCameraView() {
    if (!_isCameraReady || _cameraController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        CameraPreview(_cameraController!),
        Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Tombol batal
              FloatingActionButton(
                onPressed: _closeCamera,
                backgroundColor: Colors.red,
                child: const Icon(Icons.close),
              ),
              // Tombol ambil foto
              FloatingActionButton(
                onPressed: _takePhoto,
                backgroundColor: Colors.white,
                child: const Icon(Icons.camera, color: Colors.black),
              ),
              // Tombol ganti kamera (jika tersedia lebih dari 1 kamera)
              if (_cameras != null && _cameras!.length > 1)
                FloatingActionButton(
                  onPressed: _switchCamera,
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.switch_camera),
                ),
            ],
          ),
        ),
        // Label jenis foto yang sedang diambil
        Positioned(
          top: 50,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            color: Colors.black54,
            child: Text(
              _currentPhotoType == 'selfie'
                  ? 'Ambil Foto Selfie + KTP'
                  : 'Ambil Foto KTP',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    final currentIndex = _cameras!.indexWhere((camera) =>
        camera.lensDirection == _cameraController!.description.lensDirection);

    final nextIndex = (currentIndex + 1) % _cameras!.length;

    await _cameraController!.dispose();

    _cameraController = CameraController(
      _cameras![nextIndex],
      ResolutionPreset.high,
    );

    await _cameraController!.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _phoneCtrl.dispose();
    _nikCtrl.dispose();
    _addrCtrl.dispose();
    _jobCtrl.dispose();
    _officeAddrCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tampilkan kamera jika sedang aktif
    if (_isShowingCamera) {
      return Scaffold(
        body: _buildCameraView(),
      );
    }

    // Tampilkan form KYC normal
    return Scaffold(
      appBar: AppBar(title: const Text("Lengkapi Data Diri (KYC)")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
                "Sebelum mengajukan pinjaman, mohon lengkapi data berikut:",
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _buildPhotoBox("Selfie + KTP", _selfie, 'selfie'),
              _buildPhotoBox("Foto KTP", _ktp, 'ktp'),
            ]),
            const SizedBox(height: 20),
            TextField(
                controller: _nikCtrl,
                decoration: const InputDecoration(
                    labelText: "NIK (KTP)", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                    labelText: "No HP", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(
                controller: _addrCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: "Alamat Domisili",
                    border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(
                controller: _jobCtrl,
                decoration: const InputDecoration(
                    labelText: "Pekerjaan", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(
                controller: _officeAddrCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: "Alamat Kantor", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitKYC,
                child: _isSubmitting
                    ? const CircularProgressIndicator()
                    : const Text("SIMPAN & LANJUT"),
              ),
            )
          ],
        ),
      ),
    );
  }
}
