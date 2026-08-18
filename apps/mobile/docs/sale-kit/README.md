# Bộ ảnh giới thiệu VSP Golf

29 màn hình chụp từ một vòng 18 hố có thật, chơi từ đầu đến cuối trên iPhone 17
Pro tại **Long Biên Golf Course — Đường A → Đường B**.

Không phải ảnh dựng. Ứng dụng thật, máy chủ thật (`vps-api.vnteki.com`), dữ liệu
sân thật, và golfer **đi bộ** qua đủ 18 hố: toạ độ GPS của máy ảo được dời theo
từng hố, nên tính năng tự nhận diện hố hoạt động đúng như ngoài sân.

## Vì sao là Long Biên

Đường A và Đường B là hai đường duy nhất trong cơ sở dữ liệu có gói dữ liệu đủ
**bảy lớp** — tee, fairway, green, bunker, hồ nước, rough, đường xe điện — nên
đây là nơi bản đồ vẽ ra trông giống golf thay vì hai chấm tròn. Ghép lại, đó
cũng là vòng 18 hố thật sự duy nhất mà ứng dụng có.

## Chụp lại bộ ảnh

```
scripts/sale_kit.sh <simulator-udid>          # bản tối (mặc định)
VSP_KIT_THEME=light scripts/sale_kit.sh <udid>  # bản sáng
xcrun simctl list devices available            # để lấy udid
```

Script tự khởi động lại máy ảo (bề mặt đồ hoạ của một máy ảo cũ không vẽ lại,
ảnh sẽ giống hệt nhau mà vẫn báo thành công), đặt vị trí golfer, và chỉ chép ảnh
vào kho khi cả lượt chạy đi tới cuối.

## Thứ tự câu chuyện

| Ảnh | Màn hình |
|---|---|
| `01-welcome` | Màn hình mở đầu |
| `03-home` | Trang chủ sau khi đăng nhập |
| `04-courses` | Tìm sân golf — 62 câu lạc bộ |
| `05-course-detail` | Trang của câu lạc bộ |
| `06-play` | Tab Chơi golf |
| `07-round-setup` | Tạo vòng đấu |
| `08-course-picker` | Chọn sân, có tìm kiếm tiếng Việt |
| `09-choose-the-round` | **Chọn vòng chơi** — 9 cách chơi câu lạc bộ này |
| `09b-start-hole` | Chọn hố xuất phát |
| `10-ready-to-start` | Vòng đấu đã sẵn sàng |
| `11-scorecard-hole-1` | Thẻ điểm, hố 1 |
| `12-satellite` | Ảnh vệ tinh hố 1, đóng khung đúng hố |
| `13-course-map` | Bản đồ vẽ — bảy lớp dữ liệu |
| `14-target` | Mục tiêu — cự ly tới điểm đã chọn |
| `15-conditions` | Điều kiện sân và thời tiết |
| `16-score-entry` | Nhập điểm |
| `17-hole-01-card` | Hố 1 |
| `17-hole-09-card` | Hố 9 — hết vòng ngoài |
| `17-hole-10-card` | Hố 10 — chuyển sang Đường B |
| `18-hole-10-map` | Ảnh vệ tinh hố 10 |
| `19-hole-10-course-map` | Bản đồ vẽ hố 10 |
| `17-hole-18-card` | Hố 18 |
| `20-finish-confirm` | Xác nhận kết thúc |
| `21-round-summary` | **Tổng kết vòng đấu** — có phần tổng kết do AI viết để chia sẻ |
| `22-round-history` | Lịch sử vòng đấu |
| `23-profile` | Hồ sơ golfer |
| `24-more` | Menu Thêm |
| `25-bag` | Túi gậy |
| `26-settings` | Cài đặt |

## Lưu ý khi dùng

- Huy hiệu **"Chờ đồng bộ" / "Đã lưu ngoại tuyến"** trên màn tổng kết là đúng
  chức năng, không phải lỗi: điểm được ghi xuống máy trước, đồng bộ sau. Nếu
  cần ảnh không có huy hiệu này thì chụp lại sau khi hàng đợi đã đẩy lên.
- Ảnh vệ tinh hiện lấy từ Esri. Bản quyền cho mục đích thương mại **chưa được
  xác lập** — xem `lib/features/basemap/domain/satellite_imagery_config.dart`.
  Cần chốt trước khi đưa ảnh vệ tinh vào tài liệu bán hàng.
- Tổng gậy trong bộ ảnh này chưa cộng đủ cả 18 hố (xem ghi chú trong
  `integration_test/sale_kit_test.dart`): lượt chạy tự động nhập điểm nhanh hơn
  nhịp lưu của ứng dụng. Trên máy thật, thẻ điểm cộng đủ.
