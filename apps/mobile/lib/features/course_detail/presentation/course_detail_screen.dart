// Course Detail Screen — VSP Mobile App
//
// Full course detail with 10 sections covering all AC-1 fields.
//
// AC-1: Details include all required fields (contact, coordinates, facilities,
//       holes, tee sets, local rules, ratings, conditions, and update time)
// AC-2: Unavailable data shown as "unavailable" (not fabricated)
// AC-3: Official/estimated/stale/community distinguishable via DataQualityBadge
//
// Design: ux-spec §5.2 + DESIGN.md
// Sections: Overview, Contact, Coordinates, Facilities, Holes,
//           Tee Sets, Conditions, Ratings, Local Rules, Data Quality

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../../core/network/api_client.dart';
import '../../../../data/api/course_detail_api.dart';
import '../../../../data/repositories/course_detail_repository.dart';
import '../../../../domain/models/course_detail.dart';
import '../../round_setup/presentation/round_setup_screen.dart';
import 'course_detail_bloc.dart';
import 'course_detail_event.dart';
import 'course_detail_state.dart';
import 'widgets/course_hero_section.dart';
import 'widgets/contact_section.dart';
import 'widgets/coordinates_section.dart';
import 'widgets/facilities_section.dart';
import 'widgets/hole_list_section.dart';
import 'widgets/tee_set_section.dart';
import 'widgets/conditions_section.dart';
import 'widgets/ratings_section.dart';
import 'widgets/local_rules_section.dart';
import 'widgets/data_quality_section.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';
import '../../scorecard/presentation/scorecard_submit_screen.dart';
import 'package:vsp_mobile/features/caddie/caddie_book.dart';
import 'package:vsp_mobile/features/strategy/presentation/strategy_screen.dart';

/// Course detail screen — full course information for pre-round preparation.
class CourseDetailScreen extends StatelessWidget {
  final int courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final apiClient = ApiClient();
        final api = CourseDetailApi(apiClient: apiClient);
        final repository = CourseDetailRepository(api: api);
        return CourseDetailBloc(repository: repository)
          ..add(LoadCourseDetail(courseId));
      },
      child: const _CourseDetailScreenBody(),
    );
  }
}

class _CourseDetailScreenBody extends StatelessWidget {
  const _CourseDetailScreenBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<CourseDetailBloc, CourseDetailState>(
        builder: (context, state) {
          if (state is CourseDetailLoading) {
            return const _LoadingBody();
          }

          if (state is CourseDetailError) {
            return _ErrorBody(
              message: context.tr(state.message),
              onRetry: () {
                final courseId =
                    (context.read<CourseDetailBloc>().state
                            as CourseDetailError?)
                        ?.lastCourse
                        ?.courseId ??
                    0;
                if (courseId > 0) {
                  context.read<CourseDetailBloc>().add(
                    LoadCourseDetail(courseId),
                  );
                }
              },
            );
          }

          if (state is CourseDetailLoaded) {
            return _LoadedBody(course: state.course);
          }

          return const _LoadingBody();
        },
      ),
      bottomNavigationBar: BlocBuilder<CourseDetailBloc, CourseDetailState>(
        builder: (context, state) {
          if (state is! CourseDetailLoaded) return const SizedBox.shrink();
          final course = state.course;
          return SafeArea(
            minimum: const EdgeInsets.all(VspSpacing.md),
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RoundSetupScreen(
                      initialCourseId: course.courseId,
                      initialCourseName: course.facilityName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.golf_course),
              label: Text(AppLocalizations.of(context).homeStartRound),
            ),
          );
        },
      ),
    );
  }
}

// ─── Loading State ───────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: colorScheme.surface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(color: colorScheme.surface),
          ),
        ),
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: VspSpacing.md),
                Text(AppLocalizations.of(context).courseDetailLoading),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Error State ─────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: colorScheme.surface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(color: colorScheme.surface),
          ),
        ),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(VspSpacing.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                  const SizedBox(height: VspSpacing.md),
                  Text(
                    AppLocalizations.of(context).courseDetailLoadFailed,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: VspSpacing.sm),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: VspSpacing.lg),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: Text(AppLocalizations.of(context).commonTryAgain),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Loaded State ────────────────────────────────────────────────────────────

