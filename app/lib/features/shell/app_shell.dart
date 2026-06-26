import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/features/home/home_screen.dart';
import 'package:gymbuddy/features/plans/plans_screen.dart';
import 'package:gymbuddy/features/profile/profile_screen.dart';
import 'package:gymbuddy/features/workout/workout_screen.dart';

/// Owns the selected bottom-nav tab index.
///
/// Held in Riverpod rather than widget state so the selection survives shell
/// rebuilds and is inspectable in tests, per the no-logic-in-widgets rule.
class ShellTabController extends Notifier<int> {
  @override
  int build() => 0;

  /// Selects the tab at [index] (0-based, matching the destination order).
  void select(int index) => state = index;
}

/// The selected bottom-nav tab index. `autoDispose` resets it to Home on a
/// fresh sign-in (the shell is torn down while signed out).
final shellTabProvider =
    NotifierProvider.autoDispose<ShellTabController, int>(
  ShellTabController.new,
);

/// The authenticated app shell: four primary destinations behind a bottom
/// navigation bar.
///
/// Tab bodies are kept alive across switches via [IndexedStack] so scroll
/// position and in-progress state aren't lost when the user hops tabs. The tab
/// bodies are placeholders today; each feature fills in its screen in M3–M6.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const List<Widget> _tabs = <Widget>[
    HomeScreen(),
    PlansScreen(),
    WorkoutScreen(),
    ProfileScreen(),
  ];

  static const List<NavigationDestination> _destinations =
      <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.list_alt_outlined),
      selectedIcon: Icon(Icons.list_alt),
      label: 'Plans',
    ),
    NavigationDestination(
      icon: Icon(Icons.fitness_center_outlined),
      selectedIcon: Icon(Icons.fitness_center),
      label: 'Workout',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(shellTabProvider);
    return Scaffold(
      body: IndexedStack(index: index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) =>
            ref.read(shellTabProvider.notifier).select(i),
        destinations: _destinations,
      ),
    );
  }
}
