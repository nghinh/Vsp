// Course Search Screen — VSP Mobile App
//
// Main course search screen with tab bar (All / Nearby / Favorites / Recent).
// Full implementation of AC-1, AC-2, AC-3.
//
// Tab behavior:
// - All: text search with debounce
// - Nearby: GPS location-based search
// - Favorites: user favorited courses
// - Recent: user recently viewed courses
//
// Design: ux-spec §5.2 + DESIGN.md

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../../core/network/api_client.dart';
import '../../../../data/api/course_search_api.dart';
import '../../../../data/repositories/course_package_repository.dart';
import '../../../../data/repositories/course_search_repository.dart';
import '../../../../data/repositories/package_manifest_repository.dart';
import '../../../../domain/models/course_search_result.dart';
import '../../../../presentation/screens/course_download_screen.dart';
import '../../../../domain/models/favorite_course.dart';
import '../../../../domain/models/recent_course.dart';
import '../../course_detail/presentation/course_detail_screen.dart';
import 'course_search_bloc.dart';
import 'course_search_event.dart';
import 'course_search_state.dart';
import 'widgets/course_card.dart';
import 'widgets/empty_search_state.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';
import 'package:vsp_mobile/domain/models/course_selection.dart';

class CourseSearchScreen extends StatelessWidget {
  /// When true the screen acts as a picker: tapping a course pops the route
  /// with that [CourseSearchResult] instead of opening the course detail.
  /// Used by round setup so a golfer with no nearby/recent course can still
  /// find one and start a round.
  final bool selectionMode;

  const CourseSearchScreen({super.key, this.selectionMode = false});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final apiClient = ApiClient();
        final api = CourseSearchApi(apiClient: apiClient);
        final repository = CourseSearchRepository(api: api);
        return CourseSearchBloc(repository: repository)
          ..add(const LoadRecent())
          ..add(const LoadFavorites())
          // Populate the default "All" tab with the full course list.
          ..add(const SearchSubmitted(''));
      },
      child: _CourseSearchScreenBody(selectionMode: selectionMode),
    );
  }
}

class _CourseSearchScreenBody extends StatefulWidget {
  final bool selectionMode;

  const _CourseSearchScreenBody({this.selectionMode = false});

  @override
  State<_CourseSearchScreenBody> createState() =>
      _CourseSearchScreenBodyState();
}

class _CourseSearchScreenBodyState extends State<_CourseSearchScreenBody>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      context.read<CourseSearchBloc>().add(TabSwitched(_tabController.index));
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<CourseSearchBloc>().add(const LoadNextPage());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.selectionMode
              ? AppLocalizations.of(context).courseSearchSelectTitle
              : AppLocalizations.of(context).courseSearchTitle,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: VspSpacing.md,
                  vertical: VspSpacing.sm,
                ),
                child: _SearchBar(
                  controller: _searchController,
                  onChanged: (query) {
                    context.read<CourseSearchBloc>().add(
                      TabSwitched(0), // Switch to "All" tab for text search
                    );
                    context.read<CourseSearchBloc>().add(
                      SearchTextChanged(query),
                    );
                  },
                  onSubmitted: (query) {
                    context.read<CourseSearchBloc>().add(
                      SearchSubmitted(query),
                    );
                  },
                  onNearbyPressed: () {
                    _tabController.animateTo(1); // Switch to "Nearby" tab
                  },
                ),
              ),

              // Tab bar
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: AppLocalizations.of(context).courseTabAll),
                  Tab(text: AppLocalizations.of(context).courseTabNearby),
                  Tab(text: AppLocalizations.of(context).courseTabFavorites),
                  Tab(text: AppLocalizations.of(context).courseTabRecent),
                ],
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                indicatorColor: colorScheme.primary,
                indicatorSize: TabBarIndicatorSize.label,
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 0: All (text search)
          _SearchResultsTab(
            scrollController: _scrollController,
            selectionMode: widget.selectionMode,
          ),

          // Tab 1: Nearby
          _NearbyTab(
            scrollController: _scrollController,
            selectionMode: widget.selectionMode,
          ),

          // Tab 2: Favorites
          _FavoritesTab(selectionMode: widget.selectionMode),

          // Tab 3: Recent
          _RecentTab(selectionMode: widget.selectionMode),
        ],
      ),
    );
  }
}

