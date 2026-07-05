import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_design_system.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/design_system/app_card.dart';
import '../../widgets/design_system/app_chip.dart';
import '../../widgets/shimmer_widgets.dart';
import '../../widgets/design_system/app_empty_state.dart';
import '../../services/api_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all'; // all, citizen, department, admin

  @override
  void initState() {
    super.initState();
    _apiService.init();
    Future.delayed(const Duration(milliseconds: 500), () {
      _loadUsers();
    });
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getUsers();
      
      if (response.data['success'] == true) {
        List<Map<String, dynamic>> allUsers = List<Map<String, dynamic>>.from(
          response.data['data'] ?? []
        );
        
        // Filter by role if needed
        if (_selectedFilter != 'all') {
          allUsers = allUsers.where((user) {
            final role = (user['role'] as String? ?? 'citizen').toLowerCase();
            return role == _selectedFilter.toLowerCase();
          }).toList();
        }
        
        setState(() {
          _users = allUsers;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.data['message'] ?? 'Failed to load users';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading users: ${e.toString()}';
        _isLoading = false;
      });
      print('Error loading users: $e');
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return AppDesignSystem.errorColor;
      case 'department':
        return AppDesignSystem.statusInProgress;
      case 'citizen':
        return AppDesignSystem.statusResolved;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundColor,
      appBar: AppBar(
        title: const Text('Users Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: AppDesignSystem.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUsers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Filter Chips - Always visible
                        Text(
                          'Filters',
                          style: AppDesignSystem.heading4.copyWith(
                            color: AppDesignSystem.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppDesignSystem.spacingS),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('all', 'All'),
                              const SizedBox(width: AppDesignSystem.spacingS),
                              _buildFilterChip('citizen', 'Citizens'),
                              const SizedBox(width: AppDesignSystem.spacingS),
                              _buildFilterChip('department', 'Departments'),
                              const SizedBox(width: AppDesignSystem.spacingS),
                              _buildFilterChip('admin', 'Admins'),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDesignSystem.spacingL),
                        
                        // Users List
                        Text(
                          'Users (${_users.length})',
                          style: AppDesignSystem.heading4,
                        ),
                        const SizedBox(height: AppDesignSystem.spacingM),
                        _users.isEmpty
                            ? AppEmptyState(
                                icon: Icons.people_outline,
                                title: 'No users',
                                message: 'User management feature requires backend API endpoint.',
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _users.length,
                                itemBuilder: (context, index) {
                                  final user = _users[index];
                                  return _buildUserCard(user);
                                },
                              ),
                      ],
                    ),
                  ),
                ),
      bottomNavigationBar: const BottomNavBar(currentRoute: '/admin/users'),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppDesignSystem.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = value;
          });
          _loadUsers();
        },
        selectedColor: AppDesignSystem.primaryColor,
        backgroundColor: AppDesignSystem.cardColor,
        checkmarkColor: Colors.white,
        side: BorderSide(
          color: isSelected ? AppDesignSystem.primaryColor : Colors.grey[300]!,
          width: 1,
        ),
        elevation: isSelected ? 2 : 0,
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final role = user['role'] as String? ?? 'citizen';
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppDesignSystem.spacingM),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppDesignSystem.primaryColor,
                  child: Text(
                    (user['displayName'] as String? ?? 'U').substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: AppDesignSystem.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['displayName'] as String? ?? 'Unknown',
                        style: AppDesignSystem.heading4,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user['email'] as String? ?? '',
                        style: AppDesignSystem.bodySmall.copyWith(
                          color: AppDesignSystem.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                AppChip(
                  label: role.toUpperCase(),
                  backgroundColor: _getRoleColor(role).withOpacity(0.1),
                  textColor: _getRoleColor(role),
                ),
              ],
            ),
            if (user['department'] != null) ...[
              const SizedBox(height: AppDesignSystem.spacingS),
              Row(
                children: [
                  Icon(Icons.business, size: 16, color: AppDesignSystem.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    user['department'] as String,
                    style: AppDesignSystem.bodySmall.copyWith(
                      color: AppDesignSystem.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

