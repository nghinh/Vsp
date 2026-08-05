// Contact Section — VSP Mobile App
//
// Contact info: phone (tap to call), website (tap to open), address.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../domain/models/course_detail.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class ContactSection extends StatelessWidget {
  final CourseDetail course;

  const ContactSection({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    if (!course.hasContact) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _SectionContainer(
      title: AppLocalizations.of(context).sectionContact,
      icon: Icons.phone,
      children: [
        if (course.phone != null)
          _ContactTile(
            icon: Icons.phone,
            label: AppLocalizations.of(context).fieldPhone,
            value: course.phone!,
            onTap: () => _launchUrl('tel:${course.phone}'),
          ),
        if (course.website != null)
          _ContactTile(
            icon: Icons.language,
            label: AppLocalizations.of(context).fieldWebsite,
            value: course.website!,
            onTap: () => _launchUrl(course.website!),
          ),
        if (course.address != null)
          _ContactTile(
            icon: Icons.location_on,
            label: AppLocalizations.of(context).fieldAddress,
            value: course.address!,
            onTap: null,
          ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _SectionContainer extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionContainer({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VspSpacing.md,
        vertical: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: VspIconSize.md, color: colorScheme.primary),
              const SizedBox(width: VspSpacing.sm),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _ContactTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isInteractive = onTap != null;

    return Semantics(
      label: '$label: $value${isInteractive ? ', tap to open' : ''}',
      button: isInteractive,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: VspSpacing.sm,
            horizontal: VspSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: VspIconSize.md,
                color: isInteractive
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isInteractive
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        decoration: isInteractive
                            ? TextDecoration.underline
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (isInteractive)
                Icon(
                  Icons.open_in_new,
                  size: VspIconSize.sm,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
