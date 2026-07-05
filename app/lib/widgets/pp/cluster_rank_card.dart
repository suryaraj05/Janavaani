import 'package:flutter/material.dart';

import '../../config/app_design_system.dart';
import '../../models/priority_models.dart';
import '../priorities/why_panel.dart';
import 'score_ring.dart';

class ClusterRankCard extends StatefulWidget {
  const ClusterRankCard({
    super.key,
    required this.cluster,
    required this.rank,
  });

  final PriorityCluster cluster;
  final int rank;

  @override
  State<ClusterRankCard> createState() => _ClusterRankCardState();
}

class _ClusterRankCardState extends State<ClusterRankCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.cluster;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppDesignSystem.surfaceColor,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        border: Border.all(color: AppDesignSystem.borderColor),
        boxShadow: AppDesignSystem.shadowSmall,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ScoreRing(score: c.totalScore, rank: widget.rank),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.canonicalTitleEn,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _MiniChip(
                                icon: Icons.category_outlined,
                                label: _categoryLabel(c.category),
                              ),
                              _MiniChip(
                                icon: Icons.people_outline,
                                label: '${c.uniqueCitizens} citizens',
                              ),
                              if (c.mostlySimulated)
                                const _StatusBadge(
                                  label: 'SIMULATED',
                                  color: AppDesignSystem.warningColor,
                                  icon: Icons.science_outlined,
                                ),
                              if (c.hasAnomaly)
                                _StatusBadge(
                                  label: c.anomalyFlags.first.replaceAll('_', ' ').toUpperCase(),
                                  color: AppDesignSystem.errorColor,
                                  icon: Icons.warning_amber_rounded,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppDesignSystem.textTertiary,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ScoreRow(label: 'Evidence', value: c.evidence, color: AppDesignSystem.scoreEvidence),
                const SizedBox(height: 6),
                _ScoreRow(label: 'Demand', value: c.demand, color: AppDesignSystem.scoreDemand),
                const SizedBox(height: 6),
                _ScoreRow(label: 'Confidence', value: c.confidence, color: AppDesignSystem.scoreConfidence),
                const SizedBox(height: 6),
                _ScoreRow(label: 'Recency', value: c.recency, color: AppDesignSystem.scoreRecency),
                if (_expanded) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  WhyPanel(cluster: c),
                ] else if (c.justificationText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    c.justificationText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppDesignSystem.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _categoryLabel(String cat) {
    return cat.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(label, style: AppDesignSystem.labelSmall),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value.clamp(0, 1),
              minHeight: 7,
              backgroundColor: color.withValues(alpha: 0.12),
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            '${(value * 100).round()}',
            textAlign: TextAlign.right,
            style: AppDesignSystem.labelMedium.copyWith(fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppDesignSystem.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppDesignSystem.primaryColor),
          const SizedBox(width: 4),
          Text(label, style: AppDesignSystem.labelSmall.copyWith(color: AppDesignSystem.primaryColor)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color, required this.icon});

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
