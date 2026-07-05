import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:firebase_auth/firebase_auth.dart';



import '../../config/app_design_system.dart';

import '../../providers/shell_tab_provider.dart';

import '../../providers/priority_provider.dart';

import '../../services/offline_queue.dart';



class HomeScreen extends ConsumerWidget {

  const HomeScreen({super.key, this.embedded = false});



  final bool embedded;



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final user = FirebaseAuth.instance.currentUser;

    final pendingAsync = ref.watch(_pendingCountProvider);

    final clustersAsync = ref.watch(clustersProvider);



    return Scaffold(

      backgroundColor: AppDesignSystem.backgroundColor,

      body: SafeArea(

        child: CustomScrollView(

          slivers: [

            SliverToBoxAdapter(

              child: _HeroHeader(

                name: user?.displayName ?? user?.email?.split('@').first ?? 'Citizen',

                pendingCount: pendingAsync.value ?? 0,

              ),

            ),

            SliverPadding(

              padding: const EdgeInsets.all(20),

              sliver: SliverList(

                delegate: SliverChildListDelegate([

                  _ActionCard(

                    gradient: const LinearGradient(

                      colors: [AppDesignSystem.accentColor, AppDesignSystem.accentLight],

                    ),

                    icon: Icons.mic_rounded,

                    title: 'Record your priority',

                    subtitle: 'Speak in Telugu, Hindi, or English — we understand all three',

                    onTap: () => context.push('/submit'),

                  ),

                  const SizedBox(height: 14),

                  Row(

                    children: [

                      Expanded(

                        child: _QuickTile(

                          icon: Icons.format_list_numbered,

                          label: 'View rankings',

                          onTap: () => ref.read(shellTabProvider.notifier).state = 1,

                        ),

                      ),

                      const SizedBox(width: 12),

                      Expanded(

                        child: _QuickTile(

                          icon: Icons.map_outlined,

                          label: 'Hotspot map',

                          onTap: () => ref.read(shellTabProvider.notifier).state = 2,

                        ),

                      ),

                    ],

                  ),

                  const SizedBox(height: 24),

                  Text('Top community demand', style: AppDesignSystem.heading4),

                  const SizedBox(height: 4),

                  Text(

                    'What your neighbours are asking for most',

                    style: AppDesignSystem.bodySmall,

                  ),

                  const SizedBox(height: 12),

                  clustersAsync.when(

                    loading: () => const Center(child: Padding(

                      padding: EdgeInsets.all(24),

                      child: CircularProgressIndicator(),

                    )),

                    error: (_, __) => const SizedBox.shrink(),

                    data: (clusters) {

                      if (clusters.isEmpty) {

                        return Text(

                          'No priorities yet — be the first voice.',

                          style: AppDesignSystem.bodyMedium.copyWith(

                            color: AppDesignSystem.textSecondary,

                          ),

                        );

                      }

                      final top = clusters.first;

                      return Container(

                        padding: const EdgeInsets.all(16),

                        decoration: BoxDecoration(

                          color: Colors.white,

                          borderRadius: BorderRadius.circular(16),

                          border: Border.all(color: AppDesignSystem.borderColor),

                        ),

                        child: Row(

                          children: [

                            Container(

                              width: 44,

                              height: 44,

                              decoration: BoxDecoration(

                                color: AppDesignSystem.primaryColor.withValues(alpha: 0.1),

                                shape: BoxShape.circle,

                              ),

                              alignment: Alignment.center,

                              child: Text(

                                '#1',

                                style: AppDesignSystem.labelLarge.copyWith(

                                  color: AppDesignSystem.primaryColor,

                                ),

                              ),

                            ),

                            const SizedBox(width: 12),

                            Expanded(

                              child: Column(

                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [

                                  Text(

                                    top.canonicalTitleEn,

                                    maxLines: 2,

                                    overflow: TextOverflow.ellipsis,

                                    style: AppDesignSystem.bodyMedium.copyWith(

                                      fontWeight: FontWeight.w600,

                                    ),

                                  ),

                                  const SizedBox(height: 4),

                                  Text(

                                    '${top.uniqueCitizens} citizens · score ${top.totalScore.toStringAsFixed(0)}',

                                    style: AppDesignSystem.bodySmall,

                                  ),

                                ],

                              ),

                            ),

                            Icon(Icons.chevron_right, color: AppDesignSystem.textTertiary),

                          ],

                        ),

                      );

                    },

                  ),

                  const SizedBox(height: 24),

                  _TrustBanner(),

                ]),

              ),

            ),

          ],

        ),

      ),

    );

  }

}



