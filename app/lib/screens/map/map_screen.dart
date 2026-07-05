import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../config/app_design_system.dart';
import '../../widgets/shimmer_widgets.dart';
import '../../widgets/design_system/app_button.dart';
import '../../widgets/design_system/app_card.dart';
import '../../widgets/design_system/app_chip.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../services/api_service.dart';
import '../../models/grievance.dart';

class MapScreen extends StatefulWidget {
  final bool selectLocation;
  
  const MapScreen({
    super.key,
    this.selectLocation = false,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  LatLng? _currentLocation;
  bool _isLoading = true;
  String? _selectedAddress;
  List<Grievance> _grievances = [];
  Grievance? _selectedGrievance;
  final ApiService _apiService = ApiService();
  bool _showLocations = false; // Toggle between problems and locations
  List<Map<String, dynamic>> _campusLocations = [];
  List<Map<String, dynamic>> _optimizedRoutes = []; // TSP optimized route groups
  Map<String, dynamic>? _routeSummary;

  @override
  void initState() {
    super.initState();
    _apiService.init();
    _getCurrentLocation();
    if (!widget.selectLocation) {
      _loadGrievances();
      _loadCampusLocations();
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for optimized routes from navigation extra
    final extra = GoRouterState.of(context).extra;
    if (extra != null && extra is Map && extra['groups'] != null && _optimizedRoutes.isEmpty) {
      setState(() {
        _optimizedRoutes = List<Map<String, dynamic>>.from(extra['groups'] ?? []);
        _routeSummary = extra['summary'] as Map<String, dynamic>?;
      });
      // Show route summary after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showOptimizedRoutes();
        }
      });
    }
  }
  
