# VSP — Vietnam Smart Golf Platform

Nền tảng golf thông minh cho thị trường Việt Nam: ứng dụng cho golfer, portal vận hành cho đơn vị quản lý sân, backend đa dịch vụ, và một pipeline thị giác máy tính bóc tách hình học sân từ ảnh vệ tinh. Toàn bộ là một **monorepo** — API, web, mobile, thư viện dùng chung, hạ tầng và tài liệu nằm cùng một chỗ để hợp đồng dữ liệu không lệch nhau.

> Giao diện người dùng bằng **tiếng Việt**. Tài liệu kỹ thuật và mã nguồn dùng thuật ngữ tiếng Anh.

---

## Mục lục

- [Kiến trúc tổng quan](#kiến-trúc-tổng-quan)
- [Cấu trúc monorepo](#cấu-trúc-monorepo)
- [Các ứng dụng](#các-ứng-dụng)
- [Thư viện dùng chung](#thư-viện-dùng-chung-packages)
- [Dịch vụ thị giác máy tính](#dịch-vụ-thị-giác-máy-tính-servicesgolf-vision)
- [Công nghệ](#công-nghệ)
- [Bắt đầu phát triển](#bắt-đầu-phát-triển)
- [Kiểm thử](#kiểm-thử)
- [CI/CD](#cicd)
- [Triển khai](#triển-khai)
- [Quy ước & đóng góp](#quy-ước--đóng-góp)
- [Trạng thái dự án](#trạng-thái-dự-án)

---

## Kiến trúc tổng quan

```
┌──────────────┐     ┌──────────────┐     ┌────────────────────┐
│  Mobile app  │     │ GolfOps      │     │  golf-vision       │
│  (Flutter)   │     │ Portal (Vue) │     │  (PyTorch/U-Net)   │
│  golfer      │     │ vận hành sân │     │  bóc tách sân       │
└──────┬───────┘     └──────┬───────┘     └─────────┬──────────┘
       │  REST/JSON         │  REST/JSON            │ /trace/hole
       └──────────┬─────────┘                       │
                  ▼                                  │
        ┌───────────────────────┐                   │
        │   API (Spring Boot)   │◄──────────────────┘
        │   28 module nghiệp vụ │
        └───────┬───────────────┘
                │
     ┌──────────┼───────────┐
     ▼          ▼           ▼
┌─────────┐ ┌───────┐ ┌──────────┐
│Postgres │ │ Redis │ │ (S3 sao  │
│+ PostGIS│ │       │ │  lưu)     │
└─────────┘ └───────┘ └──────────┘
```

Hợp đồng dữ liệu giữa các thành phần được định nghĩa một lần trong `packages/contracts` (OpenAPI) và dùng chung cho cả API, portal lẫn mobile.

---

## Cấu trúc monorepo

| Thư mục | Nội dung |
|---|---|
| `apps/api` | Backend Spring Boot — 28 module nghiệp vụ |
| `apps/portal` | GolfOps Portal — web vận hành sân (Vue 3) |
| `apps/mobile` | Ứng dụng golfer (Flutter) |
| `apps/watch_apple`, `apps/wear-os` | App đồng hồ — **đã descope**, chưa dùng được |
| `packages/contracts` | Đặc tả OpenAPI + schema dùng chung |
| `packages/course-package` | Định dạng gói dữ liệu sân dùng offline |
| `packages/domain` | Model/logic miền dùng chung |
| `packages/design-tokens`, `map-style`, `mobile-theme`, `portal-ui` | Token thiết kế, style bản đồ, theme, UI kit |
| `services/golf-vision` | Pipeline segmentation ảnh vệ tinh (GolfSeg) |
| `infra/` | docker-compose, migration, script vận hành |
| `docs/` | Tài liệu kiến trúc, yêu cầu, kế hoạch |
| `.github/workflows/` | CI cho api / portal / mobile / secrets |

---

## Các ứng dụng

### `apps/api` — Backend (Spring Boot)

REST API là trung tâm của hệ thống. **Spring Boot 3.2.5 / Java 21**, PostgreSQL + **PostGIS** cho dữ liệu không gian, **Redis** cho cache & rate-limit, **Flyway** quản lý schema.

Xác thực bằng **JWT** (access token ngắn hạn + refresh token xoay vòng), đăng nhập xã hội **Google/Apple** với xác minh chữ ký JWKS đầy đủ. Phân quyền theo vai trò admin, tra vai trò từ DB mỗi request để thu hồi quyền có hiệu lực ngay.

28 module nghiệp vụ:

```
ai · audit · bag · booking · correction · course · coursealert
dataquality · geometry · geospatial · identity · loyalty · market
membership · notification · operations · package · payment
performance · privacy · profile · role · round · score · shot
sponsorship · tournament · weather
```

### `apps/portal` — GolfOps Portal (Vue 3)

Web nội bộ cho đơn vị vận hành sân: quản lý cơ sở/sân/hố, biên tập hình học, công bố phiên bản dữ liệu sân, hàng đợi hiệu chỉnh (correction), giải đấu, người dùng & vai trò, tích hợp thị trường.

**Vue 3.5 + Vite 7 + vue-router 4 + maplibre-gl 4**, TypeScript, Vitest. Có test `vietnamese-ui` chặn chuỗi tiếng Anh lọt vào giao diện. Bản đồ dùng MapLibre GL. Chạy sau nginx (reverse-proxy `/api` cùng origin nên không cần CORS).

### `apps/mobile` — Ứng dụng golfer (Flutter)

Ứng dụng cho người chơi: vòng đấu & thẻ điểm, bản đồ hố (green/fairway/bunker), đo khoảng cách & mục tiêu, thời tiết, caddie, phân tích strokes-gained, chơi offline-first (đồng bộ khi có mạng).

**Flutter + flutter_bloc**, MapLibre GL, `flutter_secure_storage` cho token (Keystore/Keychain). Nhiều nhóm tính năng:

```
analytics · auth · bag · basemap · caddie · contributors · correction
course_detail · course_search · games · ghost · hole_history · hole_map
measure · performance · play · privacy · profile · round · round_setup
score_display · scorecard · settings · strategy · target · weather
```

---

## Thư viện dùng chung (`packages/`)

- **`contracts`** — Đặc tả **OpenAPI** (`openapi.yaml`) + schema theo miền (`schemas/*.yaml`). Nguồn sự thật duy nhất cho hợp đồng API; enum và shape ở đây phải khớp với cả server lẫn client.
- **`course-package`** — Định dạng gói dữ liệu sân tải về máy để dùng khi mất mạng (hình học green/fairway/bunker theo hố).
- **`domain`** — Model & logic miền dùng chung.
- **`design-tokens` / `map-style` / `mobile-theme` / `portal-ui`** — Token thiết kế, style bản đồ MapLibre, palette/theme mobile, và UI kit cho portal.

---

## Dịch vụ thị giác máy tính (`services/golf-vision`)

**GolfSeg** — pipeline PyTorch bóc tách hình học sân (green, fairway, bunker, tee, nước, OB…) từ ảnh vệ tinh, để dựng bản đồ hố tự động.

- Kiến trúc **U-Net + encoder** (ResNet), suy luận theo cửa sổ trượt (tile 512px, blend Gaussian, TTA 8 view).
- Huấn luyện với corpus ảnh OSM Mỹ + fine-tune sân Việt Nam; loss = CE (median-freq) + Dice + Lovász.
- API `/trace/hole` được backend gọi qua tunnel nội bộ để sinh hình học cho một hố.

> ⚠️ **RESEARCH ONLY** — checkpoint hiện tại fine-tune trên ảnh Esri; thương mại hoá cần nguồn ảnh Việt Nam có giấy phép. Chi tiết ở `services/golf-vision/FINDINGS.md`.

---

## Công nghệ

| Lớp | Công nghệ |
|---|---|
| Backend | Spring Boot 3.2.5, Java 21, PostgreSQL + PostGIS, Redis, Flyway |
| Web | Vue 3.5, Vite 7, TypeScript, vue-router 4, MapLibre GL 4, Vitest |
| Mobile | Flutter, flutter_bloc, MapLibre GL, flutter_secure_storage |
| CV | Python, PyTorch, segmentation-models-pytorch, timm |
| Hạ tầng | Docker Compose, OpenTelemetry Collector, Cloudflare (edge/TLS) |
| Hợp đồng | OpenAPI 3 (`packages/contracts`) |

---

## Bắt đầu phát triển

Yêu cầu: **JDK 21**, **Node 22+**, **Flutter (stable)**, **Docker**.

### 1. Hạ tầng phụ trợ (Postgres + Redis)

```bash
cd infra/docker
docker compose up -d postgres redis
```

### 2. API

```bash
cd apps/api
mvn -o spring-boot:run -Dspring-boot.run.profiles=dev
# API chạy ở http://localhost:8080
```

> Profile `dev` đã có sẵn khoá JWT mặc định (chỉ dùng local). Staging/prod **bắt buộc** cung cấp `JWT_SECRET` (≥ 256-bit) qua biến môi trường.

### 3. Portal

```bash
cd apps/portal
npm ci
npm run dev          # http://localhost:5173, proxy /api → :8080
```

### 4. Mobile

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define=VSP_API_BASE_URL=http://localhost:8080
```

> `VSP_API_BASE_URL` là hằng số compile-time; build thiếu nó sẽ trỏ về localhost. Google Sign-in cần thêm `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`. Xem `apps/mobile/scripts/release.sh` cho build phát hành.

---

## Kiểm thử

| Thành phần | Lệnh |
|---|---|
| API (JUnit 5 + Mockito) | `cd apps/api && mvn -B test` |
| API — schema Flyway khớp entity | `mvn -B test -Dtest=FlywaySchemaMatchesEntityModelTest` |
| Portal (Vitest) | `cd apps/portal && npm test` |
| Portal — lint / type | `npm run lint && npm run typecheck` |
| Mobile (unit + widget) | `cd apps/mobile && flutter test` |
| Mobile — E2E trên thiết bị/simulator | `flutter test integration_test -d <device>` |

Bộ tour ảnh của mobile (`scripts/tour.sh`, `scripts/sale_kit.sh`) cycle simulator và cấp quyền vị trí trước khi chạy — cần thiết để ảnh chụp không bị "kẹt surface" trên iOS simulator.

---

## CI/CD

GitHub Actions, tách theo thành phần:

| Workflow | Chạy gì |
|---|---|
| `ci-api.yml` | validate → compile → test → OWASP dependency-check → package; kiểm Flyway ↔ entity |
| `ci-portal.yml` | `npm ci` → format → lint → typecheck → test → build |
| `ci-mobile.yml` | `flutter pub get` → analyze → test (ma trận OS) |
| `ci-secrets.yml` | quét lộ secret |

---

## Triển khai

- **API** & **Portal** chạy bằng Docker sau **Cloudflare** (TLS ở biên). Portal serve tĩnh bằng nginx và reverse-proxy `/api` sang container API (cùng origin).
- **Postgres, Redis** và các dịch vụ phụ trợ (OpenTelemetry Collector, backup pg_dump định kỳ) khai báo trong `infra/docker/docker-compose.yaml`.
- Migration schema do **Flyway** áp khi API khởi động.

> Thông tin máy chủ, khoá và quy trình phát hành cụ thể **không** nằm trong README này — xem `SECRETS_POLICY.md` và tài liệu vận hành nội bộ.

---

## Quy ước & đóng góp

- **Hợp đồng trước hết**: đổi shape/enum của API thì sửa `packages/contracts` trước, rồi mới đến server và client — ba nơi phải khớp.
- **Giao diện tiếng Việt**: chuỗi hiển thị cho người dùng phải tiếng Việt; portal có test chặn tiếng Anh lọt vào UI.
- **Thay đổi nhỏ nhất, verify trước khi báo xong** — xem `AGENTS.md`.
- Repo được index bởi **GitNexus**; xem `CLAUDE.md` cho quy trình phân tích tác động (impact) trước khi sửa symbol.

---

## Trạng thái dự án

Đang phát triển tích cực. Ba ứng dụng chính (API, portal, mobile) hoạt động end-to-end. Một số điểm cần biết:

- **App đồng hồ** (`watch_apple`, `wear-os`) — đã descope, chưa dùng được.
- **golf-vision** — checkpoint hiện tại là **RESEARCH ONLY** (ảnh Esri), cần nguồn ảnh có phép trước khi thương mại hoá.
- Xem `docs/completion-plan.md` cho đánh giá đầy đủ và các hạng mục còn lại.

---

<sub>VNPT-IT · Vietnam Smart Golf Platform</sub>
