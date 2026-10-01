import 'package:cloud_firestore/cloud_firestore.dart';

class LRNModel {
  final String lrn;
  final String firstName;
  final String lastName;
  final String middleName;
  final String extension;
  final String gradeLevel;
  final String section;
  final bool isRegistered;
  final DateTime? registeredAt;

  LRNModel({
    required this.lrn,
    required this.firstName,
    required this.lastName,
    this.middleName = '',
    this.extension = '',
    this.gradeLevel = '12',
    this.section = '',
    this.isRegistered = false,
    this.registeredAt,
  });

  factory LRNModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LRNModel(
      lrn: doc.id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      middleName: data['middleName'] ?? data['middleInitial'] ?? '',
      extension: data['extension'] ?? data['suffix'] ?? '',
      gradeLevel: data['gradeLevel'] ?? '12',
      section: data['section'] ?? '',
      isRegistered: data['isRegistered'] ?? false,
      registeredAt: (data['registeredAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'middleName': middleName,
      'extension': extension,
      'gradeLevel': gradeLevel,
      'section': section,
      'isRegistered': isRegistered,
      'registeredAt': registeredAt,
    };
  }
}
