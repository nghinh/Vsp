// Profile Screen — VSP Mobile App
//
// Full profile editing screen with all golf preference fields.
//
// AC-1: All profile fields rendered and editable.
// AC-2: Unit picker triggers immediate display conversion (no server round-trip).
// AC-3: Offline sync feedback — "Saved offline" / "Synced" snackbars.
//
// UX per ux-spec.md §10:
// - Screen reader labels for all fields
// - 44pt minimum touch targets
// - Non-color-only sync status indicators
// - Loading, error, retry states

import 'package:flutter/material.dart';
import 'package:vsp_mobile/presentation/widgets/scroll_edge_fade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../auth/presentation/auth_bloc.dart';
import '../data/profile_dto.dart';
import 'profile_bloc.dart';
import 'profile_scope.dart';
import 'widgets/profile_field_tile.dart';
import 'widgets/unit_picker.dart';
import 'widgets/skill_level_picker.dart';
import 'widgets/hand_picker.dart';
import 'package:vsp_mobile/features/performance/presentation/performance_dashboard.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

/// Main profile editing screen.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Reuses the app-wide bloc from the ProfileScope above the Navigator
    // (app.dart), so this tab edits the same profile every other screen
    // reads. It used to assemble its own ApiClient and repository here,
    // which meant its own cache, its own fetch, and a unit preference that
    // could disagree with the one the round screen was showing. When
    // nothing above provides a bloc — widget tests building this screen
    // alone — the scope creates one from the shared repository.
    return const ProfileScope(child: _ProfileScreenBody());
  }
}

class _ProfileScreenBody extends StatefulWidget {
  const _ProfileScreenBody();

  @override
  State<_ProfileScreenBody> createState() => _ProfileScreenBodyState();
}

class _ProfileScreenBodyState extends State<_ProfileScreenBody> {
  // Controllers for editable fields
  late final TextEditingController _handicapController;
  late final TextEditingController _homeClubController;
  late final TextEditingController _targetScoreController;
  late final TextEditingController _driverDistanceController;
  late final TextEditingController _swingSpeedController;
  late final TextEditingController _birthYearController;
  late final TextEditingController _countryController;

  @override
  void initState() {
    super.initState();
    _handicapController = TextEditingController();
    _homeClubController = TextEditingController();
    _targetScoreController = TextEditingController();
    _driverDistanceController = TextEditingController();
    _swingSpeedController = TextEditingController();
    _birthYearController = TextEditingController();
    _countryController = TextEditingController();

    // The shared bloc may have finished loading long before this tab opened,
    // and a BlocConsumer listener only hears changes — so seed the fields
    // from the state that already exists. And if the last attempt failed or
    // never ran, ask again now that someone is actually looking.
    final bloc = context.read<ProfileBloc>();
    final state = bloc.state;
    if (state is ProfileLoaded) {
      _syncControllers(state.profile);
    } else if (state is ProfileInitial || state is ProfileError) {
      bloc.add(const LoadProfile());
    }
  }

