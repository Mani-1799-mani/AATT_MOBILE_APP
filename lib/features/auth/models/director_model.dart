import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a director or producer user in the system.
class DirectorModel {
  const DirectorModel({
    required this.uid,
    required this.phoneNumber,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.role,
    required this.status,
    this.productionHouse,
    this.email,
    this.profileImageUrl,
    this.bio,
    this.experience,
    this.specializations,
    this.awards,
    this.projects,
    this.contactInfo,
    this.socialMedia,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String phoneNumber;
  final String firstName;
  final String lastName;
  final String fullName;
  final String role; // 'director' or 'producer'
  final String status; // 'active', 'inactive', 'pending'
  final String? productionHouse;
  final String? email;
  final String? profileImageUrl;
  final String? bio;
  final int? experience; // years of experience
  final List<String>? specializations; // genres/types they specialize in
  final List<String>? awards;
  final List<String>? projects; // list of notable projects
  final Map<String, String>? contactInfo; // additional contact details
  final Map<String, String>? socialMedia; // social media handles
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Create DirectorModel from Firestore document data
  factory DirectorModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return DirectorModel(
      uid: data['uid'] ?? snapshot.id,
      phoneNumber: data['phoneNumber'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      fullName: data['fullName'] ?? '',
      role: data['role'] ?? 'director',
      status: data['status'] ?? 'active',
      productionHouse: data['productionHouse'],
      email: data['email'],
      profileImageUrl: data['profileImageUrl'],
      bio: data['bio'],
      experience: data['experience'],
      specializations: data['specializations']?.cast<String>(),
      awards: data['awards']?.cast<String>(),
      projects: data['projects']?.cast<String>(),
      contactInfo: data['contactInfo']?.cast<String, String>(),
      socialMedia: data['socialMedia']?.cast<String, String>(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert DirectorModel to Firestore document data
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'firstName': firstName,
      'lastName': lastName,
      'fullName': fullName,
      'role': role,
      'status': status,
      'productionHouse': productionHouse,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'experience': experience,
      'specializations': specializations,
      'awards': awards,
      'projects': projects,
      'contactInfo': contactInfo,
      'socialMedia': socialMedia,
      'updatedAt': FieldValue.serverTimestamp(),
      if (createdAt == null) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Create a copy of this DirectorModel with updated fields
  DirectorModel copyWith({
    String? uid,
    String? phoneNumber,
    String? firstName,
    String? lastName,
    String? fullName,
    String? role,
    String? status,
    String? productionHouse,
    String? email,
    String? profileImageUrl,
    String? bio,
    int? experience,
    List<String>? specializations,
    List<String>? awards,
    List<String>? projects,
    Map<String, String>? contactInfo,
    Map<String, String>? socialMedia,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DirectorModel(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      status: status ?? this.status,
      productionHouse: productionHouse ?? this.productionHouse,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      experience: experience ?? this.experience,
      specializations: specializations ?? this.specializations,
      awards: awards ?? this.awards,
      projects: projects ?? this.projects,
      contactInfo: contactInfo ?? this.contactInfo,
      socialMedia: socialMedia ?? this.socialMedia,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'DirectorModel(uid: $uid, name: $fullName, role: $role, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DirectorModel && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
}