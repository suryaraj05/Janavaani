import 'package:flutter/material.dart';
import '../../config/app_design_system.dart';
import '../../widgets/design_system/app_card.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDesignSystem.spacingL),
        children: [
          // Header
          Text(
            'How can we help you?',
            style: AppDesignSystem.heading2.copyWith(
              color: AppDesignSystem.textPrimary,
            ),
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          Text(
            'Find answers to common questions and get support',
            style: AppDesignSystem.bodyMedium.copyWith(
              color: AppDesignSystem.textSecondary,
            ),
          ),
          const SizedBox(height: AppDesignSystem.spacingXL),

          // FAQ Section
          _buildSection(
            context,
            title: 'Frequently Asked Questions',
            icon: Icons.help_outline,
            children: [
              _buildFAQItem(
                context,
                question: 'How do I submit a grievance?',
                answer: 'Tap the + button on the home screen, fill in the details, add photos if available, and submit. You can also use AI to auto-fill the form.',
              ),
              _buildFAQItem(
                context,
                question: 'How do I track my grievance status?',
                answer: 'Go to "My Issues" tab to see all your submitted grievances and their current status.',
              ),
              _buildFAQItem(
                context,
                question: 'What should I do if my grievance is rejected?',
                answer: 'Review the rejection reason. You can submit a new grievance with more details or contact support for assistance.',
              ),
              _buildFAQItem(
                context,
                question: 'How do I upvote a grievance?',
                answer: 'Tap the upvote button on any grievance card in the feed. This helps prioritize important issues.',
              ),
            ],
          ),
          const SizedBox(height: AppDesignSystem.spacingL),

          // Contact Section
          _buildSection(
            context,
            title: 'Contact Support',
            icon: Icons.support_agent,
            children: [
              AppCard(
                child: ListTile(
                  leading: const Icon(Icons.email, color: AppDesignSystem.primaryColor),
                  title: Text(
                    'Email Support',
                    style: AppDesignSystem.bodyMedium.copyWith(
                      color: AppDesignSystem.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'support@campusconnect.com',
                    style: AppDesignSystem.bodySmall.copyWith(
                      color: AppDesignSystem.textSecondary,
                    ),
                  ),
                  onTap: () {
                    // TODO: Open email client
                  },
                ),
              ),
              const SizedBox(height: AppDesignSystem.spacingS),
              AppCard(
                child: ListTile(
                  leading: const Icon(Icons.phone, color: AppDesignSystem.primaryColor),
                  title: Text(
                    'Phone Support',
                    style: AppDesignSystem.bodyMedium.copyWith(
                      color: AppDesignSystem.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '+1 (555) 123-4567',
                    style: AppDesignSystem.bodySmall.copyWith(
                      color: AppDesignSystem.textSecondary,
                    ),
                  ),
                  onTap: () {
                    // TODO: Open phone dialer
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignSystem.spacingL),

          // Tips Section
          _buildSection(
            context,
            title: 'Tips for Better Results',
            icon: Icons.lightbulb_outline,
            children: [
              _buildTipItem(
                context,
                icon: Icons.camera_alt,
                tip: 'Add clear photos of the issue',
              ),
              _buildTipItem(
                context,
                icon: Icons.location_on,
                tip: 'Provide accurate location details',
              ),
              _buildTipItem(
                context,
                icon: Icons.description,
                tip: 'Write detailed descriptions',
              ),
              _buildTipItem(
                context,
                icon: Icons.priority_high,
                tip: 'Select appropriate priority level',
              ),
            ],
          ),
          const SizedBox(height: AppDesignSystem.spacingXL),

          // App Version
          Center(
            child: Text(
              'Campus Connect v1.0.0',
              style: AppDesignSystem.bodySmall.copyWith(
                color: AppDesignSystem.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: AppDesignSystem.spacingL),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppDesignSystem.primaryColor),
            const SizedBox(width: AppDesignSystem.spacingS),
            Text(
              title,
              style: AppDesignSystem.heading3.copyWith(
                color: AppDesignSystem.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDesignSystem.spacingM),
        ...children,
      ],
    );
  }

  Widget _buildFAQItem(
    BuildContext context, {
    required String question,
    required String answer,
  }) {
    return Card(
      color: AppDesignSystem.cardColor,
      child: ExpansionTile(
        title: Text(
          question,
          style: AppDesignSystem.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppDesignSystem.textPrimary,
          ),
        ),
        iconColor: AppDesignSystem.primaryColor,
        collapsedIconColor: AppDesignSystem.textSecondary,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
            child: Text(
              answer,
              style: AppDesignSystem.bodySmall.copyWith(
                color: AppDesignSystem.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(
    BuildContext context, {
    required IconData icon,
    required String tip,
  }) {
    return AppCard(
      child: ListTile(
        leading: Icon(icon, color: AppDesignSystem.secondaryColor),
        title: Text(
          tip,
          style: AppDesignSystem.bodyMedium.copyWith(
            color: AppDesignSystem.textPrimary,
          ),
        ),
      ),
    );
  }
}

