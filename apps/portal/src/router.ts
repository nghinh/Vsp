import { createRouter, createWebHistory, type RouteLocationNormalized } from "vue-router";
import FacilitiesPage from "./pages/facilities/index.vue";
import TournamentListPage from "./pages/tournament/list.vue";
import { getAuthToken, getUserRoles } from "./auth";

const PlaceholderPage = (title: string, description: string) => ({
  template: `<section class="placeholder-page"><div class="eyebrow">GolfOps Portal</div><h2>${title}</h2><p>${description}</p><div class="placeholder-card"><span class="material-symbols-outlined">construction</span><div><strong>Màn hình đang được kết nối</strong><p>Thiết kế và luồng nghiệp vụ đã được xác định theo bộ mockup vận hành.</p></div></div></section>`,
});

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
      meta: { title: "Cơ sở & Sân golf" },
    },
    {
      path: "/facilities/:id",
      component: () => import("./pages/facilities/[id].vue"),
      props: withAuth(),
      meta: { title: "Chi tiết cơ sở" },
    },
    {
      path: "/facilities/:id/courses",
      component: () => import("./pages/facilities/[id]/courses/index.vue"),
      props: withAuth(),
      meta: { title: "Sân golf tại cơ sở" },
    },

    // ─── Course management sub-pages ─────────────────────────────────────────
    {
      path: "/courses/:courseId/holes",
      component: () => import("./pages/courses/[courseId]/holes/index.vue"),
      props: withAuth(),
      meta: { title: "Danh sách hố" },
    },
    {
      path: "/courses/:courseId/tee-sets",
      component: () => import("./pages/courses/[courseId]/tee-sets/index.vue"),
      props: withAuth(),
      meta: { title: "Bộ tee" },
    },
    {
      path: "/courses/:courseId/edit-geometry",
      component: () => import("./pages/courses/[courseId]/edit-geometry/index.vue"),
      props: withAuth((route) => ({
        courseId: numParam(route.params.courseId),
        userRoles: getUserRoles(),
      })),
      meta: { title: "Biên tập bản đồ" },
    },
    {
      path: "/courses/:courseId/versions",
      component: () => import("./pages/courses/[courseId]/versions/index.vue"),
      props: withAuth((route) => ({ courseId: numParam(route.params.courseId) })),
      meta: { title: "Phiên bản & Kiểm tra" },
    },
    {
      path: "/courses/:courseId/versions/:versionId/publish",
      component: () =>
        import("./pages/courses/[courseId]/versions/[versionId]/publish/index.vue"),
      meta: { title: "Kiểm tra & Công bố" },
    },
    {
      path: "/courses/:courseId/packages",
      component: () => import("./pages/courses/[courseId]/packages/index.vue"),
      props: withAuth((route) => ({ courseId: numParam(route.params.courseId) })),
      meta: { title: "Lịch sử đóng gói" },
    },

    { path: "/map-editor", redirect: "/facilities" },

    // ─── Operations ──────────────────────────────────────────────────────────
    {
      path: "/pin-positions",
      component: () => import("./pages/pin-positions/index.vue"),
      meta: { title: "Vị trí cờ & Điều kiện sân" },
    },
    {
      path: "/course-conditions",
      component: () => import("./pages/course-conditions/index.vue"),
      meta: { title: "Tình trạng sân" },
    },
    {
      path: "/alerts",
      component: () => import("./pages/alerts/index.vue"),
      meta: { title: "Cảnh báo sân" },
    },
    {
      path: "/corrections",
      component: () => import("./pages/corrections/index.vue"),
      props: withAuth(),
      meta: { title: "Hàng đợi hiệu chỉnh" },
    },
    {
      path: "/admin/data-quality",
      component: () => import("./pages/admin/data-quality/index.vue"),
      props: withAuth(),
      meta: { title: "Chất lượng dữ liệu" },
    },

    // ─── Tournaments ─────────────────────────────────────────────────────────
    {
      path: "/tournaments",
      component: TournamentListPage,
      props: withAuth(),
      meta: { title: "Điều hành giải đấu" },
    },
    {
      path: "/tournament/create",
      component: () => import("./pages/tournament/create.vue"),
      props: withAuth(),
      meta: { title: "Tạo giải đấu" },
    },
    {
      path: "/tournament/:id",
      component: () => import("./pages/tournament/detail.vue"),
      props: withAuth(),
      meta: { title: "Chi tiết giải đấu" },
    },
    {
      path: "/tournament-policies",
      component: () => import("./pages/tournaments/index.vue"),
      props: withAuth(),
      meta: { title: "Chính sách giải đấu" },
    },
    {
      path: "/tournament-policies/:policyId",
      component: () => import("./pages/tournaments/[policyId]/index.vue"),
      props: withAuth((route) => ({
        policyId: String(route.params.policyId),
      })),
      meta: { title: "Chi tiết chính sách" },
    },

    // ─── Admin ───────────────────────────────────────────────────────────────
    {
      path: "/users",
      component: () => import("./pages/users/index.vue"),
      meta: { title: "Người dùng & Vai trò" },
    },
    {
      path: "/market-integrations",
      component: PlaceholderPage(
        "Thị trường & Tích hợp",
        "Quản lý thị trường, đối tác và các kết nối nền tảng.",
      ),
      meta: { title: "Thị trường & Tích hợp" },
    },
  ],
});

export default router;
