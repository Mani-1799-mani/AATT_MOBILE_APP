import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aatt/features/auth/data/director_repository.dart';
import 'package:aatt/features/auth/models/director_model.dart';
import 'package:aatt/features/auth/providers/director_providers.dart';

/// Service class for managing directors/producers business logic
class DirectorService {
  DirectorService(this._repository);

  final DirectorRepository _repository;

  /// Check if a phone number exists in the directors collection
  Future<bool> checkPhoneExists(String phoneNumber) async {
    return await _repository.checkPhoneExists(phoneNumber);
  }

  /// Create a new director/producer with validation
  Future<DirectorModel> createDirector({
    required String uid,
    required String phoneNumber,
    required String firstName,
    required String lastName,
    required String role, // 'director' or 'producer'
    String? productionHouse,
    String? email,
    String? bio,
    int? experience,
    List<String>? specializations,
    Map<String, String>? contactInfo,
    Map<String, String>? socialMedia,
  }) async {
    // Validate role
    if (!['director', 'producer'].contains(role)) {
      throw ArgumentError('Role must be either "director" or "producer"');
    }

    // Validate required fields
    if (uid.isEmpty) throw ArgumentError('UID cannot be empty');
    if (phoneNumber.isEmpty) throw ArgumentError('Phone number cannot be empty');
    if (firstName.isEmpty) throw ArgumentError('First name cannot be empty');
    if (lastName.isEmpty) throw ArgumentError('Last name cannot be empty');

    // Check if phone number already exists
    final phoneExists = await _repository.checkPhoneExists(phoneNumber);
    if (phoneExists) {
      throw Exception('A director/producer with this phone number already exists');
    }

    // Create the director model
    final director = DirectorModel(
      uid: uid,
      phoneNumber: phoneNumber,
      firstName: firstName,
      lastName: lastName,
      fullName: '$firstName $lastName'.trim(),
      role: role,
      status: 'active',
      productionHouse: productionHouse,
      email: email,
      bio: bio,
      experience: experience,
      specializations: specializations,
      contactInfo: contactInfo,
      socialMedia: socialMedia,
    );

    // Save to Firestore
    await _repository.createDirector(director);
    return director;
  }

  /// Update director profile
  Future<void> updateDirectorProfile({
    required String uid,
    String? firstName,
    String? lastName,
    String? productionHouse,
    String? email,
    String? bio,
    String? profileImageUrl,
    int? experience,
    List<String>? specializations,
    List<String>? awards,
    Map<String, String>? contactInfo,
    Map<String, String>? socialMedia,
  }) async {
    final Map<String, dynamic> updates = {};

    if (firstName != null) updates['firstName'] = firstName;
    if (lastName != null) updates['lastName'] = lastName;
    if (firstName != null || lastName != null) {
      // Update full name if either first or last name changed
      final currentDirector = await _repository.getDirectorByUid(uid);
      if (currentDirector != null) {
        final newFirstName = firstName ?? currentDirector.firstName;
        final newLastName = lastName ?? currentDirector.lastName;
        updates['fullName'] = '$newFirstName $newLastName'.trim();
      }
    }
    if (productionHouse != null) updates['productionHouse'] = productionHouse;
    if (email != null) updates['email'] = email;
    if (bio != null) updates['bio'] = bio;
    if (profileImageUrl != null) updates['profileImageUrl'] = profileImageUrl;
    if (experience != null) updates['experience'] = experience;
    if (specializations != null) updates['specializations'] = specializations;
    if (awards != null) updates['awards'] = awards;
    if (contactInfo != null) updates['contactInfo'] = contactInfo;
    if (socialMedia != null) updates['socialMedia'] = socialMedia;

    if (updates.isNotEmpty) {
      await _repository.updateDirector(uid, updates);
    }
  }

  /// Get director profile with error handling
  Future<DirectorModel?> getDirectorProfile(String uid) async {
    return await _repository.getDirectorByUid(uid);
  }

  /// Search directors with enhanced filtering
  Future<List<DirectorModel>> searchDirectors({
    String? searchTerm,
    String? role,
    String? status,
    String? productionHouse,
    String? specialization,
    int? minExperience,
    int? maxExperience,
  }) async {
    List<DirectorModel> results = [];

    if (searchTerm != null && searchTerm.isNotEmpty) {
      // Use search functionality
      results = await _repository.searchDirectors(searchTerm);
    } else {
      // Get all directors first, then filter
      results = await _repository.getDirectors(
        role: role,
        status: status,
        productionHouse: productionHouse,
      );
    }

    // Apply additional filters
    if (specialization != null) {
      results = results.where((director) {
        return director.specializations?.contains(specialization) ?? false;
      }).toList();
    }

    if (minExperience != null) {
      results = results.where((director) {
        return (director.experience ?? 0) >= minExperience;
      }).toList();
    }

    if (maxExperience != null) {
      results = results.where((director) {
        return (director.experience ?? 0) <= maxExperience;
      }).toList();
    }

    return results;
  }

  /// Get directors statistics
  Future<Map<String, int>> getDirectorStatistics() async {
    final allDirectors = await _repository.getDirectors();
    
    final stats = <String, int>{
      'total': allDirectors.length,
      'directors': 0,
      'producers': 0,
      'active': 0,
      'inactive': 0,
      'pending': 0,
    };

    for (final director in allDirectors) {
      if (director.role == 'director') stats['directors'] = (stats['directors'] ?? 0) + 1;
      if (director.role == 'producer') stats['producers'] = (stats['producers'] ?? 0) + 1;
      
      switch (director.status) {
        case 'active':
          stats['active'] = (stats['active'] ?? 0) + 1;
          break;
        case 'inactive':
          stats['inactive'] = (stats['inactive'] ?? 0) + 1;
          break;
        case 'pending':
          stats['pending'] = (stats['pending'] ?? 0) + 1;
          break;
      }
    }

    return stats;
  }

  /// Validate director data before operations
  bool validateDirectorData(Map<String, dynamic> data) {
    final requiredFields = ['uid', 'phoneNumber', 'firstName', 'lastName', 'role'];
    
    for (final field in requiredFields) {
      if (!data.containsKey(field) || data[field] == null || data[field].toString().isEmpty) {
        return false;
      }
    }

    // Validate role
    if (!['director', 'producer'].contains(data['role'])) {
      return false;
    }

    // Validate phone number format (basic validation)
    final phoneRegex = RegExp(r'^\+?[\d\s-()]+$');
    if (!phoneRegex.hasMatch(data['phoneNumber'])) {
      return false;
    }

    return true;
  }

  /// Batch operations for multiple directors
  Future<void> batchUpdateDirectors(Map<String, Map<String, dynamic>> updates) async {
    for (final entry in updates.entries) {
      await _repository.updateDirector(entry.key, entry.value);
    }
  }

  /// Archive director (soft delete by changing status)
  Future<void> archiveDirector(String uid) async {
    await _repository.updateDirectorStatus(uid, 'archived');
  }

  /// Restore archived director
  Future<void> restoreDirector(String uid) async {
    await _repository.updateDirectorStatus(uid, 'active');
  }
}

/// Provider for DirectorService
final directorServiceProvider = Provider<DirectorService>((ref) {
  final repository = ref.read(directorRepositoryProvider);
  return DirectorService(repository);
});