// survey_model.dart

import 'package:flutter/material.dart';


class SurveyModel {
  final String id;
  final String loanId;
  final String surveyorId;
  final List<String> photos;
  final int score;
  final Map<String, dynamic> location;
  final String notes;
  final DateTime createdAt;

  SurveyModel({
    required this.id,
    required this.loanId,
    required this.surveyorId,
    required this.photos,
    required this.score,
    required this.location,
    required this.notes,
    required this.createdAt,
  });

  factory SurveyModel.fromMap(Map<String, dynamic> map) {
    return SurveyModel(
      id: map['id']?.toString() ?? '',
      loanId: map['loanId']?.toString() ?? '',
      surveyorId: map['surveyorId']?.toString() ?? '',
      photos: List<String>.from(map['photos'] ?? []),
      score: map['score'] is int ? map['score'] : int.parse(map['score']?.toString() ?? '0'),
      location: Map<String, dynamic>.from(map['location'] ?? {}),
      notes: map['notes'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'loanId': loanId,
      'surveyorId': surveyorId,
      'photos': photos,
      'score': score,
      'location': location,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  String get scoreText {
    if (score >= 90) return 'Sangat Baik';
    if (score >= 80) return 'Baik';
    if (score >= 70) return 'Cukup';
    if (score >= 60) return 'Kurang';
    return 'Buruk';
  }

  Color get scoreColor {
    if (score >= 80) return Colors.green;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }

  double? get latitude => location['lat'] is double ? location['lat'] : double.tryParse(location['lat']?.toString() ?? '');
  double? get longitude => location['long'] is double ? location['long'] : double.tryParse(location['long']?.toString() ?? '');
}