import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../config/app_design_system.dart';
import '../../models/priority_models.dart';
import '../../providers/priority_provider.dart';
import '../../widgets/priorities/why_panel.dart';
import '../../widgets/pp/score_ring.dart';

class HotspotMapScreen extends ConsumerWidget {
  const HotspotMapScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clustersAsync = ref.watch(clustersProvider);

    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundColor,
      appBar: embedded
          ? AppBar(
              title: const Text('Priority Hotspots'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(clustersProvider),
                ),
              ],
            )
          : AppBar(title: const Text('Priority Hotspots')),
      body: clustersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (clusters) {
          final located = clusters.where((c) => c.centroidPoint != null).toList();
          if (located.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, size: 48, color: AppDesignSystem.textTertiary),
                  const SizedBox(height: 12),
                  Text('No geolocated demands yet', style: AppDesignSystem.heading4),
                ],
              ),
            );
          }

          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(initialCenter: _center(located), initialZoom: 11.5),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.peoplespriorities.app',
                  ),
                  CircleLayer(circles: located.map(_circle).toList()),
                  MarkerLayer(markers: located.asMap().entries.map((e) => _marker(context, e.value, e.key + 1)).toList()),
                ],
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: embedded ? 88 : 16,
                child: _MapLegend(),
              ),
            ],
          );
        },
      ),
    );
  }

  LatLng _center(List<PriorityCluster> clusters) {
    double lat = 0, lng = 0;
    for (final c in clusters) {
      lat += (c.centroidPoint!['lat'] as num).toDouble();
      lng += (c.centroidPoint!['lng'] as num).toDouble();
    }
    return LatLng(lat / clusters.length, lng / clusters.length);
  }

  Color _scoreColor(double score) {
    if (score >= 80) return AppDesignSystem.accentColor;
    if (score >= 60) return AppDesignSystem.primaryLight;
    return AppDesignSystem.secondaryColor;
  }

  CircleMarker _circle(PriorityCluster c) {
    final point = LatLng(
      (c.centroidPoint!['lat'] as num).toDouble(),
      (c.centroidPoint!['lng'] as num).toDouble(),
    );
    final color = _scoreColor(c.totalScore);
    return CircleMarker(
      point: point,
      color: color.withValues(alpha: 0.2),
      borderColor: color.withValues(alpha: 0.6),
      borderStrokeWidth: 2,
      useRadiusInMeter: true,
      radius: 250 + c.totalScore * 15,
    );
  }

  Marker _marker(BuildContext context, PriorityCluster c, int rank) {
    final point = LatLng(
      (c.centroidPoint!['lat'] as num).toDouble(),
      (c.centroidPoint!['lng'] as num).toDouble(),
    );
    final color = _scoreColor(c.totalScore);
    return Marker(
      point: point,
      width: 48,
      height: 48,
      child: GestureDetector(
        onTap: () => _showDetail(context, c, rank),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: AppDesignSystem.shadowSmall,
          ),
          alignment: Alignment.center,
          child: Text(
            '$rank',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, PriorityCluster c, int rank) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppDesignSystem.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.45,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ScoreRing(score: c.totalScore, rank: rank, size: 64),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(c.canonicalTitleEn, style: AppDesignSystem.heading4),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${c.category} · ${c.uniqueCitizens} citizens · ${c.subcategory.replaceAll('_', ' ')}',
                style: AppDesignSystem.bodySmall,
              ),
              const SizedBox(height: 16),
              WhyPanel(cluster: c),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppDesignSystem.shadowMedium,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _LegendDot(color: AppDesignSystem.accentColor, label: 'High (80+)'),
          _LegendDot(color: AppDesignSystem.primaryLight, label: 'Medium'),
          _LegendDot(color: AppDesignSystem.secondaryColor, label: 'Lower'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppDesignSystem.labelSmall),
      ],
    );
  }
}
