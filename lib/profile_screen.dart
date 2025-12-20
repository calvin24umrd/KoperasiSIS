import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'restapi.dart';
import 'config.dart';
import 'user_model.dart';
import 'utils.dart';
import 'data_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  final AppRepository _repo = AppRepository();

  Uint8List? _tempImageBytes;

  @override
  void dispose() {
    _tempImageBytes = null;
    super.dispose();
  }

  Future<void> _changePhoto(AuthService auth) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _tempImageBytes = bytes; // SIMPAN UNTUK FEEDBACK INSTAN
      });

      String filename = "prof_${DateTime.now().millisecondsSinceEpoch}.jpg";
      String uploadedName = await DataService().upload(bytes, filename);

      if (uploadedName.isNotEmpty) {
        // Set immediately for persistence across navigation
        auth.currentUser!.selfieImage = uploadedName;
        auth.notifyListeners();

        // Save to local storage immediately
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_photo', uploadedName);

        await auth.updatePhoto(uploadedName);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Foto Profil Diperbarui!")));

        // JANGAN CLEAR TEMP - BIARKAN TETAP MUNCUL
        // Saat logout, AuthService akan clear session dan _tempImageBytes juga akan di-reset
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Gagal upload foto."), backgroundColor: Colors.red));
        setState(() {
          _tempImageBytes = null;
        });
      }
    }
  }

  void _editProfile(BuildContext context, AuthService auth) {
    final user = auth.currentUser!;
    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone);
    final addrCtrl = TextEditingController(text: user.address);
    final officeCtrl = TextEditingController(text: user.addressOffice);

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                  left: 20,
                  right: 20,
                  top: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Edit Profile",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7C3AED))),
                  const SizedBox(height: 20),
                  TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                          labelText: "Nama Lengkap",
                          border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                          labelText: "No. HP", border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(
                      controller: addrCtrl,
                      decoration: const InputDecoration(
                          labelText: "Alamat Lengkap",
                          border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(
                      controller: officeCtrl,
                      decoration: const InputDecoration(
                          labelText: "Alamat Kantor",
                          border: OutlineInputBorder())),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        UserModel updated = UserModel(
                            id: user.id,
                            email: user.email,
                            password: user.password,
                            role: user.role,
                            name: nameCtrl.text,
                            joinDate: user.joinDate,
                            ktpImage: user.ktpImage,
                            selfieImage: user.selfieImage,
                            nik: user.nik,
                            job: user.job,
                            isVerified: user.isVerified,
                            phone: phoneCtrl.text,
                            address: addrCtrl.text,
                            addressOffice: officeCtrl.text);
                        await auth.updateProfile(updated);
                        if (mounted) Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Profil Diperbarui!")));
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED)),
                      child: const Text("Simpan Perubahan",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ));
  }

  Widget _buildAvatarImage(UserModel user) {
    // PRIORITAS 1: Jika ada temp image (baru upload), tampilkan
    if (_tempImageBytes != null) {
      return Image.memory(
        _tempImageBytes!,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
              child: Icon(Icons.person, size: 60, color: Colors.grey));
        },
      );
    }

    // PRIORITAS 2: Ambil dari database (user.selfieImage)
    if (user.selfieImage != null && user.selfieImage!.isNotEmpty) {
      String imageUrl = user.selfieImage!.contains('http')
          ? user.selfieImage!
          : getFileUrl(user.selfieImage!);

      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        cacheWidth: 150,
        cacheHeight: 150,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
              child: Icon(Icons.person, size: 60, color: Colors.grey));
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
      );
    }

    // DEFAULT
    return const Center(
        child: Icon(Icons.person, size: 60, color: Colors.grey));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(builder: (context, auth, _) {
      final user = auth.currentUser;
      if (user == null) return const SizedBox();

      return Scaffold(
        backgroundColor: const Color(0xFFF3E8FF),
        body: SingleChildScrollView(
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 80),
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]),
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(40))),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("CoopConnect",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: () {
                        setState(() => _tempImageBytes = null);
                        Utils.confirmLogout(context, auth);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(20)),
                        child: const Text("Logout",
                            style: TextStyle(color: Colors.white)),
                      ),
                    )
                  ]),
            ),
            Transform.translate(
              offset: const Offset(0, -60),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 128,
                        height: 128,
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: ClipOval(
                          child: Container(
                            color: Colors.grey[200],
                            child: _buildAvatarImage(user),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _changePhoto(auth),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                                color: Color(0xFF7C3AED),
                                shape: BoxShape.circle,
                                border: Border.fromBorderSide(
                                    BorderSide(color: Colors.white, width: 2))),
                            child: const Icon(Icons.camera_alt,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(user.name,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  Text(user.email, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _infoCard("Username", user.name),
                  _infoCard("Email", user.email),
                  _infoCard("Alamat Lengkap",
                      user.address.isEmpty ? "-" : user.address),
                  _infoCard("No. HP", user.phone.isEmpty ? "-" : user.phone),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _editProfile(context, auth),
                      icon: const Icon(Icons.edit, color: Colors.white),
                      label: const Text("Edit Profile",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15))),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 30),
          ]),
        ),
      );
    });
  }

  Widget _infoCard(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 5),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