  @override
  void dispose() {
    _handicapController.dispose();
    _homeClubController.dispose();
    _targetScoreController.dispose();
    _driverDistanceController.dispose();
    _swingSpeedController.dispose();
    _birthYearController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  void _syncControllers(GolferProfileDto profile) {
    _handicapController.text = profile.handicap?.toString() ?? '';
    _homeClubController.text = profile.homeClub ?? '';
    _targetScoreController.text = profile.targetScore?.toString() ?? '';
    // Display driver distance in current unit
    _driverDistanceController.text =
        profile.displayDriverDistance?.toString() ?? '';
    _swingSpeedController.text = profile.swingSpeed?.toString() ?? '';
    _birthYearController.text = profile.birthYear?.toString() ?? '';
    _countryController.text = profile.country ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        // The tab's own name. It read "Edit Profile" — the title of a mode
        // you step into — on a destination reached from the bottom bar, which
        // you do not step out of.
        title: Text(AppLocalizations.of(context).navProfile),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileLoaded) {
            // Sync controllers when profile loads
            _syncControllers(state.profile);

            // Show offline / synced feedback
            if (state.hasPendingSync && !state.isSyncing) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        Icons.cloud_off,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context).profileSavedOffline),
                    ],
                  ),
                  backgroundColor: const Color(0xFF3B82F6),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          } else if (state is ProfileSessionExpired) {
            // The session is over and a refresh already failed. Sign out so
            // the root router lands on the login screen — the one action
            // that actually helps, instead of a retry into the same 401.
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr(AppMessages.authSessionExpired)),
                backgroundColor: colorScheme.error,
              ),
            );
            context.read<AuthBloc>().add(const LogoutRequested());
          } else if (state is ProfileError && state.lastProfile != null) {
            // Only when the form is still on screen does an error need the
            // snackbar. With no profile the full error view says it —
            // repeating the same sentence in a banner said it three times.
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr(state.message)),
                backgroundColor: colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ProfileLoading ||
              state is ProfileInitial ||
              // Momentary: the listener is signing the golfer out and the
              // root router is about to replace this screen entirely.
              state is ProfileSessionExpired) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ProfileError && state.lastProfile == null) {
            return _ErrorView(
              detail: state.detail == null ? null : context.tr(state.detail),
              onRetry: () {
                context.read<ProfileBloc>().add(const LoadProfile());
              },
            );
          }

          if (state is ProfileLoaded || state is ProfileError) {
            final profile = state is ProfileLoaded
                ? state.profile
                : (state as ProfileError).lastProfile!;
            final loadedState = state is ProfileLoaded ? state : null;

            return RefreshIndicator(
              onRefresh: () async {
                context.read<ProfileBloc>().add(
                  const LoadProfile(forceReload: true),
                );
                await Future.delayed(const Duration(milliseconds: 300));
              },
              child: _ProfileContent(
                profile: profile,
                state: loadedState,
                handicapController: _handicapController,
                homeClubController: _homeClubController,
                targetScoreController: _targetScoreController,
                driverDistanceController: _driverDistanceController,
                swingSpeedController: _swingSpeedController,
                birthYearController: _birthYearController,
                countryController: _countryController,
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ─── Profile Content ──────────────────────────────────────────────────────────

class _ProfileContent extends StatelessWidget {
  final GolferProfileDto profile;
  final ProfileLoaded? state;
  final TextEditingController handicapController;
  final TextEditingController homeClubController;
  final TextEditingController targetScoreController;
  final TextEditingController driverDistanceController;
  final TextEditingController swingSpeedController;
  final TextEditingController birthYearController;
  final TextEditingController countryController;

  const _ProfileContent({
    required this.profile,
    required this.state,
    required this.handicapController,
    required this.homeClubController,
    required this.targetScoreController,
    required this.driverDistanceController,
    required this.swingSpeedController,
    required this.birthYearController,
    required this.countryController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // The list runs under the bottom navigation bar, and the third screen in
    // a row to have a card sliced level with its top edge — which reads as
    // two blocks on top of each other, not as "there is more below".
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(
            VspSpacingSemantic.gutterMobile,
            VspSpacingSemantic.gutterMobile,
            VspSpacingSemantic.gutterMobile,
            VspSpacingSemantic.gutterMobile + 20,
          ),
          children: [
            // ─── Sync Status Banner ────────────────────────────────────────────
            if (state != null && state!.hasPendingSync) ...[
              _SyncBanner(isSyncing: state!.isSyncing),
              const SizedBox(height: 12),
            ],

            // ─── What the golfer's own rounds say ───────────────────────────────
            //
            // Above the editable fields on purpose: the handicap typed into the
            // profile is a claim, and this is the record. A golfer opening this
            // tab is usually asking how they are playing, not changing their
            // home club.
            const PerformanceDashboard(),
            const SizedBox(height: VspSpacing.lg),

            // ─── Identity Section ───────────────────────────────────────────────
            _SectionHeader(
              title: AppLocalizations.of(context).profileSectionIdentity,
            ),
            const SizedBox(height: VspSpacing.sm),
            _IdentitySection(profile: profile),
            const SizedBox(height: VspSpacing.lg),

            // ─── Golf Stats Section ──────────────────────────────────────────────
            _SectionHeader(
              title: AppLocalizations.of(context).profileSectionGolfStats,
            ),
            const SizedBox(height: VspSpacing.sm),
            _GolfStatsSection(
              profile: profile,
              state: state,
              handicapController: handicapController,
              homeClubController: homeClubController,
              targetScoreController: targetScoreController,
            ),
            const SizedBox(height: VspSpacing.lg),

            // ─── Distance Section ────────────────────────────────────────────────
            _SectionHeader(
              title: AppLocalizations.of(context).profileSectionDistance,
            ),
            const SizedBox(height: VspSpacing.sm),
            _DistanceSection(
              profile: profile,
              state: state,
              driverDistanceController: driverDistanceController,
            ),
            const SizedBox(height: VspSpacing.lg),

            // ─── Personal Section ────────────────────────────────────────────────
            _SectionHeader(
              title: AppLocalizations.of(context).profileSectionPersonal,
            ),
            const SizedBox(height: VspSpacing.sm),
            _PersonalSection(
              profile: profile,
              state: state,
              swingSpeedController: swingSpeedController,
              birthYearController: birthYearController,
              countryController: countryController,
            ),
            const SizedBox(height: VspSpacing.xl),
          ],
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: ScrollEdgeFade(color: colorScheme.surface),
        ),
      ],
    );
  }
}

// ─── Identity Section ──────────────────────────────────────────────────────────

class _IdentitySection extends StatelessWidget {
  final GolferProfileDto profile;

  const _IdentitySection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Avatar + name
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: colorScheme.primaryContainer,
                child: profile.imageUrl != null
                    ? ClipOval(
                        child: Image.network(
                          profile.imageUrl!,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.person,
                            size: 32,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: 32,
                        color: colorScheme.onPrimaryContainer,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).profileGolfer,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      AppLocalizations.of(
                        context,
                      ).profileIdLabel('${profile.golferAccountId}'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: VspSpacing.sm),
          // Home Club is not here.
          //
          // It was — read-only, showing "—", directly above a second Home Club
          // in Golf Stats that could be edited. One field, two rows, the same
          // label, and only one of them doing anything. The editable one is
          // the one that is any use.
          _InfoRow(
            label: AppLocalizations.of(context).profileCountry,
            value: profile.country ?? '—',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: VspSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ─── Golf Stats Section ───────────────────────────────────────────────────────

class _GolfStatsSection extends StatelessWidget {
  final GolferProfileDto profile;
  final ProfileLoaded? state;
  final TextEditingController handicapController;
  final TextEditingController homeClubController;
  final TextEditingController targetScoreController;

  const _GolfStatsSection({
    required this.profile,
    required this.state,
    required this.handicapController,
    required this.homeClubController,
    required this.targetScoreController,
  });

  @override
  Widget build(BuildContext context) {
    final isSaving = state?.savingField != null;

    return Column(
      children: [
        // Handicap
        _EditableField(
          label: AppLocalizations.of(context).profileHandicap,
          value: profile.handicap?.toString() ?? '',
          controller: handicapController,
          placeholder: 'e.g. 12.5',
          keyboardType: TextInputType.number,
          savingField: state?.savingField == ProfileField.handicap
              ? 'handicap'
              : null,
          onSave: (value) => _saveField(
            context,
            ProfileField.handicap,
            double.tryParse(value),
          ),
        ),
        const SizedBox(height: VspSpacing.sm),

        // Home Club
        _EditableField(
          label: AppLocalizations.of(context).profileHomeClub,
          value: profile.homeClub ?? '',
          controller: homeClubController,
          placeholder: AppLocalizations.of(context).profileHomeClubHint,
          savingField: state?.savingField == ProfileField.homeClub
              ? 'homeClub'
              : null,
          onSave: (value) => _saveField(
            context,
            ProfileField.homeClub,
            value.isEmpty ? null : value,
          ),
        ),
        const SizedBox(height: VspSpacing.sm),

        // Skill Level
        SkillLevelPicker(
          selectedLevel: profile.skillLevel,
          onChanged: (level) {
            context.read<ProfileBloc>().add(
              UpdateProfileField(field: ProfileField.skillLevel, value: level),
            );
            context.read<ProfileBloc>().add(
              const SaveField(field: ProfileField.skillLevel),
            );
          },
        ),
        const SizedBox(height: VspSpacing.sm),

        // Target Score
        _EditableField(
          label: AppLocalizations.of(context).profileTargetScore,
          value: profile.targetScore?.toString() ?? '',
          controller: targetScoreController,
          placeholder: 'e.g. 90',
          keyboardType: TextInputType.number,
          savingField: state?.savingField == ProfileField.targetScore
              ? 'targetScore'
              : null,
          onSave: (value) => _saveField(
            context,
            ProfileField.targetScore,
            int.tryParse(value),
          ),
        ),
      ],
    );
  }

  void _saveField(BuildContext context, ProfileField field, dynamic value) {
    context.read<ProfileBloc>().add(
      UpdateProfileField(field: field, value: value),
    );
    context.read<ProfileBloc>().add(SaveField(field: field));
  }
}

// ─── Distance Section ──────────────────────────────────────────────────────────

class _DistanceSection extends StatelessWidget {
  final GolferProfileDto profile;
  final ProfileLoaded? state;
  final TextEditingController driverDistanceController;

  const _DistanceSection({
    required this.profile,
    required this.state,
    required this.driverDistanceController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Unit Picker — AC-2: immediate display conversion
        Text(
          AppLocalizations.of(context).profileDistanceUnit,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: VspSpacing.sm),
        UnitPicker(
          selectedUnit: profile.distanceUnit,
          onChanged: (unit) {
            // UnitChanged triggers immediate local conversion (no server round-trip)
            context.read<ProfileBloc>().add(UnitChanged(unit: unit));
          },
        ),
        const SizedBox(height: VspSpacing.sm),

        // Driver Distance
        _EditableField(
          label: AppLocalizations.of(
            context,
          ).profileDriverDistance(profile.distanceUnitLabel),
          value: profile.displayDriverDistance?.toString() ?? '',
          controller: driverDistanceController,
          placeholder: 'e.g. 220',
          keyboardType: TextInputType.number,
          helperText: AppLocalizations.of(
            context,
          ).profileDriverDistanceHelper(profile.distanceUnitLabel),
          savingField: state?.savingField == ProfileField.driverDistance
              ? 'driverDistance'
              : null,
          onSave: (value) {
            final parsed = int.tryParse(value);
            if (parsed == null) return;
            // Convert display value back to canonical meters before saving
            final canonicalMeters = profile.distanceUnit == DistanceUnit.yards
                ? (parsed / 1.09361).round()
                : parsed;
            context.read<ProfileBloc>().add(
              UpdateProfileField(
                field: ProfileField.driverDistance,
                value: canonicalMeters,
              ),
            );
            context.read<ProfileBloc>().add(
              const SaveField(field: ProfileField.driverDistance),
            );
          },
        ),
      ],
    );
  }
}

// ─── Personal Section ──────────────────────────────────────────────────────────

class _PersonalSection extends StatelessWidget {
  final GolferProfileDto profile;
  final ProfileLoaded? state;
  final TextEditingController swingSpeedController;
  final TextEditingController birthYearController;
  final TextEditingController countryController;

  const _PersonalSection({
    required this.profile,
    required this.state,
    required this.swingSpeedController,
    required this.birthYearController,
    required this.countryController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Dominant Hand
        Text(
          AppLocalizations.of(context).profileDominantHand,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: VspSpacing.sm),
        HandPicker(
          selectedHand: profile.dominantHand,
          onChanged: (hand) {
            context.read<ProfileBloc>().add(
              UpdateProfileField(field: ProfileField.dominantHand, value: hand),
            );
            context.read<ProfileBloc>().add(
              const SaveField(field: ProfileField.dominantHand),
            );
          },
        ),
        const SizedBox(height: 12),

        // Swing Speed
        _EditableField(
          label: AppLocalizations.of(context).profileSwingSpeed,
          value: profile.swingSpeed?.toString() ?? '',
          controller: swingSpeedController,
          placeholder: 'e.g. 95',
          keyboardType: TextInputType.number,
          savingField: state?.savingField == ProfileField.swingSpeed
              ? 'swingSpeed'
              : null,
          onSave: (value) =>
              _saveField(context, ProfileField.swingSpeed, int.tryParse(value)),
        ),
        const SizedBox(height: VspSpacing.sm),

        // Birth Year
        _EditableField(
          label: AppLocalizations.of(context).profileBirthYear,
          value: profile.birthYear?.toString() ?? '',
          controller: birthYearController,
          placeholder: 'e.g. 1985',
          keyboardType: TextInputType.number,
          savingField: state?.savingField == ProfileField.birthYear
              ? 'birthYear'
              : null,
          onSave: (value) =>
              _saveField(context, ProfileField.birthYear, int.tryParse(value)),
        ),
        const SizedBox(height: VspSpacing.sm),

        // Country
        _EditableField(
          label: AppLocalizations.of(context).profileCountry,
          value: profile.country ?? '',
          controller: countryController,
          placeholder: 'e.g. Vietnam',
          savingField: state?.savingField == ProfileField.country
              ? 'country'
              : null,
          onSave: (value) => _saveField(
            context,
            ProfileField.country,
            value.isEmpty ? null : value,
          ),
        ),
      ],
    );
  }

  void _saveField(BuildContext context, ProfileField field, dynamic value) {
    context.read<ProfileBloc>().add(
      UpdateProfileField(field: field, value: value),
    );
    context.read<ProfileBloc>().add(SaveField(field: field));
  }
}

// ─── Editable Field ───────────────────────────────────────────────────────────

class _EditableField extends StatefulWidget {
  final String label;
  final String value;
  final TextEditingController controller;
  final String placeholder;
  final TextInputType keyboardType;
  final String? helperText;
  final String? savingField;
  final ValueChanged<String> onSave;

  const _EditableField({
    required this.label,
    required this.value,
    required this.controller,
    required this.placeholder,
    this.keyboardType = TextInputType.text,
    this.helperText,
    this.savingField,
    required this.onSave,
  });

  @override
  State<_EditableField> createState() => _EditableFieldState();
}

class _EditableFieldState extends State<_EditableField> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!_isEditing) {
      return ProfileFieldTile(
        label: widget.label,
        value: widget.value.isEmpty ? null : widget.value,
        isLoading: widget.savingField != null,
        onTap: () => setState(() => _isEditing = true),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.primary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.label, style: theme.textTheme.labelMedium),
          const SizedBox(height: VspSpacing.xs),
          TextField(
            controller: widget.controller,
            keyboardType: widget.keyboardType,
            autofocus: true,
            decoration: InputDecoration(
              hintText: widget.placeholder,
              helperText: widget.helperText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: VspSpacing.sm,
              ),
            ),
            onSubmitted: (_) => _commit(),
          ),
          const SizedBox(height: VspSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  widget.controller.text = widget.value;
                  setState(() => _isEditing = false);
                },
                child: Text(AppLocalizations.of(context).commonCancel),
              ),
              const SizedBox(width: VspSpacing.sm),
              VspButton(
                label: AppLocalizations.of(context).commonSave,
                size: VspButtonSize.small,
                onPressed: _commit,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _commit() {
    widget.onSave(widget.controller.text);
    setState(() => _isEditing = false);
  }
}

