import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_design_system.dart';
import '../../services/api_service.dart';
import '../../widgets/design_system/app_button.dart';
import '../../widgets/design_system/app_card.dart';
import '../../widgets/design_system/app_input_field.dart';
import '../../widgets/design_system/app_snackbar.dart';
import '../../widgets/design_system/app_empty_state.dart';
import 'package:dio/dio.dart';

class AdminLocationsScreen extends StatefulWidget {
  const AdminLocationsScreen({super.key});

  @override
  State<AdminLocationsScreen> createState() => _AdminLocationsScreenState();
}

class _AdminLocationsScreenState extends State<AdminLocationsScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _locations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _apiService.init();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getCampusLocations();
      if (response.data['success'] == true) {
        setState(() {
          _locations = List<Map<String, dynamic>>.from(response.data['data'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.data['message'] ?? 'Failed to load locations';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading locations: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteLocation(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Location'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _apiService.deleteCampusLocation(id);
      if (mounted) {
        AppSnackbar.success(context, 'Location deleted successfully');
        _loadLocations();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Error deleting location: ${e.toString()}');
      }
    }
  }

  void _showAddLocationDialog({Map<String, dynamic>? location}) {
    final isEdit = location != null;
    final nameController = TextEditingController(text: location?['name'] ?? '');
    final descController = TextEditingController(text: location?['description'] ?? '');
    final latController = TextEditingController(text: location?['latitude']?.toString() ?? '');
    final lngController = TextEditingController(text: location?['longitude']?.toString() ?? '');
    final categoryController = TextEditingController(text: location?['category'] ?? 'general');
    final iconController = TextEditingController(text: location?['icon'] ?? 'location_on');
    bool _isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Location' : 'Add Location'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppInputField(
                  controller: nameController,
                  label: 'Location Name *',
                  prefixIcon: Icons.place,
                ),
                const SizedBox(height: AppDesignSystem.spacingM),
                AppInputField(
                  controller: descController,
                  label: 'Description',
                  prefixIcon: Icons.description,
                  maxLines: 2,
                ),
                const SizedBox(height: AppDesignSystem.spacingM),
                Row(
                  children: [
                    Expanded(
                      child: AppInputField(
                        controller: latController,
                        label: 'Latitude *',
                        prefixIcon: Icons.navigation,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: AppDesignSystem.spacingS),
                    Expanded(
                      child: AppInputField(
                        controller: lngController,
                        label: 'Longitude *',
                        prefixIcon: Icons.navigation,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDesignSystem.spacingM),
                AppInputField(
                  controller: categoryController,
                  label: 'Category',
                  prefixIcon: Icons.category,
                  hint: 'e.g., building, facility, landmark',
                ),
                const SizedBox(height: AppDesignSystem.spacingM),
                AppInputField(
                  controller: iconController,
                  label: 'Icon Name',
                  prefixIcon: Icons.image,
                  hint: 'Material icon name (e.g., location_on)',
                ),
                const SizedBox(height: AppDesignSystem.spacingS),
                TextButton.icon(
                  onPressed: () async {
                    // Open map to select location
                    final result = await context.push('/map?selectLocation=true');
                    if (result != null && result is Map<String, dynamic> && mounted) {
                      latController.text = (result['latitude'] as num?)?.toString() ?? '';
                      lngController.text = (result['longitude'] as num?)?.toString() ?? '';
                      if (nameController.text.isEmpty) {
                        nameController.text = (result['address'] as String?) ?? '';
                      }
                    }
                  },
                  icon: const Icon(Icons.map),
                  label: const Text('Select on Map'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            AppButton(
              label: _isSaving ? 'Saving...' : (isEdit ? 'Update' : 'Add'),
              onPressed: _isSaving ? null : () async {
                if (nameController.text.isEmpty ||
                    latController.text.isEmpty ||
                    lngController.text.isEmpty) {
                  AppSnackbar.warning(context, 'Please fill all required fields');
                  return;
                }

                setDialogState(() => _isSaving = true);

                try {
                  final lat = double.tryParse(latController.text);
                  final lng = double.tryParse(lngController.text);

                  if (lat == null || lng == null) {
                    AppSnackbar.error(context, 'Invalid coordinates');
                    setDialogState(() => _isSaving = false);
                    return;
                  }

                  if (isEdit) {
                    await _apiService.updateCampusLocation(
                      location!['id'],
                      name: nameController.text.trim(),
                      description: descController.text.trim(),
                      latitude: lat,
                      longitude: lng,
                      category: categoryController.text.trim(),
                      icon: iconController.text.trim(),
                    );
                  } else {
                    await _apiService.createCampusLocation(
                      name: nameController.text.trim(),
                      description: descController.text.trim(),
                      latitude: lat,
                      longitude: lng,
                      category: categoryController.text.trim(),
                      icon: iconController.text.trim(),
                    );
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    AppSnackbar.success(
                      context,
                      isEdit ? 'Location updated successfully' : 'Location added successfully',
                    );
                    _loadLocations();
                  }
                } on DioException catch (e) {
                  if (mounted) {
                    AppSnackbar.error(
                      context,
                      e.response?.data['message'] ?? 'Error saving location',
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    AppSnackbar.error(context, 'Error: ${e.toString()}');
                  }
                } finally {
                  if (mounted) {
                    setDialogState(() => _isSaving = false);
                  }
                }
              },
              type: AppButtonType.primary,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Locations'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? AppEmptyState(
                  icon: Icons.error_outline,
                  title: 'Error Loading Locations',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _loadLocations,
                  iconColor: AppDesignSystem.errorColor,
                )
              : RefreshIndicator(
                  onRefresh: _loadLocations,
                  child: _locations.isEmpty
                      ? AppEmptyState(
                          icon: Icons.location_off,
                          title: 'No Locations',
                          message: 'Add campus locations to help users select nearby places',
                          actionLabel: 'Add First Location',
                          onAction: () => _showAddLocationDialog(),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppDesignSystem.spacingL),
                          itemCount: _locations.length,
                          itemBuilder: (context, index) {
                            final location = _locations[index];
                            return AppCard(
                              margin: const EdgeInsets.only(bottom: AppDesignSystem.spacingM),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppDesignSystem.primaryColor.withOpacity(0.1),
                                  child: Icon(
                                    _getIconData(location['icon'] ?? 'location_on'),
                                    color: AppDesignSystem.primaryColor,
                                  ),
                                ),
                                title: Text(
                                  location['name'] ?? 'Unknown',
                                  style: AppDesignSystem.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (location['description'] != null &&
                                        location['description'].toString().isNotEmpty)
                                      Text(
                                        location['description'],
                                        style: AppDesignSystem.bodySmall,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${location['latitude']?.toStringAsFixed(6) ?? 'N/A'}, ${location['longitude']?.toStringAsFixed(6) ?? 'N/A'}',
                                      style: AppDesignSystem.bodySmall.copyWith(
                                        color: AppDesignSystem.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _showAddLocationDialog(location: location),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteLocation(
                                        location['id'],
                                        location['name'] ?? 'Unknown',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddLocationDialog(),
        backgroundColor: AppDesignSystem.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    // Map common icon names to IconData
    switch (iconName) {
      case 'location_on':
        return Icons.location_on;
      case 'school':
        return Icons.school;
      case 'home':
        return Icons.home;
      case 'restaurant':
        return Icons.restaurant;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'sports_soccer':
        return Icons.sports_soccer;
      case 'library_books':
        return Icons.library_books;
      case 'apartment':
        return Icons.apartment;
      default:
        return Icons.location_on;
    }
  }
}

