# NhaMangDW — Hệ thống kho dữ liệu nhà mạng

Mã nguồn nguồn OLTP, ETL bằng T-SQL, cube SSAS Multidimensional và giao diện hai vai trò. Có bộ triển khai vào môi trường mới cùng bộ sinh dữ liệu mô phỏng; không cần khôi phục .bak/.abf.

## Thành phần

| Đường dẫn | Nội dung |
|---|---|
| CaiDat.cmd, scripts/TrienKhai.ps1 | Kiểm tra điều kiện, tạo mới hai database, sinh mẫu, ETL, cấp quyền nguồn cube, triển khai/process SSAS |
| sql/NhaMangDW.sql | 37 bảng kho, khóa, chỉ mục, view, function và thủ tục ETL, đã sắp thứ tự đối tượng phụ thuộc |
| oltp/NhaMangOLTP.sql | 17 bảng nguồn và thủ tục nghiệp vụ thuê bao, gói, sử dụng, tiền, hóa đơn |
| data | Ba script sinh danh mục/giao dịch mới, không trích dữ liệu thuê bao hoặc giao dịch từ hệ thống đang có |
| ssas | Solution Visual Studio, 7 dimension, 4 nhóm số đo, DSV, partition, calculation và XMLA |
| demo | Python server, PowerShell đọc/ghi nghiệp vụ và HTML/CSS/JavaScript |
| scripts | Cấu hình kết nối, ETL, process và đối soát được menu quản trị gọi |
| reports | 14 truy vấn MDX cho các thao tác phân tích |
| cau-hinh.mau.json | Mẫu cấu hình; cấu hình riêng khi cài thành công ghi vào cau-hinh.local.json và không đưa vào Git |

## Chuẩn bị máy mới

- Windows 64-bit, Windows PowerShell 5.1 64-bit, Python 3 (máy kiểm chứng dùng 3.12).
- SQL Server 2022 hoặc mới hơn. Tài khoản Windows chạy bộ cài cần quyền tạo database, tạo login/user và cấp quyền đọc cho dịch vụ SSAS; khi kiểm chứng dùng Windows Authentication với quyền quản trị SQL.
- Analysis Services cài chế độ **Multidimensional**, tài khoản chạy bộ cài có quyền quản trị instance SSAS. SQL Server Express không bao gồm SSAS; cần cài SSAS riêng.
- Provider OLE DB 64-bit tương thích `MSOLEDBSQL.1` mà Data Source của project sử dụng.
- Thư viện AMO và ADOMD.NET. Bộ cài tự tìm tại các vị trí SQL Server/SSMS thông dụng; nếu không tìm được, truyền `-AMOPath` và `-ADOMDPath` trỏ đến DLL tương ứng. Có thể dùng SSMS 21 như máy phát triển. Không chép DLL Microsoft vào repository này.
- Visual Studio với Analysis Services Projects nếu cần xem thiết kế/Build; không bắt buộc dùng Visual Studio để chạy bộ cài XMLA.

Bộ cài triển khai ứng dụng/dữ liệu, không tự cài các sản phẩm SQL Server, SSAS, provider hoặc Python. Dữ liệu mẫu và mã nguồn đều nhỏ, không chứa bản backup hay mật khẩu phiên.

## Cài mới toàn hệ thống

Chỉ dùng trên instance **chưa có** NhaMangOLTP, NhaMangDW và NhaMangDW_OLAP. Mở PowerShell tại thư mục có README này.

Kiểm tra điều kiện trước, chưa tạo/nạp:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\TrienKhai.ps1 -ChiKiemTra
```

Nếu SQL ở localhost, SSAS là instance SSAS2022 và tài khoản dịch vụ SSAS là NT SERVICE\MSOLAP$SSAS2022, chạy:

```powershell
.\CaiDat.cmd
```

Hoặc chỉ định đúng máy và tài khoản dịch vụ thực tế:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\TrienKhai.ps1 -SQLServer 'localhost' -SSASServer 'localhost\SSAS2022' -TaiKhoanDichVuSSAS 'NT SERVICE\MSOLAP$SSAS2022'
```

Với SSAS default instance, máy chủ có thể là `localhost` và tài khoản dịch vụ có thể là `NT SERVICE\MSSQLServerOLAPService`; kiểm tra cấu hình dịch vụ thực tế thay vì dùng tên ví dụ. Dùng một instance SQL duy nhất cho nguồn và kho vì có tham chiếu chéo hai database. Tài khoản dịch vụ SSAS phải truy cập được SQL Server; khi khác máy cần tài khoản Windows/domain và cấu hình mạng phù hợp.

Khi thành công, bộ cài ghi `cau-hinh.local.json`. Mở `demo/Mo_Demo.cmd`, đặt mật khẩu phiên cho `quantri` và `nhanvien`, truy cập http://127.0.0.1:8765. Chọn tháng 09 hoặc 10/2026 rồi bấm **Xem báo cáo**. Khi cập nhật mã, dừng demo cũ bằng Ctrl+C và mở lại trước khi tải trang.

