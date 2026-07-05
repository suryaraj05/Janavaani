import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_design_system.dart';
import '../../models/priority_models.dart';
import '../../providers/priority_provider.dart';
import '../../widgets/design_system/app_empty_state.dart';
import '../../widgets/pp/cluster_rank_card.dart';
import '../../widgets/pp/dashboard_stats_header.dart';

class PrioritiesDashboardScreen extends ConsumerStatefulWidget {
  const PrioritiesDashboardScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<PrioritiesDashboardScreen> createState() =>
      _PrioritiesDashboardScreenState();
}

class _PrioritiesDashboardScreenState extends ConsumerState<PrioritiesDashboardScreen> {
  String? _categoryFilter;

  List<PriorityCluster> _filter(List<PriorityCluster> clusters) {
    if (_categoryFilter == null) return clusters;
    return clusters.where((c) => c.category == _categoryFilter).toList();
  }

  Set<String> _categories(List<PriorityCluster> clusters) =>
      clusters.map((c) => c.category).toSet();

  @override
  Widget build(BuildContext context) {
    final clustersAsync = ref.watch(clustersProvider);

    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundColor,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("People's Priorities"),
                  Text(
                    'Ranked development demands',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.map_outlined),
                  onPressed: () => context.push('/hotspots'),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(clustersProvider),
                ),
              ],
            ),
      body: clustersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, size: 48, color: AppDesignSystem.textTertiary),
                const SizedBox(height: 12),
                Text('Could not load priorities', style: AppDesignSystem.heading4),
                const SizedBox(height: 8),
                Text('$e', textAlign: TextAlign.center, style: AppDesignSystem.bodySmall),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(clustersProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (clusters) {
          if (clusters.isEmpty) {
            return AppEmptyState(
              icon: Icons.campaign_outlined,
              title: 'No demands yet',
              message: 'Be the first to share what your area needs.',
              actionLabel: 'Record voice request',
              onAction: () => context.push('/submit'),
            );
          }

          final filtered = _filter(clusters);
          final cats = _categories(clusters).toList()..sort();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(clustersProvider),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: DashboardStatsHeader(clusters: clusters)),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: const Text('All'),
                            selected: _categoryFilter == null,
                            onSelected: (_) => setState(() => _categoryFilter = null),
                          ),
                        ),
                        ...cats.map(
                          (cat) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(cat.replaceAll('_', ' ')),
                              selected: _categoryFilter == cat,
                              onSelected: (_) => setState(() => _categoryFilter = cat),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => ClusterRankCard(
                      cluster: filtered[index],
                      rank: clusters.indexOf(filtered[index]) + 1,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: widget.embedded
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/submit'),
              backgroundColor: AppDesignSystem.accentColor,
              icon: const Icon(Icons.mic),
              label: const Text('Voice request'),
            ),
    );
  }
}