final _pendingCountProvider = FutureProvider.autoDispose<int>((ref) async {

  return OfflineQueue.instance.pendingCount();

});



class _HeroHeader extends StatelessWidget {

  const _HeroHeader({required this.name, required this.pendingCount});



  final String name;

  final int pendingCount;



  @override

  Widget build(BuildContext context) {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),

      decoration: const BoxDecoration(

        gradient: LinearGradient(

          begin: Alignment.topLeft,

          end: Alignment.bottomRight,

          colors: [AppDesignSystem.heroGradientStart, AppDesignSystem.heroGradientEnd],

        ),

        borderRadius: BorderRadius.only(

          bottomLeft: Radius.circular(28),

          bottomRight: Radius.circular(28),

        ),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(

            'నమస్కారం, $name',

            style: AppDesignSystem.heading3.copyWith(color: Colors.white),

          ),

          const SizedBox(height: 6),

          Text(

            'Your voice shapes the works list',

            style: AppDesignSystem.bodyMedium.copyWith(color: Colors.white70),

          ),

          if (pendingCount > 0) ...[

            const SizedBox(height: 12),

            Container(

              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

              decoration: BoxDecoration(

                color: Colors.white.withValues(alpha: 0.15),

                borderRadius: BorderRadius.circular(10),

              ),

              child: Row(

                mainAxisSize: MainAxisSize.min,

                children: [

                  const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 18),

                  const SizedBox(width: 8),

                  Text(

                    '$pendingCount request${pendingCount == 1 ? '' : 's'} queued — will send when online',

                    style: const TextStyle(color: Colors.white, fontSize: 12),

                  ),

                ],

              ),

            ),

          ],

        ],

      ),

    );

  }

}



class _ActionCard extends StatelessWidget {

  const _ActionCard({

    required this.gradient,

    required this.icon,

    required this.title,

    required this.subtitle,

    required this.onTap,

  });



  final Gradient gradient;

  final IconData icon;

  final String title;

  final String subtitle;

  final VoidCallback onTap;



  @override

  Widget build(BuildContext context) {

    return Material(

      color: Colors.transparent,

      child: InkWell(

        onTap: onTap,

        borderRadius: BorderRadius.circular(20),

        child: Ink(

          decoration: BoxDecoration(

            gradient: gradient,

            borderRadius: BorderRadius.circular(20),

            boxShadow: AppDesignSystem.shadowMedium,

          ),

          padding: const EdgeInsets.all(20),

          child: Row(

            children: [

              Container(

                padding: const EdgeInsets.all(14),

                decoration: BoxDecoration(

                  color: Colors.white.withValues(alpha: 0.2),

                  shape: BoxShape.circle,

                ),

                child: Icon(icon, color: Colors.white, size: 32),

              ),

              const SizedBox(width: 16),

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(title, style: AppDesignSystem.heading4.copyWith(color: Colors.white)),

                    const SizedBox(height: 4),

                    Text(subtitle, style: AppDesignSystem.bodySmall.copyWith(color: Colors.white70)),

                  ],

                ),

              ),

              const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),

            ],

          ),

        ),

      ),

    );

  }

}



class _QuickTile extends StatelessWidget {

  const _QuickTile({required this.icon, required this.label, required this.onTap});



  final IconData icon;

  final String label;

  final VoidCallback onTap;



  @override

  Widget build(BuildContext context) {

    return Material(

      color: Colors.white,

      borderRadius: BorderRadius.circular(14),

      child: InkWell(

        onTap: onTap,

        borderRadius: BorderRadius.circular(14),

        child: Container(

          padding: const EdgeInsets.symmetric(vertical: 18),

          decoration: BoxDecoration(

            borderRadius: BorderRadius.circular(14),

            border: Border.all(color: AppDesignSystem.borderColor),

          ),

          child: Column(

            children: [

              Icon(icon, color: AppDesignSystem.primaryColor),

              const SizedBox(height: 6),

              Text(label, style: AppDesignSystem.labelMedium),

            ],

          ),

        ),

      ),

    );

  }

}



class _TrustBanner extends StatelessWidget {

  @override

  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(

        color: AppDesignSystem.secondaryColor.withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: AppDesignSystem.secondaryColor.withValues(alpha: 0.2)),

      ),

      child: Row(

        children: [

          Icon(Icons.shield_outlined, color: AppDesignSystem.secondaryColor),

          const SizedBox(width: 12),

          Expanded(

            child: Text(

              'Every rank shows its sources and figures. Simulated portal data is always labelled.',

              style: AppDesignSystem.bodySmall.copyWith(color: AppDesignSystem.primaryColor),

            ),

          ),

        ],

      ),

    );

  }

}

