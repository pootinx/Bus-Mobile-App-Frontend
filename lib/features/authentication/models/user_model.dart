
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String fullName;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
  });

  // Factory constructor to create a UserModel from a Firestore document.
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
    );
  }

  // Method to convert a UserModel instance to a map for Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'fullName': fullName,
    };
  }
}
