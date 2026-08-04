import { createRouter, createWebHistory } from "vue-router";
import FacilitiesPage from "./pages/facilities/index.vue";
import TournamentListPage from "./pages/tournament/list.vue";

const PlaceholderPage = (title: string, description: string) => ({
  template: `<section class="placeholder-page"><div class="eyebrow">GolfOps Portal</div><h2>${title}</h2><p>${description}</p><div class="placeholder-card"><span class="material-symbols-outlined">construction</span><div><strong>Màn hình đang được kết nối</strong><p>Thiết kế và luồng nghiệp vụ đã được xác định theo bộ mockup vận hành.</p></div></div></section>`,
});

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: "/", redirect: "/dashboard" },
    {
      path: "/dashboard",
      component: PlaceholderPage(
        "Tổng quan vận hành",
        "Theo dõi độ tươi dữ liệu, cảnh báo và tình trạng sân.",
      ),
      meta: { title: "Tổng quan vận hành" },
    },
    {
      path: "/facilities",
      component: FacilitiesPage,
      meta: { title: "Cơ sở & Sân golf" },
    },
    { path: "/map-editor", redirect: "/facilities" },
    {
      path: "/pin-positions",
      component: PlaceholderPage(
        "Vị trí cờ",
        "Cập nhật vị trí cờ và trạng thái green theo thời gian thực.",
      ),
      meta: { title: "Vị trí cờ & Điều kiện sân" },
    },
    {
      path: "/course-conditions",
      component: PlaceholderPage(
        "Tình trạng sân",
        "Điều hành tình trạng mặt sân và thông tin vận hành.",
      ),
      meta: { title: "Tình trạng sân" },
    },
    {
      path: "/alerts",
      component: PlaceholderPage(
        "Cảnh báo sân",
        "Phát hành và quản lý cảnh báo an toàn trên sân.",
      ),
      meta: { title: "Cảnh báo sân" },
    },
    {
      path: "/corrections",
      component: () => import("./pages/corrections/index.vue"),
      meta: { title: "Hàng đợi hiệu chỉnh" },
    },
    {
      path: "/admin/data-quality",
      component: () => import("./pages/admin/data-quality/index.vue"),
      meta: { title: "Chất lượng dữ liệu" },
    },
    {
      path: "/tournaments",
      component: TournamentListPage,
      meta: { title: "Điều hành giải đấu" },
    },
    {
      path: "/tournament/create",
      component: () => import("./pages/tournament/create.vue"),
      meta: { title: "Tạo giải đấu" },
    },
    {
      path: "/tournament/:id",
      component: () => import("./pages/tournament/detail.vue"),
      meta: { title: "Chi tiết giải đấu" },
    },
    {
      path: "/users",
      component: PlaceholderPage(
        "Người dùng & Vai trò",
        "Quản lý người dùng và phân quyền vận hành.",
      ),
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
