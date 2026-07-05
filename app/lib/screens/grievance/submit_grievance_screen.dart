import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../services/config_service.dart';
import '../../utils/image_compression.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../config/app_design_system.dart';
import '../../widgets/design_system/app_button.dart';
import '../../widgets/design_system/app_card.dart';
import '../../widgets/design_system/app_chip.dart';
import '../../widgets/design_system/app_input_field.dart';
import '../../widgets/design_system/app_snackbar.dart';
import '../../widgets/design_system/progress_indicator.dart';
import '../../widgets/duplicate_grievance_dialog.dart';
import '../../models/grievance.dart';

class SubmitGrievanceScreen extends StatefulWidget {
  const SubmitGrievanceScreen({super.key});

  @override
  State<SubmitGrievanceScreen> createState() => _SubmitGrievanceScreenState();
}

class _SubmitGrievanceScreenState extends State<SubmitGrievanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();

  final _configService = ConfigService();
  final _apiService = ApiService();

  List<String> _departments = [];
  List<String> _priorities = [];
  List<String> _selectedDepartments = [];
  String? _selectedPriority;
  List<XFile> _selectedImages = [];
  String? _currentLocation;
  double? _latitude;
  double? _longitude;
  bool _isLoading = false;
  bool _isAnalyzing = false;
  bool _useCurrentLocation = false;
  bool _manualMode = false;
  bool _showVerification = false;
  bool _aiFilled = false;
  int _analysisStep = 0;
  String _analysisProgress = '';
  Map<String, dynamic>? _aiAnalysis;
  String? _errorMessage; // For displaying errors on screen

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _apiService.init();
  }

  Future<void> _loadConfig() async {
    final departments = await _configService.getDepartments();
    final priorities = await _configService.getPriorities();
    setState(() {
      _departments = departments;
      _priorities = priorities;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
          if (_selectedImages.length > 5) {
            _selectedImages = _selectedImages.take(5).toList();
      AppSnackbar.warning(context, 'Maximum 5 images allowed');
          }
        });

        // Auto-analyze if not in manual mode
        if (!_manualMode && _selectedImages.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 300));
          _analyzeWithAI();
        }
      }
    } catch (e) {
      AppSnackbar.error(context, 'Error picking images: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppSnackbar.warning(context, 'Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        AppSnackbar.warning(context, 'Location permission permanently denied. Please enable in settings.');
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppSnackbar.warning(context, 'Location services are disabled');
        return;
      }

      setState(() => _isLoading = true);

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _currentLocation = '${position.latitude},${position.longitude}';
        _locationController.text = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        _useCurrentLocation = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  Future<String> _imageToBase64(XFile imageFile) async {
    try {
      // Compress image first to reduce size (targeting max 1MB)
      final compressed = await compressImage(imageFile, maxWidth: 1280, quality: 75);
      final bytes = await compressed.readAsBytes();
      
      // Double-check size
      if (bytes.length > 1024 * 1024) {
        print('⚠️ Compressed image still > 1MB: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)}MB');
        // Try one more aggressive compression
        final moreCompressed = await compressImage(compressed, maxWidth: 800, quality: 60);
        final moreBytes = await moreCompressed.readAsBytes();
        if (moreBytes.length <= 1024 * 1024) {
          return base64Encode(moreBytes);
        }
      }
      
      return base64Encode(bytes);
    } catch (e) {
      print('❌ Error converting image to base64: $e');
      // Fallback to original if compression fails
      final bytes = await imageFile.readAsBytes();
      return base64Encode(bytes);
    }
  }

  Future<void> _analyzeWithAI() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload images for AI analysis')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisStep = 0;
      _analysisProgress = 'Preparing images...';
    });

    try {
      // Step 1: Compress and convert images
      setState(() {
        _analysisStep = 1;
        _analysisProgress = 'Optimizing images for analysis...';
      });

      List<String> imageBase64 = [];
      for (int i = 0; i < _selectedImages.length; i++) {
        setState(() {
          _analysisProgress = 'Processing image ${i + 1}/${_selectedImages.length}...';
        });
        final base64 = await _imageToBase64(_selectedImages[i]);
        imageBase64.add('data:image/jpeg;base64,$base64');
      }

      // Step 2: Send to AI
      setState(() {
        _analysisStep = 2;
        _analysisProgress = 'AI is analyzing your images...';
      });

      final response = await _apiService.analyzeGrievance(
        title: _titleController.text,
        description: _descriptionController.text,
        images: imageBase64,
      );

      // Step 3: Process results
      setState(() {
        _analysisStep = 3;
        _analysisProgress = 'Finalizing results...';
      });

      if (response.data['success'] == true) {
        final data = response.data['data'];
        setState(() {
          _aiAnalysis = data;
        });

        // Auto-fill if problem is related
        if (data['isProblemRelated'] == true) {
          if (data['suggestedTitle'] != null && _titleController.text.isEmpty) {
            _titleController.text = data['suggestedTitle'];
          }
          if (data['suggestedDescription'] != null && _descriptionController.text.isEmpty) {
            _descriptionController.text = data['suggestedDescription'];
          }
          if (data['suggestedDepartments'] != null && _selectedDepartments.isEmpty) {
            _selectedDepartments = List<String>.from(data['suggestedDepartments']);
          }
          if (data['suggestedPriority'] != null && _selectedPriority == null) {
            _selectedPriority = data['suggestedPriority'];
          }
          if (data['suggestedLocation'] != null && _locationController.text.isEmpty) {
            _locationController.text = data['suggestedLocation'];
          }

          setState(() {
            _aiFilled = true;
          });

          // Show location selection dialog if location is not set
          if (_locationController.text.trim().isEmpty && !_useCurrentLocation) {
            await _showLocationSelectionDialog();
          }

          setState(() {
            _showVerification = true;
          });

          AppSnackbar.success(
            context,
            'AI analysis complete! Confidence: ${((data['confidence'] ?? 0) * 100).toStringAsFixed(0)}%',
          );
        } else {
          AppSnackbar.warning(
            context,
            'AI detected this may not be a problem-related issue. Please fill manually.',
          );
          setState(() {
            _manualMode = true;
          });
        }
      } else {
        AppSnackbar.error(context, response.data['message'] ?? 'AI analysis failed');
      }
    } catch (e) {
      AppSnackbar.error(context, 'Error analyzing: ${e.toString()}');
    } finally {
      setState(() {
        _isAnalyzing = false;
        _analysisStep = 0;
        _analysisProgress = '';
      });
    }
  }

  Future<void> _submitGrievance() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDepartments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one department')),
      );
      return;
    }

    if (_selectedPriority == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a priority')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null; // Clear previous errors
    });

    try {
      // Compress images before sending
      List<String> imageBase64 = [];
      int totalSize = 0;
      for (var image in _selectedImages) {
        final base64 = await _imageToBase64(image);
        final imageData = 'data:image/jpeg;base64,$base64';
        final size = imageData.length;
        totalSize += size;
        
        // Check if image is too large (max 5MB per image, 10MB total)
        if (size > 5 * 1024 * 1024) {
          if (mounted) {
            AppSnackbar.warning(
              context,
              'Image ${imageBase64.length + 1} is too large. Please use smaller images.',
            );
          }
          setState(() => _isLoading = false);
          return;
        }
        
        imageBase64.add(imageData);
      }
      
      // Check total payload size
      if (totalSize > 10 * 1024 * 1024) {
        if (mounted) {
          AppSnackbar.warning(
            context,
            'Total image size is too large. Please reduce the number of images or their size.',
          );
        }
        setState(() => _isLoading = false);
        return;
      }
      
      print('📸 Image payload size: ${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB');

      final location = _useCurrentLocation 
          ? (_currentLocation ?? '')
          : _locationController.text.trim();
      
      // Ensure location is not empty
      if (location.isEmpty) {
        if (mounted) {
          AppSnackbar.warning(context, 'Please provide a location');
        }
        setState(() => _isLoading = false);
        return;
      }

      print('📤 Submitting grievance...');
      print('   Title: ${_titleController.text.trim()}');
      print('   Departments: $_selectedDepartments');
      print('   Priority: $_selectedPriority');
      print('   Location: $location');
      print('   Images: ${imageBase64.length}');
      print('   Latitude: $_latitude, Longitude: $_longitude');
      
      // Check for duplicates before submitting - STRICT CHECK
      try {
        print('🔍 [Submit] Checking for duplicates...');
        final existingGrievancesResponse = await _apiService.getGrievances(limit: 100);
        List<Map<String, dynamic>> existingGrievances = [];
        
        if (existingGrievancesResponse.data['success'] == true) {
          existingGrievances = List<Map<String, dynamic>>.from(
            existingGrievancesResponse.data['data'] ?? []
          );
        } else if (existingGrievancesResponse.data is List) {
          existingGrievances = List<Map<String, dynamic>>.from(existingGrievancesResponse.data);
        }
        
        print('🔍 [Submit] Found ${existingGrievances.length} existing grievances');
        
        // Quick check: Same title from same user in last 5 minutes
        final titleLower = _titleController.text.trim().toLowerCase();
        final now = DateTime.now();
        final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));
        
        final quickDuplicate = existingGrievances.firstWhere(
          (g) {
            final gTitle = (g['title'] as String? ?? '').toLowerCase();
            final gSubmittedBy = g['submittedBy'] as String? ?? '';
            final gCreatedAt = g['createdAt'];
            
            DateTime? createdAt;
            if (gCreatedAt is String) {
              createdAt = DateTime.tryParse(gCreatedAt);
            } else if (gCreatedAt is Map && gCreatedAt['_seconds'] != null) {
              createdAt = DateTime.fromMillisecondsSinceEpoch(gCreatedAt['_seconds'] * 1000);
            }
            
            return gTitle == titleLower && 
                   gSubmittedBy.isNotEmpty &&
                   createdAt != null &&
                   createdAt.isAfter(fiveMinutesAgo);
          },
          orElse: () => <String, dynamic>{},
        );
        
        if (quickDuplicate.isNotEmpty) {
          print('❌ [Submit] Quick duplicate check failed - same title from same user');
          if (mounted) {
            AppSnackbar.error(
              context,
              'You recently submitted a grievance with the same title. Please wait a few minutes or modify the title.',
            );
            setState(() => _isLoading = false);
            return;
          }
        }
        
        // AI-based duplicate check
        if (existingGrievances.isNotEmpty) {
          final duplicateCheck = await _apiService.checkDuplicates(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            images: imageBase64,
            latitude: _latitude,
            longitude: _longitude,
            existingGrievances: existingGrievances,
          );
          
          if (duplicateCheck.data['success'] == true && 
              duplicateCheck.data['data']['hasDuplicates'] == true) {
            final similarGrievances = duplicateCheck.data['data']['similarGrievances'] as List;
            
            // If similarity is very high (>0.9), block submission
            final highSimilarity = similarGrievances.any((match) {
              final score = (match['similarityScore'] ?? 0.0).toDouble();
              return score > 0.9;
            });
            
            if (highSimilarity) {
              print('❌ [Submit] High similarity duplicate detected (>90%)');
              if (mounted) {
                AppSnackbar.error(
                  context,
                  'A very similar grievance already exists. Please check existing grievances or modify your submission.',
                );
                setState(() => _isLoading = false);
                return;
              }
            }
            
            final matches = similarGrievances.map((match) {
              final grievanceData = existingGrievances.firstWhere(
                (g) => (g['grievanceId'] ?? g['id']) == match['grievanceId'],
                orElse: () => {},
              );
              return DuplicateMatch(
                grievance: Grievance.fromJson(grievanceData),
                similarityScore: (match['similarityScore'] ?? 0.0).toDouble(),
                reason: match['reason'] ?? 'Similar problem',
                isSameLocation: match['isSameLocation'] ?? false,
                canRevive: match['canRevive'] ?? false,
                distance: match['distance']?.toDouble(),
              );
            }).toList();
            
            final newGrievance = Grievance(
              grievanceId: '',
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              departments: _selectedDepartments,
              status: 'submitted',
              priority: _selectedPriority!,
              location: location,
              imageUrls: imageBase64,
              submittedBy: '',
              submittedByName: '',
              contactPhone: _phoneController.text.trim(),
              contactEmail: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              assignedTo: const [],
              latitude: _latitude,
              longitude: _longitude,
            );
            
            final shouldContinue = await showDialog<bool>(
              context: context,
              builder: (context) => DuplicateGrievanceDialog(
                similarGrievances: matches,
                newGrievance: newGrievance,
                onContinueAnyway: () => Navigator.pop(context, true),
                onCancel: () => Navigator.pop(context, false),
              ),
            );
            
            if (shouldContinue != true) {
              setState(() => _isLoading = false);
              return;
            }
          }
        }
      } catch (e) {
        print('⚠️ Error checking duplicates: $e');
        // Continue with submission even if duplicate check fails
      }
      
      print('✅ [Submit] No duplicates found, proceeding with submission...');
      final response = await _apiService.createGrievance(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        departments: _selectedDepartments,
        priority: _selectedPriority!,
        location: location,
        images: imageBase64,
        contactPhone: _phoneController.text.trim().isNotEmpty 
            ? _phoneController.text.trim() 
            : null,
        latitude: _latitude,
        longitude: _longitude,
      );

      print('📥 Response received:');
      print('   Status Code: ${response.statusCode}');
      print('   Success: ${response.data['success']}');
      print('   Message: ${response.data['message']}');
      if (response.data['data'] != null) {
        print('   Grievance ID: ${response.data['data']['id'] ?? response.data['data']['grievanceId']}');
      }

      if (response.data['success'] == true) {
        if (mounted) {
          // Hide verification screen first and clear errors
          setState(() {
            _showVerification = false;
            _errorMessage = null;
          });
          
          AppSnackbar.success(context, 'Grievance submitted successfully!');
          
          // Navigate back after a short delay
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              context.pop();
            }
          });
        }
      } else {
        if (mounted) {
          final errorMsg = response.data['message'] ?? 'Failed to submit grievance';
          setState(() {
            _errorMessage = errorMsg;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Submission Failed',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(errorMsg),
                  if (response.data['error'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Error Details: ${response.data['error']}',
                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 10),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () {
                  setState(() => _errorMessage = null);
                  _submitGrievance();
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error submitting grievance: $e');
      print('   Error type: ${e.runtimeType}');
      
      if (mounted) {
        String errorMessage = 'Error submitting grievance';
        String? detailedError;
        
        if (e is DioException) {
          print('   DioException details:');
          print('     Type: ${e.type}');
          print('     Status: ${e.response?.statusCode}');
          print('     Response: ${e.response?.data}');
          
          if (e.response?.statusCode == 401) {
            errorMessage = 'Authentication failed. Please login again.';
          } else if (e.response?.statusCode == 400) {
            errorMessage = e.response?.data['message'] ?? 'Invalid request. Please check your input.';
            detailedError = e.response?.data['message'];
          } else if (e.response?.statusCode == 500) {
            errorMessage = e.response?.data['message'] ?? 'Server error. Please try again later.';
            detailedError = e.response?.data['message'];
          } else if (e.type == DioExceptionType.connectionTimeout || 
                     e.type == DioExceptionType.receiveTimeout) {
            errorMessage = 'Request timeout. Please check your connection.';
          } else if (e.type == DioExceptionType.connectionError) {
            errorMessage = 'Connection error. Please check your internet connection.';
          } else {
            errorMessage = e.response?.data['message'] ?? 'Error: ${e.message}';
            detailedError = e.response?.data['message'];
          }
        } else {
          errorMessage = 'Error: ${e.toString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMessage),
                if (detailedError != null && detailedError != errorMessage)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      detailedError,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _submitGrievance(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleEditManually() {
    setState(() {
      _showVerification = false;
      _manualMode = true;
    });
  }

  Future<void> _showLocationSelectionDialog() async {
    List<Map<String, dynamic>> nearbyLocations = [];
    bool isLoadingLocations = true;

    // Try to get current location first to find nearby predefined locations
    if (_latitude == null || _longitude == null) {
      try {
        await _getCurrentLocation();
      } catch (e) {
        print('Could not get current location: $e');
      }
    }

    // Fetch nearby predefined locations if we have coordinates
    if (_latitude != null && _longitude != null) {
      try {
        final response = await _apiService.getNearbyCampusLocations(
          latitude: _latitude!,
          longitude: _longitude!,
          maxDistance: 500, // 500 meters
        );
        if (response.data['success'] == true) {
          nearbyLocations = List<Map<String, dynamic>>.from(response.data['data'] ?? []);
        }
      } catch (e) {
        print('Error fetching nearby locations: $e');
      }
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Location'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (nearbyLocations.isNotEmpty) ...[
                      Text(
                        'Nearby Campus Locations:',
                        style: AppDesignSystem.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppDesignSystem.spacingS),
                      ...nearbyLocations.take(5).map((location) {
                        return ListTile(
                          leading: Icon(
                            Icons.location_on,
                            color: AppDesignSystem.primaryColor,
                          ),
                          title: Text(location['name'] ?? 'Unknown'),
                          subtitle: Text(
                            location['distance'] != null
                                ? '${location['distance']}m away'
                                : (location['description'] ?? ''),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            setState(() {
                              _latitude = location['latitude']?.toDouble();
                              _longitude = location['longitude']?.toDouble();
                              _locationController.text = location['name'] ?? '';
                              _useCurrentLocation = false;
                            });
                            Navigator.of(context).pop();
                          },
                        );
                      }),
                      const Divider(),
                      const SizedBox(height: AppDesignSystem.spacingS),
                    ],
                    Text(
                      'Or choose another option:',
                      style: AppDesignSystem.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppDesignSystem.spacingS),
                    TextButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _getCurrentLocation();
                      },
                      icon: const Icon(Icons.my_location),
                      label: const Text('Use Current Location'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        // Navigate to map screen for location selection
                        final result = await context.push('/map?selectLocation=true');
                        if (result != null && result is Map<String, dynamic>) {
                          setState(() {
                            _latitude = result['latitude'] as double?;
                            _longitude = result['longitude'] as double?;
                            if (_latitude != null && _longitude != null) {
                              _locationController.text = result['address'] ?? '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}';
                            } else {
                              _locationController.text = result['address'] ?? '';
                            }
                            _useCurrentLocation = false;
                          });
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
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Skip for Now'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleVerifyAndSubmit() async {
    print('🔵 _handleVerifyAndSubmit called');
    
    // Don't validate form here - let _submitGrievance handle it
    // Just ensure we have the minimum required fields
    
    if (_selectedDepartments.isEmpty) {
      AppSnackbar.warning(context, 'Please select at least one department');
      return;
    }

    if (_selectedPriority == null) {
      AppSnackbar.warning(context, 'Please select a priority');
      return;
    }

    // Check if location is needed
    if (_locationController.text.trim().isEmpty && !_useCurrentLocation) {
      // Show location selection dialog
      await _showLocationSelectionDialog();
      // After dialog, check again
      if (_locationController.text.trim().isEmpty && !_useCurrentLocation) {
        AppSnackbar.warning(context, 'Please provide a location');
        return;
      }
    }

    // Hide verification screen and submit directly
    print('🔵 Hiding verification screen and submitting...');
    setState(() {
      _showVerification = false;
    });
    
    // Small delay to ensure UI updates
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Now call submit directly
    if (mounted) {
      print('🔵 Calling _submitGrievance...');
      await _submitGrievance();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundColor,
      appBar: AppBar(
        title: const Text('Report an Issue'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _showVerification ? _buildVerificationScreen() : _buildFormScreen(),
      bottomNavigationBar: const BottomNavBar(currentRoute: '/submit-grievance'),
    );
  }

  Widget _buildFormScreen() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Error Display Banner
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                border: Border.all(color: Colors.red[300]!, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700], size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Submission Error',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[900],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        color: Colors.red[700],
                        onPressed: () {
                          setState(() => _errorMessage = null);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _errorMessage = null);
                        _submitGrievance();
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry Submission'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Help us improve your campus.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ),

          // Manual Mode Toggle
          if (!_manualMode)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _manualMode = true;
                  });
                },
                child: const Text('Fill all fields manually'),
              ),
            ),

          // Image Upload Section (First for AI mode)
          if (!_manualMode) ...[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.image, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Upload Images (AI will auto-fill form)',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // AI Analysis Loading
                    if (_isAnalyzing) _buildAIAnalysisProgress(),
                    
                    // Image Grid
                    if (_selectedImages.isEmpty && !_isAnalyzing)
                      _buildImageUploadButton()
                    else if (!_isAnalyzing)
                      _buildImageGrid(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Title
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Title *',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'Brief description of the issue',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.title),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Description
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description *',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      hintText: 'Detailed description of the issue',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.description),
                    ),
                    maxLines: 5,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a description';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Images (for manual mode)
          if (_manualMode) ...[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.image, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Images (${_selectedImages.length}/5)',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_selectedImages.isEmpty)
                      _buildImageUploadButton()
                    else
                      _buildImageGrid(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Location
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Location',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _locationController,
                          decoration: InputDecoration(
                            hintText: 'Enter location or use GPS',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(Icons.place),
                            enabled: !_useCurrentLocation,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : () => _showLocationSelectionDialog(),
                        icon: const Icon(Icons.location_city),
                        label: const Text('Nearby'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppDesignSystem.secondaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _getCurrentLocation,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location),
                        label: const Text('GPS'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                  if (_useCurrentLocation)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Using current location',
                            style: TextStyle(color: Colors.green, fontSize: 12),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _useCurrentLocation = false;
                                _currentLocation = null;
                                _locationController.clear();
                              });
                            },
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Departments
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.business, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Departments *',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_departments.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _departments.map((dept) {
                        final isSelected = _selectedDepartments.contains(dept);
                        final isAISuggested = _aiAnalysis != null &&
                            _aiAnalysis!['suggestedDepartments'] != null &&
                            (_aiAnalysis!['suggestedDepartments'] as List).contains(dept);
                        
                        return FilterChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(dept),
                              if (isAISuggested) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.auto_awesome, size: 14, color: Colors.amber),
                              ],
                            ],
                          ),
                          selected: isSelected,
                          selectedColor: Theme.of(context).colorScheme.primaryContainer,
                          checkmarkColor: Theme.of(context).colorScheme.primary,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedDepartments.add(dept);
                              } else {
                                _selectedDepartments.remove(dept);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  if (_selectedDepartments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Please select at least one department',
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Priority
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.priority_high, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Priority *',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_priorities.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _priorities.map((priority) {
                        final isSelected = _selectedPriority == priority;
                        final isAISuggested = _aiAnalysis != null &&
                            _aiAnalysis!['suggestedPriority'] == priority;
                        
                        Color? chipColor;
                        IconData? chipIcon;
                        
                        switch (priority) {
                          case 'urgent':
                            chipColor = Colors.red;
                            chipIcon = Icons.warning;
                            break;
                          case 'high':
                            chipColor = Colors.orange;
                            chipIcon = Icons.error_outline;
                            break;
                          case 'medium':
                            chipColor = Colors.amber;
                            chipIcon = Icons.info_outline;
                            break;
                          case 'low':
                            chipColor = Colors.green;
                            chipIcon = Icons.check_circle_outline;
                            break;
                        }

                        return FilterChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (chipIcon != null) ...[
                                Icon(chipIcon, size: 16, color: isSelected ? chipColor : null),
                                const SizedBox(width: 4),
                              ],
                              Text(priority.toUpperCase()),
                              if (isAISuggested) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.auto_awesome, size: 14, color: Colors.amber),
                              ],
                            ],
                          ),
                          selected: isSelected,
                          selectedColor: chipColor?.withOpacity(0.2),
                          checkmarkColor: chipColor,
                          onSelected: (selected) {
                            setState(() {
                              _selectedPriority = selected ? priority : null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  if (_selectedPriority == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Please select a priority',
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Contact Phone
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact Phone (Optional)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      hintText: 'Your contact number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : () {
                if (_manualMode || !_aiFilled) {
                  _submitGrievance();
                } else {
                  setState(() {
                    _showVerification = true;
                  });
                }
              },
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(_isLoading ? 'Submitting...' : 'Submit Grievance'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildVerificationScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 4,
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _aiFilled ? 'AI Auto-filled Form - Please Verify' : 'Review Before Submitting',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_aiAnalysis != null && _aiAnalysis!['confidence'] != null) ...[
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(
                      'Confidence: ${((_aiAnalysis!['confidence'] ?? 0) * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.amber.withOpacity(0.2),
                  ),
                ],
                const SizedBox(height: 24),

                // Title
                _buildVerificationField('Title', _titleController.text, Icons.title),
                const SizedBox(height: 16),

                // Description
                _buildVerificationField('Description', _descriptionController.text, Icons.description),
                const SizedBox(height: 16),

                // Location
                if (_locationController.text.isNotEmpty)
                  _buildVerificationField('Location', _locationController.text, Icons.location_on),
                if (_locationController.text.isNotEmpty) const SizedBox(height: 16),

                // Departments
                _buildVerificationChips('Departments', _selectedDepartments),
                const SizedBox(height: 16),

                // Priority
                _buildVerificationPriority(),
                const SizedBox(height: 16),

                // Images
                if (_selectedImages.isNotEmpty) ...[
                  Text(
                    'Uploaded Images',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_selectedImages[index].path),
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // AI Reasoning
                if (_aiAnalysis != null && _aiAnalysis!['reasoning'] != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.psychology, color: AppDesignSystem.primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI Analysis',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _aiAnalysis!['reasoning'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _handleEditManually,
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Manually'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _handleVerifyAndSubmit,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle),
                        label: const Text('Confirm & Submit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationField(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.black87),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationChips(String label, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) => Chip(
            label: Text(item),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildVerificationPriority() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Priority',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        if (_selectedPriority != null)
          Chip(
            label: Text(_selectedPriority!.toUpperCase()),
            backgroundColor: _getPriorityColor(_selectedPriority!).withOpacity(0.2),
          ),
      ],
    );
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
        return AppDesignSystem.textTertiary;
    }
  }

  Widget _buildImageUploadButton() {
    return InkWell(
      onTap: _pickImages,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid, width: 2),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[50],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey[600]),
            const SizedBox(height: 8),
            Text(
              'Tap to add images',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Up to 5 images',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._selectedImages.asMap().entries.map((entry) {
          final index = entry.key;
          final image = entry.value;
          return Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(image.path),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.red,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => _removeImage(index),
                  ),
                ),
              ),
            ],
          );
        }),
        if (_selectedImages.length < 5)
          InkWell(
            onTap: _pickImages,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[50],
              ),
              child: const Icon(Icons.add, size: 32, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Widget _buildAIAnalysisProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.psychology, 
                color: Theme.of(context).colorScheme.primary, 
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI is Working Its Magic! ✨',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _analysisProgress,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _analysisStep / 3,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          _buildAnalysisStep('Optimizing images...', _analysisStep >= 1),
          _buildAnalysisStep('Processing image data...', _analysisStep >= 2),
          _buildAnalysisStep('AI analyzing content...', _analysisStep >= 3),
        ],
      ),
    );
  }

  Widget _buildAnalysisStep(String label, bool completed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: completed ? Colors.green : Colors.grey[300],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: completed ? Colors.green[700] : Colors.grey[600],
              fontWeight: completed ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
