import 'package:flutter/material.dart';

import '../../config/app_design_system.dart';
import '../../models/priority_models.dart';

class DashboardStatsHeader extends StatelessWidget {
  const DashboardStatsHeader({
    super.key,
    required this.clusters,
    this.constituency = 'Malkajgiri',
  });

  final List<PriorityCluster> clusters;
  final String constituency;

  @override
  Widget build(BuildContext context) {
    final citizens = clusters.fold<int>(0, (s, c) => s + c.uniqueCitizens);
    final top = clusters.isNotEmpty ? clusters.first : null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppDesignSystem.heroGradientStart, AppDesignSystem.heroGradientEnd],
        ),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusXL),
        boxShadow: AppDesignSystem.shadowMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  constituency,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              Icon(Icons.verified_outlined, color: Colors.white.withValues(alpha: 0.7), size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "People's Priorities",
            style: AppDesignSystem.heading2.copyWith(color: Colors.white, fontSize: 22),
          ),
          const SizedBox(height: 4),
          Text(
            'Evidence-backed ranking of what citizens need most',
            style: AppDesignSystem.bodySmall.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatChip(value: '${clusters.length}', label: 'Demands'),
              const SizedBox(width: 12),
              _StatChip(value: '$citizens', label: 'Citizens'),
              const SizedBox(width: 12),
              if (top != null)
                Expanded(
                  child: _StatChip(
                    value: top.totalScore.toStringAsFixed(0),
                    label: 'Top score',
                    highlight: true,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlight
            ? AppDesignSystem.accentColor.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
