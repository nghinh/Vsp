// Course Download Screen — VSP Mobile App
//
// Screen for downloading, updating, and managing a course package.
// Shows: package size, version, update time, Wi-Fi preference, progress, retry, completion.
//
// AC-1, AC-2, AC-3 from Story 4.3.
// Route: /courses/{courseId}/download
//
// Design: ux-spec §5.2

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/repositories/course_package_repository.dart';
import '../../../data/repositories/package_manifest_repository.dart';
import '../../../data/services/connectivity_service.dart';
import '../../../data/services/course_package_download_service.dart';
import '../../../data/services/package_file_downloader.dart';
import '../../../domain/models/course_package_manifest.dart';
import '../../../domain/models/download_progress.dart';
import '../../../domain/models/download_state.dart';
import '../widgets/delete_package_dialog.dart';
import '../widgets/download_action_button.dart';
import '../widgets/download_progress_indicator.dart';
import '../widgets/package_info_card.dart';
import '../widgets/wifi_only_toggle.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Screen for managing course package download/update/delete.
class CourseDownloadScreen extends StatefulWidget {
  final int courseId;
  final String courseName;
  final PackageManifestRepository manifestRepo;
  final CoursePackageRepository packageRepo;

  const CourseDownloadScreen({
    super.key,
    required this.courseId,
    required this.courseName,
    required this.manifestRepo,
    required this.packageRepo,
  });

  @override
  State<CourseDownloadScreen> createState() => _CourseDownloadScreenState();
}

class _CourseDownloadScreenState extends State<CourseDownloadScreen> {
  late final ConnectivityService _connectivity;
  late final PackageFileDownloader _downloader;
  late final CoursePackageDownloadService _downloadService;

  CoursePackageManifest? _activeManifest;
  CoursePackageManifest? _remoteManifest;
  DownloadProgress? _progress;
  DownloadServiceState _state = DownloadServiceState.idle;
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<DownloadProgress>? _progressSubscription;

  @override
  void initState() {
    super.initState();
    _initServices();
    _loadState();
  }

  void _initServices() {
    _connectivity = ConnectivityService(prefs: _getPrefs());
    _downloader = PackageFileDownloader();
    _downloadService = CoursePackageDownloadService(
      manifestRepo: widget.manifestRepo,
      packageRepo: widget.packageRepo,
      downloader: _downloader,
      connectivity: _connectivity,
    );
  }

  SharedPreferences _getPrefs() {
    // Injected via provider in production; for now use sync access
    // This will be replaced with proper DI
    throw UnimplementedError('Inject SharedPreferences via provider');
  }

