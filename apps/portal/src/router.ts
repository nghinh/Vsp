import { createRouter, createWebHistory, type RouteLocationNormalized } from "vue-router";
import FacilitiesPage from "./pages/facilities/index.vue";
import TournamentListPage from "./pages/tournament/list.vue";
import { getAuthToken, getUserRoles } from "./auth";
import { resolveNavigation } from "./guard";
import {
  COURSE_ROLES,
  GREENKEEPING_ROLES,
  CORRECTION_ROLES,
  DATA_QUALITY_ROLES,
  TOURNAMENT_ROLES,
  SUPER_ADMIN_ONLY,
} from "./roles";

/** Inject the portal auth token (+ any route params) as component props. */
function withAuth(
  extra: (route: RouteLocationNormalized) => Record<string, unknown> = () => ({}),
) {
  return (route: RouteLocationNormalized) => ({
    authToken: getAuthToken(),
    ...extra(route),
  });
}

const numParam = (v: unknown) => Number(Array.isArray(v) ? v[0] : v);

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: "/", redirect: "/dashboard" },

    // ─── Session ─────────────────────────────────────────────────────────────
    {
      path: "/login",
      component: () => import("./pages/login/index.vue"),
      meta: { title: "Đăng nhập", public: true },
    },
    {
      path: "/forbidden",
      component: () => import("./pages/forbidden/index.vue"),
      meta: { title: "Không đủ quyền" },
    },

    {
      path: "/dashboard",
      component: () => import("./pages/dashboard/index.vue"),
      meta: { title: "Tổng quan vận hành" },
    },

    // ─── Facilities & Courses ────────────────────────────────────────────────
    {
      path: "/facilities",
      component: FacilitiesPage,
      props: withAuth(),
      meta: { title: "Cơ sở & Sân golf", roles: COURSE_ROLES },
    },
    {
      path: "/facilities/:id",
      component: () => import("./pages/facilities/[id].vue"),
      props: withAuth(),
      meta: { title: "Chi tiết cơ sở", roles: COURSE_ROLES },
    },
    {
      path: "/facilities/:id/courses",
      component: () => import("./pages/facilities/[id]/courses/index.vue"),
      props: withAuth(),
      meta: { title: "Sân golf tại cơ sở", roles: COURSE_ROLES },
    },

    // ─── Course management sub-pages ─────────────────────────────────────────
    {
      path: "/courses/:courseId/holes",
      component: () => import("./pages/courses/[courseId]/holes/index.vue"),
      props: withAuth(),
      meta: { title: "Danh sách hố", roles: COURSE_ROLES },
    },
    {
      path: "/courses/:courseId/tee-sets",
      component: () => import("./pages/courses/[courseId]/tee-sets/index.vue"),
      props: withAuth(),
      meta: { title: "Bộ tee", roles: COURSE_ROLES },
    },
    {
      path: "/courses/:courseId/edit-geometry",
      component: () => import("./pages/courses/[courseId]/edit-geometry/index.vue"),
      props: withAuth((route) => ({
        courseId: numParam(route.params.courseId),
        userRoles: getUserRoles(),
      })),
      meta: { title: "Biên tập bản đồ", roles: COURSE_ROLES },
    },
    {
      path: "/courses/:courseId/versions",
      component: () => import("./pages/courses/[courseId]/versions/index.vue"),
      props: withAuth((route) => ({ courseId: numParam(route.params.courseId) })),
      meta: { title: "Phiên bản & Kiểm tra", roles: COURSE_ROLES },
    },
    {
      path: "/courses/:courseId/versions/:versionId/publish",
      component: () =>
        import("./pages/courses/[courseId]/versions/[versionId]/publish/index.vue"),
      meta: { title: "Kiểm tra & Công bố", roles: COURSE_ROLES },
    },
    {
      path: "/courses/:courseId/packages",
      component: () => import("./pages/courses/[courseId]/packages/index.vue"),
      props: withAuth((route) => ({ courseId: numParam(route.params.courseId) })),
      meta: { title: "Lịch sử đóng gói", roles: COURSE_ROLES },
    },

    { path: "/map-editor", redirect: "/facilities" },

    // ─── Operations ──────────────────────────────────────────────────────────
    {
      path: "/pin-positions",
      component: () => import("./pages/pin-positions/index.vue"),
      meta: { title: "Vị trí cờ & Điều kiện sân", roles: GREENKEEPING_ROLES },
    },
    {
      path: "/course-conditions",
      component: () => import("./pages/course-conditions/index.vue"),
      meta: { title: "Tình trạng sân", roles: GREENKEEPING_ROLES },
    },
    {
      path: "/alerts",
      component: () => import("./pages/alerts/index.vue"),
      meta: { title: "Cảnh báo sân", roles: COURSE_ROLES },
    },
    {
      path: "/corrections",
      component: () => import("./pages/corrections/index.vue"),
      props: withAuth(),
      meta: { title: "Hàng đợi hiệu chỉnh", roles: CORRECTION_ROLES },
    },
    {
      path: "/admin/data-quality",
      component: () => import("./pages/admin/data-quality/index.vue"),
      props: withAuth(),
      meta: { title: "Chất lượng dữ liệu", roles: DATA_QUALITY_ROLES },
    },

    // ─── Tournaments ─────────────────────────────────────────────────────────
    {
      path: "/tournaments",
      component: TournamentListPage,
      props: withAuth(),
      meta: { title: "Điều hành giải đấu", roles: TOURNAMENT_ROLES },
    },
    {
      path: "/tournament/create",
      component: () => import("./pages/tournament/create.vue"),
      props: withAuth(),
      meta: { title: "Tạo giải đấu", roles: TOURNAMENT_ROLES },
    },
    {
      path: "/tournament/:id",
      component: () => import("./pages/tournament/detail.vue"),
      props: withAuth(),
      meta: { title: "Chi tiết giải đấu", roles: TOURNAMENT_ROLES },
    },
    {
      path: "/tournament-policies",
      component: () => import("./pages/tournaments/index.vue"),
      props: withAuth(),
      meta: { title: "Chính sách giải đấu", roles: TOURNAMENT_ROLES },
    },
    {
      path: "/tournament-policies/:policyId",
      component: () => import("./pages/tournaments/[policyId]/index.vue"),
      props: withAuth((route) => ({
        policyId: String(route.params.policyId),
      })),
      meta: { title: "Chi tiết chính sách", roles: TOURNAMENT_ROLES },
    },

    // ─── Admin ───────────────────────────────────────────────────────────────
    {
      path: "/users",
      component: () => import("./pages/users/index.vue"),
      meta: { title: "Người dùng & Vai trò", roles: SUPER_ADMIN_ONLY },
    },
    {
      path: "/market-integrations",
      component: () => import("./pages/market-integrations/index.vue"),
      props: withAuth(),
      meta: { title: "Thị trường & Tích hợp", roles: SUPER_ADMIN_ONLY },
    },
  ],
});

/**
 * Nothing reaches a page without going through `resolveNavigation` first. See
 * `guard.ts` for what it decides and why it is a separate module.
 */
router.beforeEach(resolveNavigation);

export default router;