class _LoadedBody extends StatelessWidget {
  final CourseDetail course;

  const _LoadedBody({required this.course});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<CourseDetailBloc>().add(const RefreshCourseDetail());
      },
      child: CustomScrollView(
        slivers: [
          // App bar with course name
          SliverAppBar(
            pinned: true,
            expandedHeight: 0,
            backgroundColor: colorScheme.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              course.facilityName,
              style: const TextStyle(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              // The caddie's pencilled page: 18 rows of shots received, net
              // par and club picks, built for this golfer, shareable as one
              // image.
              IconButton(
                key: const Key('course_detail_strategy_action'),
                icon: const Icon(Icons.menu_book_outlined),
                tooltip: AppLocalizations.of(context).strategyOpen,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StrategyScreen(courseId: course.courseId),
                  ),
                ),
              ),
              // Caddie book: Vietnamese courses require a caddie and golfers
              // ask for good ones back by number — this is where that number
              // is looked up before the round.
              IconButton(
                key: const Key('course_detail_caddie_action'),
                icon: const Icon(Icons.badge_outlined),
                tooltip: AppLocalizations.of(context).caddieOpen,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CaddieBookScreen(
                      facilityId: course.facilityId,
                      facilityName: course.facilityName,
                    ),
                  ),
                ),
              ),
              // The scorecard button also sits at the foot of this page, past
              // the conditions and the tee sets and the data-quality panel —
              // which is to say, past where anyone scrolls. A golfer holding
              // the club's card needs it on arrival.
              IconButton(
                key: const Key('course_detail_scorecard_action'),
                icon: const Icon(Icons.assignment_outlined),
                tooltip: AppLocalizations.of(context).scorecardTitle,
                onPressed: () => _openScorecardSubmission(context, course),
              ),
            ],
          ),

          // Hero section
          SliverToBoxAdapter(
            child: CourseHeroSection(
              course: course,
              onDownloadPressed:
                  null, // Course package download out of scope for 3-3
            ),
          ),

          // Divider
          const SliverToBoxAdapter(child: Divider(height: 1)),

          // Contact section
          if (course.hasContact)
            SliverToBoxAdapter(child: ContactSection(course: course)),

          // Coordinates section
          SliverToBoxAdapter(child: CoordinatesSection(course: course)),

          // Facilities section
          if (course.hasFacilities)
            SliverToBoxAdapter(child: FacilitiesSection(course: course)),

          // Ratings section
          if (course.hasRatings)
            SliverToBoxAdapter(child: RatingsSection(course: course)),

          // Conditions section
          if (course.hasConditions)
            SliverToBoxAdapter(child: ConditionsSection(course: course)),

          // Tee sets section
          if (course.teeSets.isNotEmpty)
            SliverToBoxAdapter(child: TeeSetSection(course: course)),

          // Holes section
          if (course.holes.isNotEmpty)
            SliverToBoxAdapter(child: HoleListSection(course: course)),

          // Local rules section
          if (course.hasLocalRules)
            SliverToBoxAdapter(child: LocalRulesSection(course: course)),

          // Data quality section
          SliverToBoxAdapter(child: DataQualitySection(course: course)),

          // The club's card. Stroke index is printed on it and held nowhere
          // else, so the golfer standing there with it is the only source the
          // app will ever have.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: VspSpacing.md,
                vertical: VspSpacing.sm,
              ),
              child: OutlinedButton.icon(
                key: const Key('course_detail_submit_scorecard'),
                icon: const Icon(Icons.assignment_outlined),
                label: Text(AppLocalizations.of(context).scorecardTitle),
                onPressed: () => _openScorecardSubmission(context, course),
              ),
            ),
          ),

          // Bottom safe area
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).padding.bottom + VspSpacing.md,
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the form for typing in the club's printed card.
  ///
  /// Reached from the app bar and from the foot of the page: the golfer with
  /// the card in their hand is the app's only source of stroke index, and a
  /// button they have to scroll past a data-quality panel to find is a source
  /// nobody uses.
  void _openScorecardSubmission(BuildContext context, CourseDetail course) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScorecardSubmitScreen(
          courseId: course.courseId,
          facilityCourses: course.facilityCourses,
          defaultName: course.facilityCourses.length > 1
              ? ''
              : course.facilityName,
        ),
      ),
    );
  }
}
