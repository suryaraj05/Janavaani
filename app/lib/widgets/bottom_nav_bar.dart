import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_design_system.dart';
import '../providers/auth_provider.dart';

class BottomNavBar extends ConsumerWidget {
  final String currentRoute;

  const BottomNavBar({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDataAsync = ref.watch(userDataProvider);
    final userRole = userDataAsync.value?['role'] as String? ?? 'citizen';

    // Define navigation items based on role
    List<NavItem> navItems;
    
    switch (userRole) {
      case 'admin':
        navItems = [
          NavItem(icon: Icons.home, label: 'Community', route: '/home'),
          NavItem(icon: Icons.map_outlined, label: 'Map', route: '/map'),
          NavItem(icon: Icons.dashboard, label: 'Admin', route: '/admin'),
          NavItem(icon: Icons.people, label: 'Users', route: '/admin/users'),
        ];
        break;
      case 'department':
        navItems = [
          NavItem(icon: Icons.home, label: 'Community', route: '/home'),
          NavItem(icon: Icons.map_outlined, label: 'Map', route: '/map'),
          NavItem(icon: Icons.dashboard, label: 'Dashboard', route: '/department'),
          NavItem(icon: Icons.person_outline, label: 'Profile', route: '/profile'),
        ];
        break;
      default: // citizen/user
        navItems = [
          NavItem(icon: Icons.home, label: 'Community', route: '/home'),
          NavItem(icon: Icons.add_circle_outline, label: 'Submit', route: '/submit-grievance'),
          NavItem(icon: Icons.map_outlined, label: 'Map', route: '/map'),
          NavItem(icon: Icons.person_outline, label: 'My Issues', route: '/grievances'),
        ];
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: navItems.map((item) => _buildNavItem(
              context,
              icon: item.icon,
              label: item.label,
              route: item.route,
              isActive: currentRoute == item.route,
            )).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    required bool isActive,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          if (currentRoute != route) {
            context.go(route);
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? AppDesignSystem.primaryColor : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? AppDesignSystem.primaryColor : Colors.grey[600],
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 4),
                height: 2,
                width: 40,
                decoration: BoxDecoration(
                  color: AppDesignSystem.primaryColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class NavItem {
  final IconData icon;
  final String label;
  final String route;

  NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}