  void _showOptimizedRoutes() {
    if (_optimizedRoutes.isEmpty) return;
    
    // Show dialog with route summary
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Optimized Routes'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_routeSummary != null) ...[
                Text('Total Groups: ${_routeSummary!['totalGroups'] ?? 0}'),
                Text('Total Distance: ${(_routeSummary!['totalDistance'] ?? 0).toStringAsFixed(2)} km'),
                const SizedBox(height: 16),
              ],
              ..._optimizedRoutes.asMap().entries.map((entry) {
                final group = entry.value;
                final index = entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Route ${index + 1}: ${group['grievances']?.length ?? 0} grievances, ${(group['totalDistance'] ?? 0).toStringAsFixed(2)} km',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadCampusLocations() async {
    try {
      final response = await _apiService.getCampusLocations();
      if (response.data['success'] == true) {
        setState(() {
          _campusLocations = List<Map<String, dynamic>>.from(response.data['data'] ?? []);
        });
      }
    } catch (e) {
      print('Error loading campus locations: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever || 
          permission == LocationPermission.denied) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        if (widget.selectLocation) {
          _selectedLocation = _currentLocation;
        }
        _isLoading = false;
      });

      // Move map to current location
      if (_currentLocation != null) {
        _mapController.move(_currentLocation!, 15.0);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadGrievances() async {
    try {
      final response = await _apiService.getGrievances(limit: 100);
      
      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        setState(() {
          _grievances = data
              .map((json) => Grievance.fromJson(json))
              .where((g) => g.latitude != null && g.longitude != null)
              .toList();
        });
      } else if (response.data is List) {
        final List<dynamic> data = response.data;
        setState(() {
          _grievances = data
              .map((json) => Grievance.fromJson(json))
              .where((g) => g.latitude != null && g.longitude != null)
              .toList();
        });
      }
    } catch (e) {
      print('Error loading grievances: $e');
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (widget.selectLocation) {
      setState(() {
        _selectedLocation = point;
        _selectedAddress = '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
      });
    } else {
      // Find nearest grievance
      Grievance? nearest;
      double? minDistance;
      
      for (var grievance in _grievances) {
        if (grievance.latitude != null && grievance.longitude != null) {
          final distance = const Distance().as(
            LengthUnit.Meter,
            point,
            LatLng(grievance.latitude!, grievance.longitude!),
          );
          if (minDistance == null || distance < minDistance) {
            minDistance = distance;
            nearest = grievance;
          }
        }
      }
      
      if (nearest != null && minDistance != null && minDistance < 100) {
        setState(() {
          _selectedGrievance = nearest;
        });
      } else {
        setState(() {
          _selectedGrievance = null;
        });
      }
    }
  }

  void _confirmSelection() {
    if (_selectedLocation != null && widget.selectLocation) {
      context.pop({
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'address': _selectedAddress ?? '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
      });
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return AppDesignSystem.priorityUrgent;
      case 'high':
        return AppDesignSystem.priorityHigh;
      case 'medium':
        return AppDesignSystem.priorityMedium;
      case 'low':
        return AppDesignSystem.priorityLow;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return AppDesignSystem.statusSubmitted;
      case 'assigned':
        return AppDesignSystem.statusAssigned;
      case 'in_progress':
        return AppDesignSystem.statusInProgress;
      case 'resolved':
        return AppDesignSystem.statusResolved;
      case 'closed':
        return AppDesignSystem.statusClosed;
      case 'rejected':
        return AppDesignSystem.statusRejected;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultLocation = LatLng(18.883747, 77.920214); // Default campus location

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectLocation ? 'Select Location' : 'Map View'),
        actions: widget.selectLocation
            ? [
                TextButton(
                  onPressed: _selectedLocation != null ? _confirmSelection : null,
                  child: const Text(
                    'Confirm',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ]
            : [
                if (!widget.selectLocation)
                  IconButton(
                    icon: Icon(_showLocations ? Icons.report_problem : Icons.location_on),
                    tooltip: _showLocations ? 'Show Problems' : 'Show Locations',
                    onPressed: () {
                      setState(() {
                        _showLocations = !_showLocations;
                      });
                    },
                  ),
              ],
      ),
      body: _isLoading
          ? const MapShimmer()
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation ?? defaultLocation,
                    initialZoom: 15.0,
                    onTap: _onMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.surya.campusconnect',
                    ),
                    if (_currentLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentLocation!,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.blue,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    if (widget.selectLocation && _selectedLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation!,
                            width: 50,
                            height: 50,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 50,
                            ),
                          ),
                        ],
                      ),
                    if (!widget.selectLocation && !_showLocations)
                      MarkerLayer(
                        markers: _grievances.map((grievance) {
                          if (grievance.latitude == null || grievance.longitude == null) {
                            return Marker(point: LatLng(0, 0), width: 0, height: 0, child: Container());
                          }
                          return Marker(
                            point: LatLng(grievance.latitude!, grievance.longitude!),
                            width: 40,
                            height: 40,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedGrievance = grievance;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _getPriorityColor(grievance.priority),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    if (!widget.selectLocation && _showLocations)
                      MarkerLayer(
                        markers: _campusLocations.map((location) {
                          final lat = location['latitude'] as double?;
                          final lng = location['longitude'] as double?;
                          if (lat == null || lng == null) {
                            return Marker(point: LatLng(0, 0), width: 0, height: 0, child: Container());
                          }
                          return Marker(
                            point: LatLng(lat, lng),
                            width: 40,
                            height: 40,
                            child: GestureDetector(
                              onTap: () {
                                // Show location details
                                showModalBottomSheet(
                                  context: context,
                                  builder: (context) => AppCard(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          location['name'] ?? 'Location',
                                          style: AppDesignSystem.heading4,
                                        ),
                                        if (location['description'] != null) ...[
                                          const SizedBox(height: AppDesignSystem.spacingS),
                                          Text(
                                            location['description'],
                                            style: AppDesignSystem.bodySmall,
                                          ),
                                        ],
                                        const SizedBox(height: AppDesignSystem.spacingM),
                                        Row(
                                          children: [
                                            Icon(Icons.location_on, size: 16, color: AppDesignSystem.textSecondary),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                                              style: AppDesignSystem.bodySmall.copyWith(
                                                color: AppDesignSystem.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppDesignSystem.secondaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.place,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
                if (widget.selectLocation && _selectedLocation != null)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: AppCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected Location:',
                            style: AppDesignSystem.labelLarge,
                          ),
                          const SizedBox(height: AppDesignSystem.spacingXS),
                          Text(
                            _selectedAddress ?? 
                            '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                            style: AppDesignSystem.bodySmall,
                          ),
                          const SizedBox(height: AppDesignSystem.spacingM),
                          AppButton(
                            label: 'Confirm Selection',
                            icon: Icons.check,
                            onPressed: _confirmSelection,
                            fullWidth: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!widget.selectLocation && _selectedGrievance != null)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: AppCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedGrievance!.title,
                                  style: AppDesignSystem.heading4,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    _selectedGrievance = null;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDesignSystem.spacingS),
                          Row(
                            children: [
                              AppChip(
                                label: _selectedGrievance!.priority.toUpperCase(),
                                backgroundColor: _getPriorityColor(_selectedGrievance!.priority).withOpacity(0.1),
                                textColor: _getPriorityColor(_selectedGrievance!.priority),
                              ),
                              const SizedBox(width: AppDesignSystem.spacingS),
                              AppChip(
                                label: _selectedGrievance!.status.replaceAll('_', ' ').toUpperCase(),
                                backgroundColor: _getStatusColor(_selectedGrievance!.status).withOpacity(0.1),
                                textColor: _getStatusColor(_selectedGrievance!.status),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDesignSystem.spacingS),
                          Text(
                            _selectedGrievance!.description,
                            style: AppDesignSystem.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppDesignSystem.spacingM),
                          AppButton(
                            label: 'View Details',
                            icon: Icons.arrow_forward,
                            onPressed: () {
                              context.push('/grievance/${_selectedGrievance!.grievanceId}');
                            },
                            fullWidth: true,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: widget.selectLocation ? null : BottomNavBar(currentRoute: '/map'),
    );
  }
}
