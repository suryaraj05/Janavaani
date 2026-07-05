class AIAnalysis {
  final bool isProblemRelated;
  final String suggestedTitle;
  final String suggestedDescription;
  final List<String> suggestedDepartments;
  final String suggestedPriority;
  final String? suggestedLocation;
  final double confidence;
  final String reasoning;

  AIAnalysis({
    required this.isProblemRelated,
    required this.suggestedTitle,
    required this.suggestedDescription,
    required this.suggestedDepartments,
    required this.suggestedPriority,
    this.suggestedLocation,
    required this.confidence,
    required this.reasoning,
  });

  factory AIAnalysis.fromJson(Map<String, dynamic> json) {
    return AIAnalysis(
      isProblemRelated: json['isProblemRelated'] ?? true,
      suggestedTitle: json['suggestedTitle'] ?? '',
      suggestedDescription: json['suggestedDescription'] ?? '',
      suggestedDepartments: List<String>.from(json['suggestedDepartments'] ?? []),
      suggestedPriority: json['suggestedPriority'] ?? 'medium',
      suggestedLocation: json['suggestedLocation'],
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      reasoning: json['reasoning'] ?? '',
    );
  }
}

