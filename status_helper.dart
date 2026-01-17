import 'package:flutter/material.dart';

class StatusHelper {
  // Status constants
  static const String PENDING = 'pending';
  static const String APPROVED = 'approved';
  static const String REJECTED = 'rejected';
  static const String SURVEYED = 'surveyed'; // On Process
  static const String SURVEY_COMPLETED = 'survey_completed'; // Survey Done, Waiting Admin
  static const String DISBURSED = 'disbursed';


  // Status labels in Indonesian
  static String getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case PENDING:
        return 'Dalam Proses';
      case APPROVED:
        return 'Disetujui (Ambil di Kantor)';
      case REJECTED:
        return 'Ditolak';
      case SURVEYED:
        return 'Dalam Proses Survey';
      case SURVEY_COMPLETED:
        return 'Menungu Keputusan';
      case DISBURSED: 
      return 'Sudah Dicairkan';
      default:
        return 'Unknown';
    }
  }

  // Status colors
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case PENDING:
        return Colors.yellow; // Kuning
      case APPROVED:
        return Colors.blue; // Hijau
      case REJECTED:
        return Colors.red; // Merah
      case SURVEYED:
      case SURVEY_COMPLETED:
        return Colors.blue; // Biru untuk On Process
      case DISBURSED: 
      return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Status icons
  static IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case PENDING:
        return Icons.pending;
      case APPROVED:
        return Icons.check_circle;
      case REJECTED:
        return Icons.cancel;
      case SURVEYED:
        return Icons.assignment_turned_in;
      default:
        return Icons.info;
    }
  }

  // Check if status is processed (not pending)
  static bool isProcessed(String status) {
    return status.toLowerCase() != PENDING;
  }

  // Get all status options for admin dropdown
  static List<String> getAllStatuses() {
    return [PENDING, SURVEYED, APPROVED, REJECTED];
  }

  // Get admin action statuses (excluding pending)
  static List<String> getAdminActionStatuses() {
    return [SURVEYED, APPROVED, REJECTED];
  }
}