// ─── Sync Banner ───────────────────────────────────────────────────────────────

class _SyncBanner extends StatelessWidget {
  final bool isSyncing;

  const _SyncBanner({required this.isSyncing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: VspSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isSyncing
            ? const Color(0xFF3B82F6).withOpacity(0.1)
            : colorScheme.brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : VspColorLight.muted.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSyncing
              ? const Color(0xFF3B82F6)
              : colorScheme.brightness == Brightness.dark
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : VspColorLight.muted,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSyncing ? Icons.sync : Icons.cloud_off,
            size: 18,
            color: isSyncing
                ? const Color(0xFF3B82F6)
                : colorScheme.brightness == Brightness.dark
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : VspColorLight.muted,
          ),
          const SizedBox(width: VspSpacing.sm),
          Text(
            isSyncing
                ? AppLocalizations.of(context).syncSyncing
                : AppLocalizations.of(context).syncChangesSavedOffline,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isSyncing
                  ? const Color(0xFF3B82F6)
                  : colorScheme.brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : VspColorLight.muted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: VspSpacing.xs),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: VspLetterSpacing.wide,
        ),
      ),
    );
  }
}

// ─── Error View ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  /// The specific cause, shown under the generic headline. Null hides the
  /// subtitle — before, the headline was passed back in here and the screen
  /// said "Không tải được hồ sơ" twice, three times counting the snackbar.
  final String? detail;
  final VoidCallback onRetry;

  const _ErrorView({this.detail, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: VspSpacing.md),
            Text(
              AppLocalizations.of(context).profileLoadFailed,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (detail != null) ...[
              const SizedBox(height: VspSpacing.sm),
              Text(
                detail!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: VspSpacing.lg),
            VspButton(
              label: AppLocalizations.of(context).commonTryAgain,
              onPressed: onRetry,
              variant: VspButtonVariant.secondary,
              icon: Icons.refresh,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Semantic Token helper (copy of VspColorSemantic.of for offline) ───────────

enum _SemanticToken { syncPending, offline }
