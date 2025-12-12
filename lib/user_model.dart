import 'dart:convert';

class UserModel {
  final String id;
  final String email;
  final String password;
  final String role;
  
  // Data Profil (KYC)
  String name;
  String phone;
  String address;     // Alamat Domisili
  String addressOffice; // Alamat Kantor
  String nik;
  String job;
  String? selfieImage;
  String? ktpImage;
  bool isVerified;    // Penanda sudah KYC atau belum
  DateTime joinDate;

  UserModel({
    required this.id, required this.email, required this.password, required this.role,
    required this.name, required this.phone, required this.address, required this.addressOffice,
    required this.nik, required this.job, this.selfieImage, this.ktpImage,
    required this.isVerified, required this.joinDate,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    // Default values
    String uName = 'Member';
    String uPhone = '';
    String uAddr = '';
    String uOffice = '';
    String uNik = '';
    String uJob = '';
    String? uSelfie;
    String? uKtp;
    bool uVerif = false;
    DateTime uDate = DateTime.now();

    // Bongkar JSON profile_data
    if (map['profile_data'] != null && map['profile_data'].toString().isNotEmpty) {
      try {
        var profile = map['profile_data'];
        if (profile is String) profile = json.decode(profile);

        uName = profile['name'] ?? 'Member';
        uPhone = profile['phone'] ?? '';
        uAddr = profile['address'] ?? ''; // Ini yg bikin alamat kosong sebelumnya
        uOffice = profile['addressOffice'] ?? '';
        uNik = profile['nik'] ?? '';
        uJob = profile['job'] ?? '';
        uSelfie = profile['selfieImage'];
        uKtp = profile['ktpImage'];
        uVerif = profile['isVerified'] == true;
        uDate = DateTime.tryParse(profile['joinDate'] ?? '') ?? DateTime.now();
      } catch (e) {
        print("Error parsing profile: $e");
      }
    }

    return UserModel(
      id: map['_id'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      role: map['role'] ?? 'member',
      name: uName, phone: uPhone, address: uAddr, addressOffice: uOffice,
      nik: uNik, job: uJob, selfieImage: uSelfie, ktpImage: uKtp,
      isVerified: uVerif, joinDate: uDate,
    );
  }

  // Bungkus data jadi JSON String untuk disimpan ke GoCloud
  String toProfileDataString() {
    return json.encode({
      'name': name,
      'phone': phone,
      'address': address,
      'addressOffice': addressOffice,
      'nik': nik,
      'job': job,
      'selfieImage': selfieImage,
      'ktpImage': ktpImage,
      'isVerified': isVerified,
      'joinDate': joinDate.toIso8601String(),
    });
  }
}