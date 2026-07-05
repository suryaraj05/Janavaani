class Grievance {
  final String grievanceId;
  final String title;
  final String description;
  final List<String> departments;
  final String status;
  final String priority;
  final String location;
  final List<String> imageUrls;
  final List<String> afterPhotos;
  final String submittedBy;
  final String submittedByName;
  final String contactPhone;
  final String contactEmail;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final List<String> assignedTo;
  final double? latitude;
  final double? longitude;
  final int upvotes;
  final List<String> upvotedBy;
  final List<Map<String, dynamic>>? statusHistory;

  Grievance({
    required this.grievanceId,
    required this.title,
    required this.description,
    required this.departments,
    required this.status,
    required this.priority,
    required this.location,
    required this.imageUrls,
    this.afterPhotos = const [],
    required this.submittedBy,
    required this.submittedByName,
    required this.contactPhone,
    required this.contactEmail,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    required this.assignedTo,
    this.latitude,
    this.longitude,
    this.upvotes = 0,
    this.upvotedBy = const [],
    this.statusHistory = const [],
  });

  factory Grievance.fromJson(Map<String, dynamic> json) {
    return Grievance(
      grievanceId: json['grievanceId'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      departments: List<String>.from(json['departments'] ?? []),
      status: json['status'] ?? 'submitted',
      priority: json['priority'] ?? 'medium',
      location: json['location'] ?? '',
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      afterPhotos: List<String>.from(json['afterPhotos'] ?? []),
      submittedBy: json['submittedBy'] ?? '',
      submittedByName: json['submittedByName'] ?? '',
      contactPhone: json['contactPhone'] ?? '',
      contactEmail: json['contactEmail'] ?? '',
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      resolvedAt: json['resolvedAt'] != null ? _parseDateTime(json['resolvedAt']) : null,
      assignedTo: List<String>.from(json['assignedTo'] ?? []),
      latitude: json['latitude'] != null ? (json['latitude'] is num ? json['latitude'].toDouble() : double.tryParse(json['latitude'].toString())) : null,
      longitude: json['longitude'] != null ? (json['longitude'] is num ? json['longitude'].toDouble() : double.tryParse(json['longitude'].toString())) : null,
      upvotes: json['upvotes'] ?? 0,
      upvotedBy: List<String>.from(json['upvotedBy'] ?? []),
      statusHistory: json['statusHistory'] != null 
          ? List<Map<String, dynamic>>.from(json['statusHistory'])
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'departments': departments,
      'status': status,
      'priority': priority,
      'location': location,
      'imageUrls': imageUrls,
      'contactPhone': contactPhone,
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    
    // If already a DateTime, return it
    if (value is DateTime) return value;
    
    // If it's a Map (Firestore Timestamp from backend)
    if (value is Map) {
      // Check if it's a Firestore timestamp format: {seconds: ..., nanoseconds: ...}
      if (value.containsKey('seconds') || value.containsKey('_seconds')) {
        final seconds = value['seconds'] ?? value['_seconds'] ?? 0;
        final nanoseconds = value['nanoseconds'] ?? value['_nanoseconds'] ?? 0;
        return DateTime.fromMillisecondsSinceEpoch(
          (seconds * 1000) + (nanoseconds ~/ 1000000),
        );
      }
      // If it's a Map with toDate method (shouldn't happen in JSON, but handle it)
      try {
        if (value.toString().contains('Timestamp')) {
          // Try to extract from string representation
          return DateTime.now();
        }
      } catch (e) {
        // Fall through to string parsing
      }
    }
    
    // If it's a string, try to parse it
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    
    // If it's a number (Unix timestamp in seconds or milliseconds)
    if (value is num) {
      final timestamp = value.toInt();
      // Check if it's in seconds (less than year 2000 in milliseconds)
      if (timestamp < 946684800000) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      } else {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    }
    
    // Default fallback
    return DateTime.now();
  }
}

