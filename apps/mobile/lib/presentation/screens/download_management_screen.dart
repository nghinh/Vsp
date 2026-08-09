// Download Management Screen — VSP Mobile App
//
// Lists all downloaded packages with status, storage usage, and per-package actions.
// Route: /downloads
//
// AC-1, AC-2, AC-3: manage all downloaded courses.
// Design: ux-spec §5.2

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import '../../../data/repositories/course_package_repository.dart';
import '../../../data/repositories/package_manifest_repository.dart';
import '../../../data/services/course_package_download_service.dart';
import '../../../data/services/package_file_downloader.dart';
import '../../../data/services/connectivity_service.dart';
import '../../../domain/models/download_state.dart';
import '../widgets/delete_package_dialog.dart';
import '../widgets/download_action_button.dart';
import '../widgets/offline_ready_badge.dart';
import '../widgets/update_available_badge.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Screen listing all downloaded course packages.
///
/// Shows storage usage, per-package status, update/delete actions.
class DownloadManagementScreen extends StatelessWidget {
  final PackageManifestRepository manifestRepo;
  final CoursePackageRepository packageRepo;

  const DownloadManagementScreen({
    super.key,
    required this.manifestRepo,
    required this.packageRepo,
  });

  @override
  Widget build(BuildContext context) {
    return _DownloadManagementBody(
      manifestRepo: manifestRepo,
      packageRepo: packageRepo,
    );
  }
}

class _DownloadManagementBody extends StatefulWidget {
  final PackageManifestRepository manifestRepo;
  final CoursePackageRepository packageRepo;

  const _DownloadManagementBody({
    required this.manifestRepo,
    required this.packageRepo,
  });

  @override
  State<_DownloadManagementBody> createState() =>
      _DownloadManagementBodyState();
}

class _DownloadManagementBodyState extends State<_DownloadManagementBody> {
  int _totalStorageBytes = 0;
  bool _isLoading = true;
  List<_DownloadedPackage> _packages = [];

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    setState(() => _isLoading = true);

    try {
      // Get all packages from app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final packageBase = Directory('${appDir.path}/packages');
      final packages = <_DownloadedPackage>[];
      int totalBytes = 0;

      if (await packageBase.exists()) {
        final dirs = await packageBase.list().toList();
        for (final dir in dirs) {
          if (dir is Directory) {
            final courseId = int.tryParse(dir.path.split('/').last);
            if (courseId != null) {
              final manifest = await widget.manifestRepo.getActiveManifest(
                courseId,
              );
              if (manifest != null) {
                final dirSize = await _getDirectorySize(dir);
                totalBytes += dirSize;
                packages.add(
                  _DownloadedPackage(
                    courseId: courseId,
                    courseName:
                        'Course $courseId', // Would be resolved from course detail
                    version: manifest.version,
                    sizeBytes: dirSize,
                    effectiveDate: manifest.effectiveDate,
                    updateAvailable: false, // Would check remote manifest
                  ),
                );
              }
            }
          }
        }
      }

      setState(() {
        _packages = packages;
        _totalStorageBytes = totalBytes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<int> _getDirectorySize(Directory dir) async {
    int size = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        size += await entity.length();
      }
    }
    return size;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).downloadOfflineCourses)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _packages.isEmpty
          ? _buildEmptyState(theme)
          : _buildPackageList(theme, colorScheme),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.download_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(AppLocalizations.of(context).downloadNoOfflineCourses, style: theme.textTheme.titleMedium),
          Text(
            'Download a course to play offline',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageList(ThemeData theme, ColorScheme colorScheme) {
    return RefreshIndicator(
      onRefresh: _loadPackages,
      child: ListView(
        padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
        children: [
          // Storage summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.storage, color: colorScheme.primary),
                const SizedBox(width: VspSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Using ${_formatBytes(_totalStorageBytes)} for offline courses',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${_packages.length} course${_packages.length != 1 ? "s" : ""} downloaded',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Package list
          ..._packages.map(
            (pkg) => _PackageListItem(
              package: pkg,
              onDelete: () => _confirmDelete(pkg),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(_DownloadedPackage pkg) async {
    // Was `_getPrefs()`, which threw UnimplementedError — so the only way to
    // delete a downloaded course crashed the screen. The preferences are read
    // here rather than injected: they are what ConnectivityService answers the
    // Wi-Fi-only question from.
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).downloadPreferencesUnavailable,
          ),
        ),
      );
      return;
    }
    if (!mounted) return;

    final connectivity = ConnectivityService(prefs: prefs);
    final downloader = PackageFileDownloader();
    final downloadService = CoursePackageDownloadService(
      manifestRepo: widget.manifestRepo,
      packageRepo: widget.packageRepo,
      downloader: downloader,
      connectivity: connectivity,
    );

    await DeletePackageDialog.show(
      context,
      courseName: pkg.courseName,
      onConfirm: () async {
        await downloadService.deletePackage(pkg.courseId);
        await _loadPackages();
      },
    );

    downloadService.dispose();
    connectivity.dispose();
  }

  String _formatBytes(int bytes) {
    final mb = bytes / (1024 * 1024);
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }
}

class _DownloadedPackage {
  final int courseId;
  final String courseName;
  final String version;
  final int sizeBytes;
  final DateTime effectiveDate;
  final bool updateAvailable;

  const _DownloadedPackage({
    required this.courseId,
    required this.courseName,
    required this.version,
    required this.sizeBytes,
    required this.effectiveDate,
    required this.updateAvailable,
  });
}

class _PackageListItem extends StatelessWidget {
  final _DownloadedPackage package;
  final VoidCallback onDelete;

  const _PackageListItem({required this.package, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: VspSpacing.sm),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Course icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.golf_course,
                  color: colorScheme.primary,
                  size: VspIconSize.md,
                ),
              ),
              const SizedBox(width: VspSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.courseName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Text(
                          'v${package.version}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: VspSpacing.xs),
                        Text(
                          '·',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: VspSpacing.xs),
                        Text(
                          _formatBytes(package.sizeBytes),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (package.updateAvailable)
                const UpdateAvailableBadge(compact: true)
              else
                const OfflineReadyBadge(compact: true),
            ],
          ),
          const SizedBox(height: VspSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text(AppLocalizations.of(context).commonRemove),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VspColorSemantic.of(
                      colorScheme.brightness,
                      VspSemanticColorToken.syncFailed,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