// ─── Search Bar ───────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onNearbyPressed;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onNearbyPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).courseSearchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: VspSpacing.sm,
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
            ),
            textInputAction: TextInputAction.search,
          ),
        ),
        const SizedBox(width: VspSpacing.sm),

        // Nearby button
        SizedBox(
          height: 48,
          child: IconButton.filled(
            onPressed: onNearbyPressed,
            icon: const Icon(Icons.near_me),
            tooltip: AppLocalizations.of(context).courseSearchNearbyTooltip,
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── All Tab ─────────────────────────────────────────────────────────────────

class _SearchResultsTab extends StatelessWidget {
  final ScrollController scrollController;
  final bool selectionMode;

  const _SearchResultsTab({
    required this.scrollController,
    this.selectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CourseSearchBloc, CourseSearchState>(
      builder: (context, state) {
        if (state is CourseSearchLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is CourseSearchError) {
          return EmptySearchState(
            message: AppLocalizations.of(context).commonError,
            subtitle: context.tr(state.message),
            actionLabel: AppLocalizations.of(context).commonTryAgain,
            onAction: () {
              context.read<CourseSearchBloc>().add(const RefreshResults());
            },
          );
        }

        if (state is CourseSearchLoaded && state.results.isEmpty) {
          if (state.lastQuery != null && state.lastQuery!.isNotEmpty) {
            return EmptySearchState.noResults(
              actionLabel: AppLocalizations.of(context).courseSearchClear,
              onAction: () {
                context.read<CourseSearchBloc>().add(const SearchSubmitted(''));
              },
            );
          }
          return EmptySearchState(
            message: AppLocalizations.of(context).courseSearchPrompt,
            subtitle: AppLocalizations.of(context).courseSearchPromptSubtitle,
            icon: Icons.golf_course,
          );
        }

        if (state is CourseSearchLoaded) {
          return _ResultsList(
            results: state.results,
            scrollController: scrollController,
            isLoadingMore: state.isLoadingMore,
            hasNext: state.hasNext,
            selectionMode: selectionMode,
          );
        }

        // Initial state
        return EmptySearchState(
          message: AppLocalizations.of(context).courseSearchPrompt,
          subtitle: AppLocalizations.of(context).courseSearchPromptSubtitle,
          icon: Icons.golf_course,
        );
      },
    );
  }
}

// ─── Nearby Tab ───────────────────────────────────────────────────────────────

class _NearbyTab extends StatelessWidget {
  final ScrollController scrollController;
  final bool selectionMode;

  const _NearbyTab({
    required this.scrollController,
    this.selectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CourseSearchBloc, CourseSearchState>(
      builder: (context, state) {
        if (state is CourseSearchLoading &&
            state.activeTab == SearchTab.nearby) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: VspSpacing.md),
                Text(
                  AppLocalizations.of(context).courseFindingNearby,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        if (state is CourseSearchError && state.activeTab == SearchTab.nearby) {
          return EmptySearchState.locationDenied(
            actionLabel: AppLocalizations.of(context).commonTryAgain,
            onAction: () {
              context.read<CourseSearchBloc>().add(const SearchNearby());
            },
          );
        }

        if (state is CourseSearchLoaded &&
            state.activeTab == SearchTab.nearby &&
            state.results.isEmpty) {
          final lat = state.lastLatitude;
          final lng = state.lastLongitude;
          return EmptySearchState(
            message: AppLocalizations.of(context).courseNoCoursesNearby,
            icon: Icons.golf_course,
            subtitle: AppLocalizations.of(context).courseExpandSearchSubtitle,
            actionLabel: AppLocalizations.of(context).courseExpandSearch,
            onAction: () {
              // Widen around the last fix; re-acquire GPS if we never had one.
              context.read<CourseSearchBloc>().add(
                lat != null && lng != null
                    ? NearbyLocationUpdated(
                        latitude: lat,
                        longitude: lng,
                        radiusMeters: 100000, // 100km
                      )
                    : const SearchNearby(radiusMeters: 100000),
              );
            },
          );
        }

        if (state is CourseSearchLoaded &&
            state.activeTab == SearchTab.nearby) {
          return _ResultsList(
            results: state.results,
            scrollController: scrollController,
            isLoadingMore: state.isLoadingMore,
            hasNext: state.hasNext,
            selectionMode: selectionMode,
          );
        }

        // Default: prompt to enable location. The bloc resolves the real GPS
        // fix and surfaces an error state if permission/location is missing.
        return EmptySearchState.locationDenied(
          actionLabel: AppLocalizations.of(context).courseFindNearby,
          onAction: () {
            context.read<CourseSearchBloc>().add(const SearchNearby());
          },
        );
      },
    );
  }
}

// ─── Favorites Tab ────────────────────────────────────────────────────────────

class _FavoritesTab extends StatelessWidget {
  /// True when this screen was opened to pick a course for a round.
  final bool selectionMode;

  const _FavoritesTab({this.selectionMode = false});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CourseSearchBloc, CourseSearchState>(
      builder: (context, state) {
        if (state is CourseSearchFavoritesLoaded && state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is CourseSearchError &&
            state.activeTab == SearchTab.favorites) {
          return EmptySearchState(
            message: AppLocalizations.of(context).courseFavoritesLoadFailed,
            subtitle: context.tr(state.message),
            actionLabel: 'Retry',
            onAction: () {
              context.read<CourseSearchBloc>().add(const LoadFavorites());
            },
          );
        }

        if (state is CourseSearchFavoritesLoaded) {
          if (state.favorites.isEmpty) {
            return const EmptySearchState.noFavorites();
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<CourseSearchBloc>().add(
                const LoadFavorites(forceReload: true),
              );
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
              itemCount: state.favorites.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: VspSpacing.sm),
              itemBuilder: (context, index) {
                final fav = state.favorites[index];
                return _FavoriteCourseTile(
                  favorite: fav,
                  // Was a placeholder comment: tapping a favourite recorded the
                  // view and went nowhere, so the tab a golfer keeps their home
                  // course in was the one tab they could not open it from.
                  onTap: () {
                    context.read<CourseSearchBloc>().add(
                      RecordCourseView(fav.courseId),
                    );
                    if (selectionMode) {
                      Navigator.of(
                        context,
                      ).pop(CourseSelection.fromFavorite(fav));
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CourseDetailScreen(courseId: fav.courseId),
                      ),
                    );
                  },
                  onRemove: () {
                    context.read<CourseSearchBloc>().add(
                      ToggleFavorite(fav.courseId),
                    );
                  },
                );
              },
            ),
          );
        }

        return const EmptySearchState.noFavorites();
      },
    );
  }
}

