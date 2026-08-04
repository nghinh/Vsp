# Context Understanding

- Scope is controlled by PRD and explicit epic/story artifacts; mockup presence does not promote deferred features into MVP.
- Mobile implementation root: `apps/mobile/` (Flutter/Dart), with shared `packages/mobile-theme/` and `packages/course-package/`.
- Every mobile story dispatch must cite its relevant `docs/mockup/*.html`, matching PNG, `docs/mockup/DESIGN.md`, UX spec, architecture, PRD, and story source.
- Translate HTML references into Flutter widgets and semantic theme tokens; do not copy web architecture or scatter raw colors.
- Preserve offline-first persistence, explicit sync/package states, GPS accuracy/confidence, MapLibre/vector-first maps, accessibility, and one-handed/two-tap interaction constraints.
- Mockups 01–19 cover MVP-oriented mobile onboarding, discovery, round, history, profile, and privacy. Mockups 20–24 and 40–42 include deferred/future capabilities unless explicitly authorized by stories.
- Exact mockup-to-story mapping must be established during story discovery and planning.
