import 'package:flutter_test/flutter_test.dart';
import 'package:peoples_priorities/models/priority_models.dart';

void main() {
  test('PriorityCluster parses score and stats from JSON', () {
    final cluster = PriorityCluster.fromJson({
      'cluster_id': 'clu_edu_001',
      'canonical_title_en': 'Secondary school access',
      'category': 'education',
      'subcategory': 'school_upgrade',
      'stats': {'unique_citizens': 12, 'simulated_count': 2, 'sources': {'app': 8}},
      'score': {
        'total': 84.1,
        'demand': 0.86,
        'evidence': 0.88,
        'confidence': 0.64,
        'recency': 0.98,
        'evidence_available': true,
      },
      'lifecycle': {'status': 'acknowledged'},
    });

    expect(cluster.totalScore, closeTo(84.1, 0.01));
    expect(cluster.uniqueCitizens, 12);
    expect(cluster.evidenceAvailable, isTrue);
    expect(cluster.mostlySimulated, isFalse);
  });
}
