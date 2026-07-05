import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/priority_models.dart';
import '../services/api_service.dart';
import '../services/offline_queue.dart';

final clustersProvider = FutureProvider.autoDispose<List<PriorityCluster>>((ref) async {
  // Opportunistically flush any offline-queued submissions before refreshing.
  await OfflineQueue.instance.flush();
  final response = await ApiService().getClusters();
  final list = (response.data['clusters'] as List? ?? [])
      .map((e) => PriorityCluster.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  list.sort((a, b) => b.totalScore.compareTo(a.totalScore));
  return list;
});

final submissionsProvider = FutureProvider.autoDispose<List<CitizenSubmission>>((ref) async {
  final response = await ApiService().getSubmissions();
  return (response.data['submissions'] as List? ?? [])
      .map((e) => CitizenSubmission.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});
