import 'dart:io';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'restapi.dart'; 
import 'config.dart'; 
import 'user_model.dart';
import 'utils.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  
  Future<void> _changePhoto(AuthService auth) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      String filename = "prof_${DateTime.now().millisecondsSinceEpoch}.png";
      
      String uploadedName = await DataService().upload(bytes, filename);
      
      if (uploadedName.isNotEmpty) {
        await auth.updatePhoto(uploadedName);
        if(!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Foto Profil Diperbarui!")));
        setState((){}); // Paksa refresh UI
      }
    }
  }

  // ... (Method _editProfile sama seperti sebelumnya, tidak perlu diubah) ...
  void _editProfile(BuildContext context, AuthService auth) {
    // ... code edit profile ...
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(builder: (context, auth, _) {
      final user = auth.currentUser;
      if (user == null) return const SizedBox();
      
      // LOGIC GAMBAR YANG LEBIH AMAN (FIX ERROR PUTIH)
      ImageProvider? avatarImage;
      if (user.selfieImage != null && user.selfieImage!.isNotEmpty) {
         if (!user.selfieImage!.contains('/') && !user.selfieImage!.contains('\\')) {
            // Gambar dari server
            avatarImage = NetworkImage(getFileUrl(user.selfieImage!));
         } else if (kIsWeb) {
            avatarImage = NetworkImage(user.selfieImage!); 
         } else {
            avatarImage = FileImage(File(user.selfieImage!)); 
         }
      }

      return Scaffold(
        backgroundColor: const Color(0xFFF3E8FF),
        body: SingleChildScrollView(
          child: Column(children: [
            // ... (Header sama) ...
            Container(padding: const EdgeInsets.fromLTRB(24, 60, 24, 80), decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]), borderRadius: BorderRadius.vertical(bottom: Radius.circular(40))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("CoopConnect", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), GestureDetector(onTap: () => Utils.confirmLogout(context, auth), child: const Icon(Icons.logout, color: Colors.white))])),

            Transform.translate(
              offset: const Offset(0, -60),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: CircleAvatar(
                          radius: 60, 
                          backgroundColor: Colors.grey[200], 
                          // JIKA GAMBAR ERROR/NULL, TAMPILKAN ICON ORANG
                          backgroundImage: avatarImage,
                          child: avatarImage == null ? const Icon(Icons.person, size: 60, color: Colors.grey) : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: GestureDetector(
                          onTap: () => _changePhoto(auth),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Color(0xFF7C3AED), shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2))),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(user.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                  Text(user.email, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            
            // ... (Info Card sama) ...
             Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(children: [_infoCard("Username", user.name), _infoCard("Email", user.email), _infoCard("Alamat Lengkap", user.address.isEmpty ? "-" : user.address), _infoCard("No. HP", user.phone.isEmpty ? "-" : user.phone)])),
          ]),
        ),
      );
    });
  }
  
  Widget _infoCard(String label, String value) {
    return Container(margin: const EdgeInsets.only(bottom: 15), width: double.infinity, padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)), const SizedBox(height: 5), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]));
  }
}