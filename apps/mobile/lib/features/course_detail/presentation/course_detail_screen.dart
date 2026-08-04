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
              message: state.message,
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
        const SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: VspSpacing.md),
                Text('Loading course details...'),
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
                    'Failed to load course',
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
                    label: const Text('Try Again'),
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
}