Nếu chỉ có SQL, có thể dùng `-ChiSQL`: tạo nguồn/kho, sinh mẫu và ETL, **chưa có cube**. Sau đó cần cấu hình quyền nguồn và dùng `scripts/build-cube.ps1 -Deploy` trên đích SSAS chưa tồn tại để triển khai/process cube. Các menu cube chỉ hoạt động sau bước này.

## Máy đã có hệ thống

Không chạy bộ cài hoặc ba script dữ liệu lên database đang có. Sao chép `cau-hinh.mau.json` thành `cau-hinh.local.json`, sửa kết nối theo hệ thống hiện tại rồi mở `demo/Mo_Demo.cmd`. Giữ nguyên dữ liệu cũ.

Cấu hình gồm SQLServer, KhoDuLieu, NguonOLTP, SSASServer, DatabaseSSAS và đường dẫn DLL tùy chọn. Không lưu mật khẩu; SQL/SSAS dùng Windows Authentication. Có thể đặt biến môi trường `NMDW_CONFIG` trỏ đến một tệp cấu hình riêng, hữu ích khi thử một môi trường khác.

Nếu muốn cài độc lập trên cùng instance, bộ cài hỗ trợ `-KhoDuLieu`, `-NguonOLTP`, `-DatabaseSSAS` với tên mới và `-TepCauHinh` trỏ đến tệp chưa tồn tại. Tên database chỉ nhận chữ Latin, số và gạch dưới. Bộ cài đổi đúng định danh tham chiếu database và Data Source của bản cube mới, giữ tên cube NhaMangDW và các bảng/cột nghiệp vụ. Project Visual Studio vẫn dùng mẫu kết nối ban đầu; sửa Data Source/Deployment nếu mở một môi trường có tên khác.

## Dữ liệu mẫu

Dữ liệu được sinh mới bằng công thức xác định, không xuất từ database đang vận hành. Có 126 khách hàng tên mô phỏng, 378 thuê bao số DEMO-xxxxxx, ba nhà mạng, 63 tỉnh lịch sử tại 31/12/2024 chia Bắc25/Trung19/Nam19, 63 kho, sáu biểu giá thoại/data mô phỏng và chín gói công bố lưu tham khảo tại 11/11/2026.

Có 7.560 cuộc gọi + 7.560 phiên Internet trong tháng 09–10/2026, 756 đăng ký, 378 lượt nạp, 378 hóa đơn và thanh toán đủ/một phần. Các nghiệp vụ tiền được sinh qua procedure thật để giữ số dư và sổ cái nhất quán. Nếu nhập sử dụng ngoài kỳ mẫu, cần đăng ký gói có hiệu lực tại thời điểm sử dụng; không tự kéo dài các đăng ký cũ. Giá 800 VND/phút và 20 VND/MB là giả định mô phỏng; các gói tham khảo không tự thành biểu giá, quota hoặc phí tháng.

Kho nạp 7.686 dòng mua, 7.686 dòng bán, 11.529 snapshot tồn và 15.120 dòng cước qua ETL thật. SP001 có hai phiên bản để minh họa SCD Type 2. Tồn kho vẫn dùng LastChild, tỷ lệ chia tổng tiền/tổng lượng; không cộng tiền nạp/thanh toán vào doanh thu cước. Đây là bộ mẫu riêng, **số liệu không bằng bộ dữ liệu của bài tiểu luận trước đó**.

## Bảo toàn và giới hạn

Bộ cài chặn trước khi tạo nếu database SQL/SSAS đích hoặc tệp cấu hình đích đã tồn tại. Không DROP database, không RESTORE đè, không seed lại, không sửa DuAnCu/NhaMang_DW. Nếu một bước tạo mới bị lỗi, phần đã tạo được giữ để chẩn đoán; không tự chạy lại seed hoặc cố ghi đè. Xem lỗi và xử lý trong môi trường mới riêng.

Các script KiemTra_SQL.sql, DoiSoat_Cuoc.ps1 và verify-cube.ps1 là chức năng đối soát của menu quản trị. Kết quả ghi vào evidence/ và reports/*.csv, đã loại bằng .gitignore; không phải dữ liệu mẫu cần tải lên.

Bộ cài đầy đủ đã được thực thi trên môi trường riêng cùng máy phát triển: SQL/ETL, process cube, 14 MDX, đối soát 11 chỉ tiêu cước mỗi tháng và 11 kiểm tra HTTP giao diện. Có kiểm tra khóa, tài chính, hash bốn fact trước/sau replay và chặn seed lại. Chưa kiểm chứng cài từ đầu trên một máy Windows khác hoặc thao tác kéo thả GUI mới trong SSAS Browser; không coi kết quả trên máy phát triển là đã kiểm tra mọi cấu hình Windows.
