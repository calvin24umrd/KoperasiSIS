import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'auth_service.dart';

class Utils {
  static String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    return formatter.format(amount);
  }

  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  static void confirmLogout(BuildContext context, AuthService auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Konfirmasi"),
        content: const Text("Yakin ingin keluar?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.logout();
              Navigator.pushNamedAndRemoveUntil(context, '/splash', (route) => false);
            },
            child: const Text("Ya, Keluar"),
          )
        ],
      ),
    );
  }

  // --- FUNGSI INI YANG SEBELUMNYA HILANG DAN BIKIN ERROR ---
  static void showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        height: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("Notifikasi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Divider(),
            ListTile(
              leading: Icon(Icons.info, color: Colors.blue),
              title: Text("Selamat Datang"),
              subtitle: Text("Sistem siap digunakan."),
            )
          ],
        ),
      ),
    );
  }
}

extension OnTapExt on Widget {
  Widget onTap(VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: this);
  }
}