// ─── Recent Tab ───────────────────────────────────────────────────────────────

class _RecentTab extends StatelessWidget {
  /// True when this screen was opened to pick a course for a round.
  final bool selectionMode;

  const _RecentTab({this.selectionMode = false});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CourseSearchBloc, CourseSearchState>(
      builder: (context, state) {
        if (state is CourseSearchRecentLoaded && state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is CourseSearchError && state.activeTab == SearchTab.recent) {
          return EmptySearchState(
            message: AppLocalizations.of(context).courseRecentLoadFailed,
            subtitle: context.tr(state.message),
            actionLabel: 'Retry',
            onAction: () {
              context.read<CourseSearchBloc>().add(const LoadRecent());
            },
          );
        }

        if (state is CourseSearchRecentLoaded) {
          if (state.recentCourses.isEmpty) {
            return const EmptySearchState.noRecent();
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<CourseSearchBloc>().add(
                const LoadRecent(forceReload: true),
              );
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
              itemCount: state.recentCourses.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: VspSpacing.sm),
              itemBuilder: (context, index) {
                final recent = state.recentCourses[index];
                return _RecentCourseTile(
                  recent: recent,
                  onTap: () {
                    context.read<CourseSearchBloc>().add(
                      RecordCourseView(recent.courseId),
                    );
                    if (selectionMode) {
                      Navigator.of(
                        context,
                      ).pop(CourseSelection.fromRecent(recent));
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CourseDetailScreen(courseId: recent.courseId),
                      ),
                    );
                  },
                );
              },
            ),
          );
        }

        return const EmptySearchState.noRecent();
      },
    );
  }
}

// ─── Results List ─────────────────────────────────────────────────────────────

class _ResultsList extends StatelessWidget {
  final List<CourseSearchResult> results;
  final ScrollController scrollController;
  final bool isLoadingMore;
  final bool hasNext;

  /// When true, tapping a card returns it to the caller instead of navigating.
  final bool selectionMode;

  const _ResultsList({
    required this.results,
    required this.scrollController,
    required this.isLoadingMore,
    required this.hasNext,
    this.selectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<CourseSearchBloc>().add(const RefreshResults());
      },
      child: ListView.separated(
        controller: scrollController,
        padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
        itemCount: results.length + (isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: VspSpacing.sm),
        itemBuilder: (context, index) {
          if (index >= results.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(VspSpacing.md),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final course = results[index];
          return CourseCard(
            course: course,
            onTap: () {
              context.read<CourseSearchBloc>().add(
                RecordCourseView(course.courseId),
              );
              if (selectionMode) {
                Navigator.of(
                  context,
                ).pop(CourseSelection.fromSearchResult(course));
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CourseDetailScreen(courseId: course.courseId),
                ),
              );
            },
            onFavoriteToggle: () {
              context.read<CourseSearchBloc>().add(
                ToggleFavorite(course.courseId),
              );
            },
            onDownloadTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CourseDownloadScreen(
                    courseId: course.courseId,
                    courseName: course.displayName,
                    manifestRepo: PackageManifestRepository(),
                    packageRepo: CoursePackageRepository(
                      apiClient: ApiClient(),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Favorites Tile ────────────────────────────────────────────────────────────

class _FavoriteCourseTile extends StatelessWidget {
  final FavoriteCourse favorite;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FavoriteCourseTile({
    required this.favorite,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
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
                    favorite.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: VspSpacing.half),
                  Text(
                    favorite.favoritedAtLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.favorite, color: Colors.red),
              tooltip: AppLocalizations.of(context).courseRemoveFavorite,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Recent Course Tile ────────────────────────────────────────────────────────

class _RecentCourseTile extends StatelessWidget {
  final RecentCourse recent;
  final VoidCallback onTap;

  const _RecentCourseTile({required this.recent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.history,
                color: colorScheme.onSurfaceVariant,
                size: VspIconSize.md,
              ),
            ),
            const SizedBox(width: VspSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recent.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (recent.address != null) ...[
                    const SizedBox(height: VspSpacing.half),
                    Text(
                      recent.address!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Text(
              recent.viewedAtLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
