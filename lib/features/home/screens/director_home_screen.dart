import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aatt/features/auth/controllers/auth_controller.dart';
import 'package:aatt/features/auth/providers/director_providers.dart';
import 'package:aatt/features/home/widgets/actor_search_body.dart';

class DirectorHomeScreen extends ConsumerWidget {
  const DirectorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final directorAsync =
        ref.watch(getDirectorByUidProvider(authState.uid ?? ''));

    final directorName = directorAsync.when(
      data: (d) => d?.fullName ?? 'Director',
      loading: () => 'Loading…',
      error: (_, _) => 'Director',
    );

    return ActorSearchBody(
      welcomeSubtitle: 'Artistes Association of Telugu Television',
      userName: directorName,
      onLogout: () => ref.read(authControllerProvider.notifier).signOut(),
    );
  }
}
