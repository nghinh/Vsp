// Watch Pairing Screen — VSP Mobile App
//
// Screen for pairing Apple Watch with mobile app.
// Handles watch package download and management.
//
// Story 10.1 — Slice 4: Offline Course Subset

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Watch pairing screen for managing Apple Watch connection.
class WatchPairingScreen extends StatelessWidget {
  final VoidCallback? onPairWatch;
  final VoidCallback? onDownloadPackage;
  final VoidCallback? onSyncPackages;
  final VoidCallback? onCancel;
  final String? pairedWatchName;
  final String? syncStatus;
  final bool isDownloading;
  final double? downloadProgress;

  const WatchPairingScreen({
    super.key,
    this.onPairWatch,
    this.onDownloadPackage,
    this.onSyncPackages,
    this.onCancel,
    this.pairedWatchName,
    this.syncStatus,
    this.isDownloading = false,
    this.downloadProgress,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(AppLocalizations.of(context).watchAppleWatch),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onCancel,
          child: Text(AppLocalizations.of(context).commonDone),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 20),

            // Watch status section
            _SectionHeader(title: AppLocalizations.of(context).watchStatus),

            if (pairedWatchName != null)
              _WatchStatusTile(
                name: pairedWatchName!,
                status: syncStatus ?? 'Connected',
                isConnected: true,
              )
            else
              _NoWatchPairedTile(onPair: onPairWatch),

            const SizedBox(height: 20),

            // Course packages section
            _SectionHeader(title: AppLocalizations.of(context).watchCoursePackages),

            _PackageManagementTile(
              title: AppLocalizations.of(context).watchDownloadPackages,
              subtitle: AppLocalizations.of(context).watchDownloadPackagesSubtitle,
              onTap: isDownloading ? null : onDownloadPackage,
              trailing: isDownloading
                  ? _DownloadProgressIndicator(progress: downloadProgress)
                  : const Icon(CupertinoIcons.cloud_download),
            ),

            _PackageManagementTile(
              title: AppLocalizations.of(context).watchSync,
              subtitle: AppLocalizations.of(context).watchSyncSubtitle,
              onTap: pairedWatchName != null ? onSyncPackages : null,
              trailing: const Icon(CupertinoIcons.arrow_right_arrow_left),
            ),

            const SizedBox(height: 20),

            // Info section
            _InfoSection(),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _WatchStatusTile extends StatelessWidget {
  final String name;
  final String status;
  final bool isConnected;

  const _WatchStatusTile({
    required this.name,
    required this.status,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isConnected
                  ? CupertinoColors.activeGreen.withOpacity(0.15)
                  : CupertinoColors.systemGrey.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              CupertinoIcons.device_phone_portrait,
              color: isConnected
                  ? CupertinoColors.activeGreen
                  : CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isConnected
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.circle,
            color: isConnected
                ? CupertinoColors.activeGreen
                : CupertinoColors.systemGrey,
          ),
        ],
      ),
    );
  }
}

class _NoWatchPairedTile extends StatelessWidget {
  final VoidCallback? onPair;

  const _NoWatchPairedTile({this.onPair});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPair,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: CupertinoColors.systemGrey4.resolveFrom(context),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey5.resolveFrom(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                CupertinoIcons.plus_circle,
                color: CupertinoColors.activeBlue.resolveFrom(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pair Apple Watch',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: CupertinoColors.activeBlue.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(context).watchTapToPair,
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: CupertinoColors.systemGrey3.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackageManagementTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _PackageManagementTile({
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _DownloadProgressIndicator extends StatelessWidget {
  final double? progress;

  const _DownloadProgressIndicator({this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: progress != null
          ? CircularProgressIndicator(value: progress, strokeWidth: 2)
          : const CupertinoActivityIndicator(),
    );
  }
}

class _InfoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.info_circle,
                size: 16,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              const SizedBox(width: 6),
              Text(
                'About Watch Packages',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Watch packages contain optimized course data for your Apple Watch, '
            'including hole distances and GPS coordinates. Packages are stored '
            'directly on your watch for offline use during rounds.',
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}
