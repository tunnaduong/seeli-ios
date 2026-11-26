# SEELI — iOS (SwiftUI)

*See more. Live more.*

## Chạy app
```bash
brew install xcodegen   # nếu chưa có
xcodegen generate
open Seeli.xcodeproj
```
Chọn iPhone simulator → Run. iOS 17+.

## Cấu trúc
| Thư mục | Nội dung |
|---|---|
| `Seeli/App` | Entry point, điều hướng (NavigationStack + `Route`) |
| `Seeli/Core` | `AppStore` (state + lưu JSON), models, đa ngôn ngữ `L10n`, định dạng ngày (lịch Reiwa, số kanji), camera/vị trí/thông báo/QR |
| `Seeli/Components` | Header, thẻ, `VerticalText` (chữ dọc 縦書き), tranh phong cảnh |
| `Seeli/Screens` | Tất cả màn hình |
| `Seeli/Resources/{vi,ja}.lproj` | Chuỗi tiếng Việt / tiếng Nhật |

## Đa ngôn ngữ
- Đổi ngôn ngữ ngay trong app (màn Login hoặc Settings), không cần đổi ngôn ngữ máy.
- Thêm ngôn ngữ mới: thêm case vào `AppLanguage`, tạo `xx.lproj/Localizable.strings`, thêm vào `knownRegions` trong `project.yml`.
- Ghi chú (note) toàn chữ Nhật/Hán sẽ hiển thị **chữ dọc**; chữ Latin (tiếng Việt) hiển thị ngang bằng font serif.

## Backend
- App dùng API ở repo `../seeli-api` (Node + SQLite, deploy bằng Docker trên aaPanel).
- Địa chỉ mặc định: build setting `SEELI_API_URL` trong `project.yml` (hiện là `https://api.seeli.cam`). Có thể đổi trong app: **Settings → Máy chủ**.
- Token đăng nhập lưu trong Keychain; dữ liệu được cache (`Documents/seeli-cache.json`) để mở app nhanh và xem offline.
- Ảnh chụp khi mất mạng nằm trong hàng chờ (`Documents/outbox/`) và tự tải lên khi có mạng.
- Kết bạn bằng mã mời 8 ký tự trong QR (Profile → biểu tượng QR).
- Simulator không có camera → nút chụp tạo ảnh giả lập.
- **Chế độ demo** (Settings): ảnh chụp sau khi bật sẽ “quay lại” sau ~1 phút (server phải bật `ALLOW_DEMO=true`).

## Widget
Target `SeeliWidget` (WidgetKit), dữ liệu chia sẻ qua App Group `group.com.tunnaduong.seeli` (`Shared/WidgetData.swift`). Widget chỉ nhận chữ, ngày và số đếm — không bao giờ nhận ảnh.
- **Hôm nay** (nhỏ / vừa): câu hỏi + nút chụp, số ảnh đang ngủ yên; chuyển sang “Một khoảnh khắc đã quay lại” đúng lúc ảnh đến hạn.
- **Lời của ngày hôm ấy** (nhỏ / vừa): một ghi chú cũ, đổi mỗi 3 giờ; chữ dọc nếu là tiếng Nhật.
- **Màn hình khóa** (tròn / chữ nhật / một dòng): nhắc nhìn thế giới, báo khi ảnh quay lại. Không hiện ghi chú để giữ riêng tư.
- Deep link: `seeli://camera`, `seeli://memories`, `seeli://reunion`.

## Việc tiếp theo
- Push notification từ server (khi bạn bè gửi góc nhìn).
- Bản Android (Jetpack Compose) dùng cùng cấu trúc màn hình và file chuỗi.
