import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/shimmer_widgets.dart';
import '../../config/app_design_system.dart';
import '../../widgets/design_system/app_card.dart';
import '../../widgets/design_system/app_chip.dart';
import '../../widgets/base64_image_widget.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final authService = ref.read(authServiceProvider);
      final userData = await authService.getUserData();
      setState(() {
        _userData = userData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final authService = ref.read(authServiceProvider);
        await authService.logout();
        
        if (mounted) {
          context.go('/landing');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error logging out: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final profilePicture = _userData?['profilePicture'];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: const Text('Profile'),
        elevation: 0,
        backgroundColor: AppDesignSystem.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const ProfileShimmer()
          : RefreshIndicator(
              onRefresh: _loadUserData,
              child: ListView(
                padding: const EdgeInsets.all(AppDesignSystem.spacingL),
                children: [
                  // Profile Header
                  AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDesignSystem.spacingXL),
                      child: Column(
                        children: [
                          // Profile Picture
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppDesignSystem.primaryColor,
                                width: 3,
                              ),
                            ),
                            child: ClipOval(
                              child: profilePicture != null
                                  ? Base64ImageWidget(
                                      imageUrl: profilePicture,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: AppDesignSystem.primaryColor.withOpacity(0.1),
                                      child: Center(
                                        child: Text(
                                          user?.displayName?.substring(0, 1).toUpperCase() ?? 
                                          user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                                          style: AppDesignSystem.heading2.copyWith(
                                            color: AppDesignSystem.primaryColor,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: AppDesignSystem.spacingM),
                          Text(
                            _userData?['displayName'] ?? user?.displayName ?? 'User',
                            style: AppDesignSystem.heading3.copyWith(
                              color: AppDesignSystem.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppDesignSystem.spacingXS),
                          Text(
                            user?.email ?? '',
                            style: AppDesignSystem.bodyMedium.copyWith(
                              color: AppDesignSystem.textSecondary,
                            ),
                          ),
                          if (_userData?['role'] != null) ...[
                            const SizedBox(height: AppDesignSystem.spacingS),
                            AppChip(
                              label: _userData!['role'].toString().toUpperCase(),
                              backgroundColor: AppDesignSystem.primaryColor.withOpacity(0.1),
                              textColor: AppDesignSystem.primaryColor,
                            ),
                          ],
                          if (_userData?['department'] != null) ...[
                            const SizedBox(height: AppDesignSystem.spacingS),
                            AppChip(
                              label: _userData!['department'].toString(),
                              backgroundColor: AppDesignSystem.secondaryColor.withOpacity(0.1),
                              textColor: AppDesignSystem.secondaryColor,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDesignSystem.spacingL),

                  // User Information
                  AppCard(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person, color: AppDesignSystem.primaryColor),
                          title: Text(
                            'Full Name',
                            style: AppDesignSystem.bodySmall.copyWith(
                              color: AppDesignSystem.textSecondary,
                            ),
                          ),
                          subtitle: Text(
                            _userData?['displayName'] ?? user?.displayName ?? 'Not set',
                            style: AppDesignSystem.bodyMedium.copyWith(
                              color: AppDesignSystem.textPrimary,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.email, color: AppDesignSystem.primaryColor),
                          title: Text(
                            'Email',
                            style: AppDesignSystem.bodySmall.copyWith(
                              color: AppDesignSystem.textSecondary,
                            ),
                          ),
                          subtitle: Text(
                            user?.email ?? 'Not set',
                            style: AppDesignSystem.bodyMedium.copyWith(
                              color: AppDesignSystem.textPrimary,
                            ),
                          ),
                        ),
                        if (_userData?['phoneNumber'] != null &&
                            _userData!['phoneNumber'].toString().isNotEmpty) ...[
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.phone, color: AppDesignSystem.primaryColor),
                            title: Text(
                              'Phone Number',
                              style: AppDesignSystem.bodySmall.copyWith(
                                color: AppDesignSystem.textSecondary,
                              ),
                            ),
                            subtitle: Text(
                              _userData!['phoneNumber'].toString(),
                              style: AppDesignSystem.bodyMedium.copyWith(
                                color: AppDesignSystem.textPrimary,
                              ),
                            ),
                          ),
                        ],
                        if (_userData?['department'] != null) ...[
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.business, color: AppDesignSystem.primaryColor),
                            title: Text(
                              'Department',
                              style: AppDesignSystem.bodySmall.copyWith(
                                color: AppDesignSystem.textSecondary,
                              ),
                            ),
                            subtitle: Text(
                              _userData!['department'].toString(),
                              style: AppDesignSystem.bodyMedium.copyWith(
                                color: AppDesignSystem.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDesignSystem.spacingL),

                  // Actions
                  AppCard(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.edit, color: AppDesignSystem.primaryColor),
                          title: Text(
                            'Edit Profile',
                            style: AppDesignSystem.bodyMedium.copyWith(
                              color: AppDesignSystem.textPrimary,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await context.push('/profile/edit');
                            // Refresh user data after returning from edit
                            _loadUserData();
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.help_outline, color: AppDesignSystem.primaryColor),
                          title: Text(
                            'Help & Support',
                            style: AppDesignSystem.bodyMedium.copyWith(
                              color: AppDesignSystem.textPrimary,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/profile/help'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDesignSystem.spacingL),

                  // Logout Button
                  AppCard(
                    backgroundColor: AppDesignSystem.errorColor.withOpacity(0.1),
                    child: ListTile(
                      leading: const Icon(Icons.logout, color: AppDesignSystem.errorColor),
                      title: Text(
                        'Logout',
                        style: AppDesignSystem.bodyMedium.copyWith(
                          color: AppDesignSystem.errorColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: _logout,
                    ),
                  ),
                  const SizedBox(height: AppDesignSystem.spacingXL),

                  // App Info
                  Center(
                    child: Text(
                      "People's Priorities v1.0.0",
                      style: AppDesignSystem.bodySmall.copyWith(
                        color: AppDesignSystem.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
