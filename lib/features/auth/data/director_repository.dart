import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aatt/features/auth/models/director_model.dart';

/// Repository to handle directors/producers collection in Firestore.
/// This provides methods for CRUD operations on the 'directors' collection.
class DirectorRepository {
  DirectorRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Reference to the directors collection
  CollectionReference<Map<String, dynamic>> get _directorsRef =>
      _firestore.collection('directors');

  /// Create a new director/producer profile
  Future<void> createDirector(DirectorModel director) async {
    try {
      await _directorsRef.doc(director.uid).set(director.toFirestore());
    } on FirebaseException catch (e) {
      throw Exception('Failed to create director profile: ${e.message}');
    }
  }

  /// Retrieve a director/producer by UID
  Future<DirectorModel?> getDirectorByUid(String uid) async {
    try {
      final doc = await _directorsRef.doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return DirectorModel.fromFirestore(doc);
      }
      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      throw Exception('Failed to get director by UID: ${e.message}');
    }
  }

  /// Retrieve a director/producer by phone number
  Future<DirectorModel?> getDirectorByPhone(String phoneNumber) async {
    try {
      final querySnapshot = await _directorsRef
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return DirectorModel.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } on FirebaseException catch (e) {
      throw Exception('Failed to get director by phone: ${e.message}');
    }
  }

  /// Update an existing director/producer profile
  Future<void> updateDirector(String uid, Map<String, dynamic> updates) async {
    try {
      await _directorsRef.doc(uid).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception('Failed to update director profile: ${e.message}');
    }
  }

  /// Delete a director/producer profile
  Future<void> deleteDirector(String uid) async {
    try {
      await _directorsRef.doc(uid).delete();
    } on FirebaseException catch (e) {
      throw Exception('Failed to delete director profile: ${e.message}');
    }
  }

  /// Check if a phone number already exists in the directors collection
  Future<bool> checkPhoneExists(String phoneNumber) async {
    try {
      final querySnapshot = await _directorsRef
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return false;
      }
      throw Exception('Failed to check phone existence: ${e.message}');
    }
  }

  /// Retrieve all directors (with optional filtering)
  Future<List<DirectorModel>> getDirectors({
    String? role, // filter by 'director' or 'producer'
    String? status, // filter by status
    String? productionHouse, // filter by production house
    int? limit,
    DocumentSnapshot? startAfter, // for pagination
  }) async {
    try {
      Query<Map<String, dynamic>> query = _directorsRef;

      // Apply filters
      if (role != null) {
        query = query.where('role', isEqualTo: role);
      }
      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }
      if (productionHouse != null) {
        query = query.where('productionHouse', isEqualTo: productionHouse);
      }

      // Apply pagination
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      if (limit != null) {
        query = query.limit(limit);
      }

      // Order by creation date (newest first)
      query = query.orderBy('createdAt', descending: true);

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => DirectorModel.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      throw Exception('Failed to get directors: ${e.message}');
    }
  }

  /// Search directors by name or production house
  Future<List<DirectorModel>> searchDirectors(String searchTerm) async {
    try {
      if (searchTerm.isEmpty) return [];

      final searchTermLower = searchTerm.toLowerCase();

      // Search by full name (case insensitive)
      final nameQuery = await _directorsRef
          .where('fullName', isGreaterThanOrEqualTo: searchTermLower)
          .where('fullName', isLessThanOrEqualTo: '$searchTermLower\uf8ff')
          .get();

      // Search by production house (case insensitive)
      final productionQuery = await _directorsRef
          .where('productionHouse', isGreaterThanOrEqualTo: searchTermLower)
          .where('productionHouse', isLessThanOrEqualTo: '$searchTermLower\uf8ff')
          .get();

      // Combine results and remove duplicates
      final Set<String> seenUids = {};
      final List<DirectorModel> results = [];

      for (final doc in [...nameQuery.docs, ...productionQuery.docs]) {
        final director = DirectorModel.fromFirestore(doc);
        if (!seenUids.contains(director.uid)) {
          seenUids.add(director.uid);
          results.add(director);
        }
      }

      return results;
    } on FirebaseException catch (e) {
      throw Exception('Failed to search directors: ${e.message}');
    }
  }

  /// Get directors by production house
  Future<List<DirectorModel>> getDirectorsByProductionHouse(
      String productionHouse) async {
    try {
      final querySnapshot = await _directorsRef
          .where('productionHouse', isEqualTo: productionHouse)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => DirectorModel.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      throw Exception('Failed to get directors by production house: ${e.message}');
    }
  }

  /// Get directors with specific specializations
  Future<List<DirectorModel>> getDirectorsBySpecialization(
      String specialization) async {
    try {
      final querySnapshot = await _directorsRef
          .where('specializations', arrayContains: specialization)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => DirectorModel.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      throw Exception('Failed to get directors by specialization: ${e.message}');
    }
  }

  /// Update director status (active, inactive, pending)
  Future<void> updateDirectorStatus(String uid, String status) async {
    try {
      await _directorsRef.doc(uid).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception('Failed to update director status: ${e.message}');
    }
  }

  /// Add project to director's project list
  Future<void> addProjectToDirector(String uid, String project) async {
    try {
      await _directorsRef.doc(uid).update({
        'projects': FieldValue.arrayUnion([project]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception('Failed to add project to director: ${e.message}');
    }
  }

  /// Remove project from director's project list
  Future<void> removeProjectFromDirector(String uid, String project) async {
    try {
      await _directorsRef.doc(uid).update({
        'projects': FieldValue.arrayRemove([project]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception('Failed to remove project from director: ${e.message}');
    }
  }

  /// Stream of directors (for real-time updates)
  Stream<List<DirectorModel>> getDirectorsStream({
    String? role,
    String? status,
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = _directorsRef;

    if (role != null) {
      query = query.where('role', isEqualTo: role);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    if (limit != null) {
      query = query.limit(limit);
    }

    query = query.orderBy('createdAt', descending: true);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => DirectorModel.fromFirestore(doc))
          .toList();
    });
  }
}