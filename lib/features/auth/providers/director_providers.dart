import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aatt/features/auth/data/director_repository.dart';
import 'package:aatt/features/auth/models/director_model.dart';

/// Provider for DirectorRepository
final directorRepositoryProvider = Provider<DirectorRepository>((ref) {
  return DirectorRepository();
});

/// Provider for creating a director/producer
final createDirectorProvider = FutureProvider.family<void, DirectorModel>(
  (ref, director) async {
    final repository = ref.read(directorRepositoryProvider);
    await repository.createDirector(director);
  },
);

/// Provider for getting a director by UID
final getDirectorByUidProvider = FutureProvider.family<DirectorModel?, String>(
  (ref, uid) async {
    final repository = ref.read(directorRepositoryProvider);
    return await repository.getDirectorByUid(uid);
  },
);

/// Provider for getting a director by phone number
final getDirectorByPhoneProvider = FutureProvider.family<DirectorModel?, String>(
  (ref, phoneNumber) async {
    final repository = ref.read(directorRepositoryProvider);
    return await repository.getDirectorByPhone(phoneNumber);
  },
);

/// Provider for checking if phone exists in directors collection
final checkDirectorPhoneExistsProvider = FutureProvider.family<bool, String>(
  (ref, phoneNumber) async {
    final repository = ref.read(directorRepositoryProvider);
    return await repository.checkPhoneExists(phoneNumber);
  },
);

/// Provider for getting all directors with optional filters
final getDirectorsProvider = FutureProvider.family<List<DirectorModel>, DirectorFilters>(
  (ref, filters) async {
    final repository = ref.read(directorRepositoryProvider);
    return await repository.getDirectors(
      role: filters.role,
      status: filters.status,
      productionHouse: filters.productionHouse,
      limit: filters.limit,
    );
  },
);

/// Provider for searching directors
final searchDirectorsProvider = FutureProvider.family<List<DirectorModel>, String>(
  (ref, searchTerm) async {
    final repository = ref.read(directorRepositoryProvider);
    return await repository.searchDirectors(searchTerm);
  },
);

/// Provider for directors stream (real-time updates)
final directorsStreamProvider = StreamProvider.family<List<DirectorModel>, DirectorFilters>(
  (ref, filters) {
    final repository = ref.read(directorRepositoryProvider);
    return repository.getDirectorsStream(
      role: filters.role,
      status: filters.status,
      limit: filters.limit,
    );
  },
);

/// Provider for directors by production house
final directorsByProductionHouseProvider = FutureProvider.family<List<DirectorModel>, String>(
  (ref, productionHouse) async {
    final repository = ref.read(directorRepositoryProvider);
    return await repository.getDirectorsByProductionHouse(productionHouse);
  },
);

/// Provider for directors by specialization
final directorsBySpecializationProvider = FutureProvider.family<List<DirectorModel>, String>(
  (ref, specialization) async {
    final repository = ref.read(directorRepositoryProvider);
    return await repository.getDirectorsBySpecialization(specialization);
  },
);

/// Helper class for filtering directors
class DirectorFilters {
  const DirectorFilters({
    this.role,
    this.status,
    this.productionHouse,
    this.limit,
  });

  final String? role;
  final String? status;
  final String? productionHouse;
  final int? limit;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DirectorFilters &&
        other.role == role &&
        other.status == status &&
        other.productionHouse == productionHouse &&
        other.limit == limit;
  }

  @override
  int get hashCode {
    return role.hashCode ^
        status.hashCode ^
        productionHouse.hashCode ^
        limit.hashCode;
  }
}

/// Predefined filter sets for common use cases
class DirectorFilterPresets {
  static const DirectorFilters allDirectors = DirectorFilters(role: 'director');
  static const DirectorFilters allProducers = DirectorFilters(role: 'producer');
  static const DirectorFilters activeDirectors = DirectorFilters(
    role: 'director',
    status: 'active',
  );
  static const DirectorFilters activeProducers = DirectorFilters(
    role: 'producer',
    status: 'active',
  );
  static const DirectorFilters allActive = DirectorFilters(status: 'active');
  static const DirectorFilters recent = DirectorFilters(limit: 20);
}