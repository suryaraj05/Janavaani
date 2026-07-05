class PriorityCluster {
  final String clusterId;
  final String canonicalTitleEn;
  final String category;
  final String subcategory;
  final Map<String, dynamic> stats;
  final Map<String, dynamic> score;
  final Map<String, dynamic> lifecycle;
  final Map<String, dynamic>? justification;
  final List<String> anomalyFlags;
  final Map<String, dynamic>? adminScope;
  final Map<String, dynamic>? centroidPoint;

  PriorityCluster({
    required this.clusterId,
    required this.canonicalTitleEn,
    required this.category,
    required this.subcategory,
    required this.stats,
    required this.score,
    required this.lifecycle,
    this.justification,
    this.anomalyFlags = const [],
    this.adminScope,
    this.centroidPoint,
  });

  factory PriorityCluster.fromJson(Map<String, dynamic> json) {
    return PriorityCluster(
      clusterId: json['cluster_id'] as String? ?? '',
      canonicalTitleEn: json['canonical_title_en'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      subcategory: json['subcategory'] as String? ?? '',
      stats: Map<String, dynamic>.from(json['stats'] as Map? ?? {}),
      score: Map<String, dynamic>.from(json['score'] as Map? ?? {}),
      lifecycle: Map<String, dynamic>.from(json['lifecycle'] as Map? ?? {}),
      justification: json['justification'] != null
          ? Map<String, dynamic>.from(json['justification'] as Map)
          : null,
      anomalyFlags: (json['anomaly_flags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      adminScope: json['admin_scope'] != null
          ? Map<String, dynamic>.from(json['admin_scope'] as Map)
          : null,
      centroidPoint: json['centroid_point'] != null
          ? Map<String, dynamic>.from(json['centroid_point'] as Map)
          : null,
    );
  }

  double get totalScore => (score['total'] as num?)?.toDouble() ?? 0;
  double get demand => (score['demand'] as num?)?.toDouble() ?? 0;
  double get evidence => (score['evidence'] as num?)?.toDouble() ?? 0;
  double get confidence => (score['confidence'] as num?)?.toDouble() ?? 0;
  double get recency => (score['recency'] as num?)?.toDouble() ?? 0;
  bool get evidenceAvailable => score['evidence_available'] as bool? ?? false;
  int get uniqueCitizens => (stats['unique_citizens'] as num?)?.toInt() ?? 0;
  int get simulatedCount => (stats['simulated_count'] as num?)?.toInt() ?? 0;
  String get status => lifecycle['status'] as String? ?? 'acknowledged';

  Map<String, int> get sources {
    final raw = stats['sources'] as Map? ?? {};
    return raw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
  }

  List<String> get languages =>
      (stats['languages'] as List?)?.map((e) => e.toString()).toList() ?? const [];

  bool get hasAnomaly => anomalyFlags.isNotEmpty;

  /// True when simulated (portal/meta) sources are the majority — surfaced as a
  /// SIMULATED badge so the mock provenance is never hidden.
  bool get mostlySimulated => uniqueCitizens > 0 && simulatedCount > uniqueCitizens / 2;

  String? get justificationText => justification?['text_en'] as String?;
  List<String> get evidenceBullets =>
      (justification?['evidence_bullets'] as List?)?.map((e) => e.toString()).toList() ?? const [];
  List<String> get caveats =>
      (justification?['caveats'] as List?)?.map((e) => e.toString()).toList() ?? const [];
}

class CitizenSubmission {
  final String submissionId;
  final String? clusterId;
  final Map<String, dynamic> content;
  final Map<String, dynamic>? ai;
  final Map<String, dynamic> location;
  final String createdAt;

  CitizenSubmission({
    required this.submissionId,
    this.clusterId,
    required this.content,
    this.ai,
    required this.location,
    required this.createdAt,
  });

  factory CitizenSubmission.fromJson(Map<String, dynamic> json) {
    return CitizenSubmission(
      submissionId: json['submission_id'] as String? ?? '',
      clusterId: json['cluster_id'] as String?,
      content: Map<String, dynamic>.from(json['content'] as Map? ?? {}),
      ai: json['ai'] != null ? Map<String, dynamic>.from(json['ai'] as Map) : null,
      location: Map<String, dynamic>.from(json['location'] as Map? ?? {}),
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}
