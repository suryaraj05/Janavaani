import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_design_system.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppDesignSystem.heroGradientStart, AppDesignSystem.heroGradientEnd],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.record_voice_over, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "People's Priorities",
                        style: AppDesignSystem.heading3.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'Thousands of voices.\nOne defensible list.',
                    style: AppDesignSystem.heading1.copyWith(
                      color: Colors.white,
                      fontSize: 36,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tell us what your area needs — in Telugu, Hindi, or English. '
                    'We rank demands with public data, not just who shouted loudest.',
                    style: AppDesignSystem.bodyLarge.copyWith(color: Colors.white70, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  _FeatureRow(icon: Icons.mic, text: 'Voice-first — speak naturally'),
                  const SizedBox(height: 10),
                  _FeatureRow(icon: Icons.analytics_outlined, text: 'Evidence-backed scoring (E·D·V·R)'),
                  const SizedBox(height: 10),
                  _FeatureRow(icon: Icons.translate, text: 'Multilingual — one system for all languages'),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppDesignSystem.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => context.push('/login'),
                      child: const Text('Sign in', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => context.push('/register'),
                      child: const Text('Create account'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppDesignSystem.accentLight, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14))),
      ],
    );
  }
}
