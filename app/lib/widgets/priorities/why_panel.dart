import 'package:flutter/material.dart';

import '../../config/app_design_system.dart';
import '../../models/priority_models.dart';

/// The "why is this ranked here?" panel (§3c).
class WhyPanel extends StatelessWidget {
  final PriorityCluster cluster;

  const WhyPanel({super.key, required this.cluster});

  @override
  Widget build(BuildContext context) {
    final text = cluster.justificationText;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppDesignSystem.primaryColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppDesignSystem.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: AppDesignSystem.accentColor),
              const SizedBox(width: 8),
              Text('Why this rank', style: AppDesignSystem.labelLarge),
            ],
          ),
          const SizedBox(height: 10),
          if (text != null && text.isNotEmpty)
            Text(text, style: AppDesignSystem.bodyMedium.copyWith(height: 1.5))
          else
            Text(
              'Scoring in progress — run the score pass to generate the explanation.',
              style: AppDesignSystem.bodySmall.copyWith(color: AppDesignSystem.textTertiary),
            ),
          if (cluster.evidenceBullets.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Evidence figures', style: AppDesignSystem.labelMedium),
            const SizedBox(height: 6),
            ...cluster.evidenceBullets.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline, size: 14, color: AppDesignSystem.scoreEvidence),
                    const SizedBox(width: 6),
                    Expanded(child: Text(b, style: AppDesignSystem.bodySmall)),
                  ],
                ),
              ),
            ),
          ] else if (!cluster.evidenceAvailable) ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.info_outline,
              text: 'No public-dataset evidence for this category yet — rank reflects demand, source quality and recency.',
            ),
          ],
          const SizedBox(height: 14),
          Text('Channel mix', style: AppDesignSystem.labelMedium),
          const SizedBox(height: 8),
          _ChannelBar(sources: cluster.sources),
          if (cluster.languages.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: cluster.languages
                  .map((l) => Chip(
                        avatar: const Icon(Icons.translate, size: 14),
                        label: Text(l.toUpperCase()),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ],
          if (cluster.caveats.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Caveats', style: AppDesignSystem.labelMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: cluster.caveats
                  .map((c) => Chip(
                        avatar: Icon(Icons.flag_outlined, size: 14, color: AppDesignSystem.warningColor),
                        label: Text(c.replaceAll('_', ' ')),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChannelBar extends StatelessWidget {
  const _ChannelBar({required this.sources});

  final Map<String, int> sources;

  @override
  Widget build(BuildContext context) {
    final total = sources.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return Text('No source data', style: AppDesignSystem.bodySmall);

    const colors = [
      AppDesignSystem.scoreDemand,
      AppDesignSystem.secondaryColor,
      AppDesignSystem.accentColor,
      AppDesignSystem.scoreEvidence,
      AppDesignSystem.warningColor,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: sources.entries.toList().asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                return Expanded(
                  flex: e.value,
                  child: Container(color: colors[i % colors.length]),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: sources.entries.toList().asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors[i % colors.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text('${_label(e.key)}: ${e.value}', style: AppDesignSystem.labelSmall),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  String _label(String source) {
    switch (source) {
      case 'app':
        return 'App';
      case 'whatsapp':
        return 'WhatsApp';
      case 'youtube':
        return 'YouTube';
      case 'meeting':
        return 'Meeting';
      case 'portal_mock':
        return 'Portal (sim)';
      case 'meta_mock':
        return 'Social (sim)';
      default:
        return source;
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppDesignSystem.textTertiary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppDesignSystem.bodySmall)),
      ],
    );
  }
}
