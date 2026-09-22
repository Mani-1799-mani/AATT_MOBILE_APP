import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aatt/features/auth/providers/director_providers.dart';
import 'package:aatt/features/auth/services/director_service.dart';

/// Example usage of the Directors/Producers collection system
/// This demonstrates how to use the new DirectorModel, DirectorService, and providers
class DirectorCollectionExample {
  
  /// Example: Create a new director
  static Future<void> createDirectorExample(WidgetRef ref) async {
    try {
      final directorService = ref.read(directorServiceProvider);
      
      final director = await directorService.createDirector(
        uid: 'unique_firebase_uid_123',
        phoneNumber: '+1234567890',
        firstName: 'John',
        lastName: 'Doe',
        role: 'director',
        productionHouse: 'ABC Productions',
        email: 'john.doe@abcproductions.com',
        bio: 'Experienced director with 10+ years in the film industry',
        experience: 10,
        specializations: ['Drama', 'Action', 'Thriller'],
        contactInfo: {
          'website': 'https://johndoe.com',
          'agent': 'Jane Smith Agency',
        },
        socialMedia: {
          'instagram': '@johndoe_director',
          'twitter': '@johndoe',
        },
      );
      
      debugPrint('Director created: ${director.fullName}');
    } catch (e) {
      debugPrint('Error creating director: $e');
    }
  }

  /// Example: Create a new producer
  static Future<void> createProducerExample(WidgetRef ref) async {
    try {
      final directorService = ref.read(directorServiceProvider);
      
      final producer = await directorService.createDirector(
        uid: 'unique_firebase_uid_456',
        phoneNumber: '+0987654321',
        firstName: 'Sarah',
        lastName: 'Johnson',
        role: 'producer',
        productionHouse: 'XYZ Studios',
        email: 'sarah@xyzstudios.com',
        bio: 'Award-winning producer specializing in independent films',
        experience: 8,
        specializations: ['Independent Films', 'Documentaries'],
      );
      
      debugPrint('Producer created: ${producer.fullName}');
    } catch (e) {
      debugPrint('Error creating producer: $e');
    }
  }

  /// Example: Retrieve directors using providers
  static Future<void> getDirectorsExample(WidgetRef ref) async {
    try {
      // Get all active directors
      final activeDirectors = await ref.read(
        getDirectorsProvider(DirectorFilterPresets.activeDirectors).future,
      );
      debugPrint('Found ${activeDirectors.length} active directors');

      // Get all producers
      final producers = await ref.read(
        getDirectorsProvider(DirectorFilterPresets.allProducers).future,
      );
      debugPrint('Found ${producers.length} producers');

      // Search directors by name
      final searchResults = await ref.read(
        searchDirectorsProvider('John').future,
      );
      debugPrint('Search results: ${searchResults.length} directors found');

    } catch (e) {
      debugPrint('Error retrieving directors: $e');
    }
  }

  /// Example: Update director profile
  static Future<void> updateDirectorExample(WidgetRef ref, String directorUid) async {
    try {
      final directorService = ref.read(directorServiceProvider);
      
      await directorService.updateDirectorProfile(
        uid: directorUid,
        bio: 'Updated bio with latest achievements',
        experience: 12, // Updated experience
        specializations: ['Drama', 'Action', 'Comedy', 'Sci-Fi'], // Added new specializations
        awards: ['Best Director 2024', 'Film Festival Winner 2023'],
      );
      
      debugPrint('Director profile updated successfully');
      
    } catch (e) {
      debugPrint('Error updating director: $e');
    }
  }

  /// Example: Get directors by production house
  static Future<void> getDirectorsByProductionHouseExample(WidgetRef ref) async {
    try {
      final directors = await ref.read(
        directorsByProductionHouseProvider('ABC Productions').future,
      );
      
      debugPrint('Found ${directors.length} directors from ABC Productions');
      for (final director in directors) {
        debugPrint('- ${director.fullName} (${director.role})');
      }
      
    } catch (e) {
      debugPrint('Error getting directors by production house: $e');
    }
  }

  /// Example: Using real-time stream
  static Widget directorStreamExample() {
    return Consumer(
      builder: (context, ref, child) {
        final directorsStream = ref.watch(
          directorsStreamProvider(DirectorFilterPresets.allActive),
        );

        return directorsStream.when(
          data: (directors) => ListView.builder(
            itemCount: directors.length,
            itemBuilder: (context, index) {
              final director = directors[index];
              return ListTile(
                title: Text(director.fullName),
                subtitle: Text('${director.role} at ${director.productionHouse ?? 'Independent'}'),
                trailing: Text('${director.experience ?? 0} years exp.'),
              );
            },
          ),
          loading: () => const CircularProgressIndicator(),
          error: (error, stack) => Text('Error: $error'),
        );
      },
    );
  }
}

/// Example Widget showing how to use the directors collection in a UI
class DirectorsListWidget extends ConsumerWidget {
  const DirectorsListWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directorsAsyncValue = ref.watch(
      getDirectorsProvider(DirectorFilterPresets.allActive),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Directors & Producers'),
      ),
      body: directorsAsyncValue.when(
        data: (directors) => Column(
          children: [
            // Statistics
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          '${directors.where((d) => d.role == 'director').length}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const Text('Directors'),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '${directors.where((d) => d.role == 'producer').length}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const Text('Producers'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Directors list
            Expanded(
              child: ListView.builder(
                itemCount: directors.length,
                itemBuilder: (context, index) {
                  final director = directors[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: director.profileImageUrl != null
                            ? NetworkImage(director.profileImageUrl!)
                            : null,
                        child: director.profileImageUrl == null
                            ? Text(director.fullName.substring(0, 1))
                            : null,
                      ),
                      title: Text(director.fullName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${director.role.toUpperCase()} • ${director.experience ?? 0} years'),
                          if (director.productionHouse != null)
                            Text(director.productionHouse!),
                          if (director.specializations != null && director.specializations!.isNotEmpty)
                            Text(director.specializations!.take(2).join(', ')),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.contact_phone),
                        onPressed: () {
                          // Handle contact action
                          debugPrint('Contact: ${director.phoneNumber}');
                        },
                      ),
                      onTap: () {
                        // Navigate to director profile
                        debugPrint('View profile: ${director.fullName}');
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading directors: $error'),
              ElevatedButton(
                onPressed: () => ref.invalidate(getDirectorsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to add director screen
          debugPrint('Add new director/producer');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}