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
import 'package:vsp_mobile/l10n/app_messages.dart';

/// Screen for managing course package download/update/delete.
class CourseDownloadScreen extends StatefulWidget {
  final int courseId;
  final String courseName;
  final PackageManifestRepository manifestRepo;
  final CoursePackageRepository packageRepo;

  /// The club's other đường, fetched in the same go.
  ///
  /// A club like Long Biên is three nines and six ways of pairing them, and a
  /// package covers one nine. Downloading only the nine that happened to be
  /// asked for produced a sequence nobody could follow: fetch Đường B, see
  /// "Sẵn sàng ngoại tuyến", pick Đường A → Đường B, be told to download
  /// again. Every sentence true, the whole thing unreadable — and the golfer's
  /// own summary of it was "rất linh tinh".
  ///
  /// A đường's package is about 8 KB. There was never a reason to ration
  /// them, and "tải sân" ought to mean the sân.
  final List<int> siblingCourseIds;

  const CourseDownloadScreen({
    super.key,
    required this.courseId,
    required this.courseName,
    required this.manifestRepo,
    required this.packageRepo,
    this.siblingCourseIds = const [],
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
  }

  /// Builds the download services, then loads the current state.
  ///
  /// This used to be synchronous and end in
  /// `throw UnimplementedError('Inject SharedPreferences via provider')`,
  /// called straight from initState — and this screen is a live navigation
  /// target from the course list, so tapping a course to download it produced
  /// a red screen. The preferences are simply read here: they are what
  /// [ConnectivityService] answers the Wi-Fi-only question from, and reading
  /// them is a future, not a dependency somebody has to inject.
  Future<void> _initServices() async {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = AppLocalizations.of(
          context,
        ).downloadPreferencesUnavailable;
      });
      return;
    }
    if (!mounted) return;

    _connectivity = ConnectivityService(prefs: prefs);
    _downloader = PackageFileDownloader();
    _downloadService = CoursePackageDownloadService(
      manifestRepo: widget.manifestRepo,
      packageRepo: widget.packageRepo,
      downloader: _downloader,
      connectivity: _connectivity,
    );
    setState(() => _servicesReady = true);
    await _loadState();
  }

  /// False until the services above exist. Everything that touches them is
  /// gated on this rather than on `late final` throwing a LateInitializationError.
  bool _servicesReady = false;

  /// How many of the club's other đường have been started, or 0 when idle.
  ///
  /// The progress bar belongs to the đường the golfer opened this screen for;
  /// this is the line underneath saying the rest are on their way, so a
  /// finished bar with the screen still working does not read as a hang.
  int _siblingsFetched = 0;

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
    // Nothing to tear down if the preferences never resolved, and touching a
    // `late final` that was never assigned throws.
    if (_servicesReady) {
      _downloadService.dispose();
      _connectivity.dispose();
      _downloader.close();
    }
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
      body: _isLoading || !_servicesReady
          ? _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        context.tr(_errorMessage!),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : const Center(child: CircularProgressIndicator())
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
          // Package info card.
          //
          // A local manifest the server no longer publishes — or one that
          // was promoted with no bytes behind it — is not a package. Long
          // Biên showed 0.0 MB, eleven files and a Download button that
          // could only fail: the server has never built a package for it.
          if (_activeManifest != null && _hasRealPackage(_activeManifest!))
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

          // The rest of the club, while it is happening. Without this the bar
          // reaches the end and the screen keeps working, which reads as a
          // stall.
          if (_siblingsFetched > 0)
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: VspSpacing.sm),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).downloadOtherLayouts(
                      '$_siblingsFetched',
                      '${widget.siblingCourseIds.length}',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),

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
                    AppLocalizations.of(context).packageOfflineReady,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: VspColorSemantic.of(
                        colorScheme.brightness,
                        VspSemanticColorToken.courseOfflineReady,
                      ),
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context).packageOfflineReadyBody,
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

  /// Whether a manifest has an actual package behind it.
  ///
  /// Bytes are the test. A manifest can be saved and promoted with a file
  /// list and a zero size — that is what "0.0 MB, 11 tệp" was — and the
  /// screen then offers to download something that does not exist.
  bool _hasRealPackage(CoursePackageManifest manifest) =>
      manifest.sizeBytes > 0 && manifest.files.isNotEmpty;

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
          Text(
            AppLocalizations.of(context).downloadNoPackage,
            style: theme.textTheme.titleMedium,
          ),
          Text(
            AppLocalizations.of(context).packageNotAvailable,
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
          Text(
            AppLocalizations.of(context).downloadFailed,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: VspSpacing.xs),
          Text(
            // The service emits message keys, not sentences. Printed
            // straight, a golfer was shown "msg.serverError".
            _errorMessage == null
                ? AppLocalizations.of(context).downloadFailed
                : context.tr(_errorMessage!),
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
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final before = _activeManifest?.version;

    final result = await _downloadService.downloadPackage(widget.courseId);
    if (!mounted) return;

    // Then the rest of the club, so "sân đã tải" means the sân.
    //
    // Sequential on purpose: the download service keys its progress stream and
    // its pause/resume state by course id, and running two at once would have
    // them writing over each other's progress on the one screen. Three nines
    // at 8 KB each is not worth parallelising.
    //
    // A sibling that fails does not fail the download the golfer asked for —
    // they came here for this đường and they now have it. The banner on the
    // setup screen still lists any nine that did not arrive, so nothing is
    // hidden by carrying on.
    if (result is DownloadPackageSuccess) {
      for (final sibling in widget.siblingCourseIds) {
        if (!mounted) return;
        setState(() => _siblingsFetched++);
        try {
          await _downloadService.downloadPackage(sibling);
        } catch (_) {
          // Left for the setup screen to report against its own đường.
        }
      }
      if (!mounted) return;
      setState(() => _siblingsFetched = 0);
    }

    // Tapping "Cập nhật" on a package that is already current returns
    // success having downloaded nothing, and the screen looked identical —
    // a button that does nothing, twice, is how a golfer concludes the app
    // is broken. Say which of the two happened.
    if (result is DownloadPackageSuccess) {
      final unchanged = before != null && result.manifest.version == before;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(unchanged
              ? l10n.downloadAlreadyCurrent
              : l10n.downloadCompleted),
        ));
    }
    await _loadState();
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