  Future<void> _loadState() async {
    setState(() => _isLoading = true);

    try {
      // Check active manifest
      final active = await widget.manifestRepo.getActiveManifest(
        widget.courseId,
      );
      final progress = await widget.packageRepo.getDownloadState(
        widget.courseId,
      );

      // Fetch remote manifest for version comparison
      final remoteData = await widget.packageRepo.fetchManifest(
        widget.courseId,
      );
      CoursePackageManifest? remote;
      if (remoteData != null) {
        remote = CoursePackageManifest.fromJson(remoteData);
      }

      setState(() {
        _activeManifest = active;
        _remoteManifest = remote;
        _progress = progress;
        _state = _downloadService.getState(widget.courseId);
        _isLoading = false;
      });

      // Subscribe to progress updates
      _progressSubscription = _downloadService
          .getProgressStream(widget.courseId)
          .listen((p) {
            if (mounted) {
              setState(() {
                _progress = p;
                _state = p.state;
                if (p.state == DownloadServiceState.error) {
                  _errorMessage = p.errorMessage;
                }
              });
            }
          });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _downloadService.dispose();
    _connectivity.dispose();
    _downloader.close();
    super.dispose();
  }

  bool get _hasUpdateAvailable {
    if (_activeManifest == null || _remoteManifest == null) return false;
    return _activeManifest!.version != _remoteManifest!.version;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseName),
        actions: [
          if (_activeManifest != null)
            IconButton(
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline),
              tooltip: AppLocalizations.of(context).downloadRemoveTooltip,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, theme, colorScheme),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    if (_state == DownloadServiceState.error && _errorMessage != null) {
      return _buildErrorState(theme, colorScheme);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Package info card
          if (_activeManifest != null)
            PackageInfoCard(
              manifest: _activeManifest!,
              updateAvailable: _hasUpdateAvailable,
            )
          else if (_remoteManifest != null)
            PackageInfoCard(manifest: _remoteManifest!, updateAvailable: false)
          else
            _buildNoPackageAvailable(theme),

          const SizedBox(height: VspSpacing.md),

          // Wi-Fi toggle
          WifiOnlyToggle(connectivityService: _connectivity),

          const SizedBox(height: 12),

          // Progress indicator
          if (_state == DownloadServiceState.downloading ||
              _state == DownloadServiceState.fetchingManifest ||
              _state == DownloadServiceState.validating)
            DownloadProgressIndicator(
              progress:
                  _progress ??
                  DownloadProgress(
                    courseId: widget.courseId,
                    state: _state,
                    totalBytes: _remoteManifest?.sizeBytes ?? 0,
                    downloadedBytes: 0,
                    currentFileIndex: 0,
                    totalFiles: _remoteManifest?.files.length ?? 0,
                  ),
            ),

          const SizedBox(height: 12),

          // Action buttons row
          Row(
            children: [
              Expanded(
                child: DownloadActionButton(
                  state: _state,
                  wifiRequired:
                      _connectivity.wifiOnlyEnabled && !_isWifiConnectedNow,
                  onDownload: _startDownload,
                  onUpdate: _startDownload,
                  onPause: _pauseDownload,
                  onResume: _resumeDownload,
                  onRetry: _retryDownload,
                ),
              ),
            ],
          ),

          const SizedBox(height: VspSpacing.md),

          // Offline ready confirmation
          if (_state == DownloadServiceState.offlineReady)
            _buildOfflineReadyBanner(theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildOfflineReadyBanner(ThemeData theme, ColorScheme colorScheme) {
    return Semantics(
      label: AppLocalizations.of(context).packageOfflineReadyLabel,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: VspColorSemantic.of(
            colorScheme.brightness,
            VspSemanticColorToken.courseOfflineReady,
          ).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: VspColorSemantic.of(
              colorScheme.brightness,
              VspSemanticColorToken.courseOfflineReady,
            ).withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.offline_pin,
              color: VspColorSemantic.of(
                colorScheme.brightness,
                VspSemanticColorToken.courseOfflineReady,
              ),
            ),
            const SizedBox(width: VspSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Offline Ready',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: VspColorSemantic.of(
                        colorScheme.brightness,
                        VspSemanticColorToken.courseOfflineReady,
                      ),
                    ),
                  ),
                  Text(
                    'You can play this course without internet connection.',
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
    );
  }

  Widget _buildNoPackageAvailable(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(VspSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: VspSpacing.sm),
          Text(AppLocalizations.of(context).downloadNoPackage, style: theme.textTheme.titleMedium),
          Text(
            'This course is not yet available for offline download.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: VspColorSemantic.of(
              colorScheme.brightness,
              VspSemanticColorToken.syncFailed,
            ),
          ),
          const SizedBox(height: VspSpacing.sm),
          Text(AppLocalizations.of(context).downloadFailed, style: theme.textTheme.titleMedium),
          const SizedBox(height: VspSpacing.xs),
          Text(
            _errorMessage ?? 'An error occurred.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: VspSpacing.md),
          DownloadActionButton(
            state: DownloadServiceState.error,
            onRetry: _retryDownload,
          ),
        ],
      ),
    );
  }

  bool get _isWifiConnectedNow {
    // Check synchronously is not possible; use last known state
    return _connectivity.wifiOnlyEnabled == false;
  }

  Future<void> _startDownload() async {
    await _downloadService.downloadPackage(widget.courseId);
  }

  Future<void> _resumeDownload() async {
    await _downloadService.resumeDownload(widget.courseId);
  }

  void _pauseDownload() {
    _downloadService.pauseDownload(widget.courseId);
  }

  Future<void> _retryDownload() async {
    await _downloadService.retryDownload(widget.courseId);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await DeletePackageDialog.show(
      context,
      courseName: widget.courseName,
      onConfirm: () async {
        await _downloadService.deletePackage(widget.courseId);
        if (mounted) setState(() => _activeManifest = null);
      },
    );
    if (confirmed && mounted) {
      setState(() => _activeManifest = null);
    }
  }
}

