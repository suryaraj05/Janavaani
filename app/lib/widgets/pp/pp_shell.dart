import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_design_system.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shell_tab_provider.dart';
import '../../screens/dashboard/priorities_dashboard_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/map/hotspot_map_screen.dart';
import '../../screens/profile/profile_screen.dart';

/// Primary navigation shell — bottom tabs + voice FAB.
class PpShellScreen extends ConsumerWidget {
  const PpShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(shellTabProvider);
    final role = ref.watch(userDataProvider).value?['role'] as String? ?? 'citizen';
    final isStaff = role == 'mp' || role == 'mp_staff' || role == 'admin';

    final pages = [
      isStaff ? const PrioritiesDashboardScreen(embedded: true) : const HomeScreen(embedded: true),
      const PrioritiesDashboardScreen(embedded: true),
      const HotspotMapScreen(embedded: true),
      const ProfileScreen(embedded: true),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/submit'),
        backgroundColor: AppDesignSystem.accentColor,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.mic_rounded),
        label: const Text('Voice'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => ref.read(shellTabProvider.notifier).state = i,
        destinations: [
          NavigationDestination(
            icon: Icon(isStaff ? Icons.dashboard_outlined : Icons.home_outlined),
            selectedIcon: Icon(isStaff ? Icons.dashboard : Icons.home),
            label: isStaff ? 'Dashboard' : 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.format_list_numbered_outlined),
            selectedIcon: Icon(Icons.format_list_numbered),
            label: 'Priorities',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
