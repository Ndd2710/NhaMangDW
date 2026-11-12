SET NOCOUNT ON;SET XACT_ABORT ON;SET QUOTED_IDENTIFIER ON;
IF EXISTS(SELECT 1 FROM erp.LichSu_SanPham) OR EXISTS(SELECT 1 FROM dbo.Dim_ThoiGian) THROW 57002,N'Kho khong trong; khong seed lai.',1;
BEGIN TRAN;
SET IDENTITY_INSERT dbo.Dim_SanPham ON;
INSERT dbo.Dim_SanPham(SanPhamID,MaSanPhamNghiepVu,TenSanPham,NhomSanPham,NgayHieuLuc,NgayHetHieuLuc,HienHanh) VALUES(-1,'UNKNOWN',N'Không rõ',N'Không rõ','19000101','99991231',1);
SET IDENTITY_INSERT dbo.Dim_SanPham OFF;
SET IDENTITY_INSERT dbo.Dim_KhoHang ON;
INSERT dbo.Dim_KhoHang(KhoHangID,MaKhoHangNghiepVu,TenKhoHang,TenTinh,Vung) VALUES(-1,'UNKNOWN',N'Không rõ',N'Không rõ',N'Không rõ');
SET IDENTITY_INSERT dbo.Dim_KhoHang OFF;
INSERT dbo.Dim_ThoiGian(ThoiGianID,Ngay,Nam,MaQuy,TenQuy,MaThang,TenThang) VALUES(-1,NULL,0,0,N'Không rõ',0,N'Không rõ');
INSERT erp.LichSu_SanPham VALUES('SP001','20260901',N'SIM trả trước',N'SIM'),('SP002','20260901',N'Thẻ cào 100.000',N'Thẻ cào'),('SP003','20260901',N'Thẻ dự phòng',N'Dự phòng'),('SP001','20261001',N'SIM trả trước phiên bản tháng 10',N'SIM');
INSERT erp.KhoHang SELECT h.MaKhoHang,h.TenKhoHang,k.TenTinh,k.Vung FROM NhaMangOLTP.dbo.KhoHang h JOIN NhaMangOLTP.dbo.KhuVuc k ON k.KhuVucID=h.KhuVucID;
INSERT wms.TonKho_DauKy SELECT p.MaSanPhamNghiepVu,k.MaKhoHangNghiepVu,'20260831',100 FROM (SELECT DISTINCT MaSanPhamNghiepVu FROM erp.LichSu_SanPham)p CROSS JOIN erp.KhoHang k;
INSERT etl.AnhXa_SanPham SELECT s.HeThongNguon,p.MaSanPhamNghiepVu,p.MaSanPhamNghiepVu FROM (VALUES('ERP'),('POS'),('WMS'))s(HeThongNguon) CROSS JOIN (SELECT DISTINCT MaSanPhamNghiepVu FROM erp.LichSu_SanPham)p;
INSERT etl.AnhXa_KhoHang SELECT s.HeThongNguon,k.MaKhoHangNghiepVu,k.MaKhoHangNghiepVu FROM (VALUES('ERP'),('POS'),('WMS'))s(HeThongNguon) CROSS JOIN erp.KhoHang k;
INSERT etl.Moc_NapDuLieu(HeThongNguon,DongNguonCuoiID) VALUES('ERP',0),('POS',0),('WMS',0),('CUOC',0);
DECLARE @d date='20260901',@n int=1;
WHILE @d<='20261031'
BEGIN
 INSERT erp.ChiTiet_MuaHang(SoChungTu,SoThuTuDong,NgayGoc,MaSanPhamNguon,MaKhoHangNguon,SoLuongGoc,DonGiaGoc)
 SELECT CONCAT('MH',CONVERT(char(8),@d,112),k.MaKhoHangNghiepVu),p.stt,CONVERT(char(8),@d,112),p.ma,k.MaKhoHangNghiepVu,'10',p.gia FROM (VALUES(1,'SP001','15000.00'),(2,'SP002','90000.00'))p(stt,ma,gia) CROSS JOIN erp.KhoHang k;
 INSERT pos.ChiTiet_BanHang(SoChungTu,SoThuTuDong,NgayGoc,MaSanPhamNguon,MaKhoHangNguon,SoLuongGoc,DonGiaGoc)
 SELECT CONCAT('BH',CONVERT(char(8),@d,112),k.MaKhoHangNghiepVu),p.stt,CONVERT(char(10),@d,103),p.ma,k.MaKhoHangNghiepVu,p.sl,p.gia FROM (VALUES(1,'SP001','3','20000,00'),(2,'SP002','4','100000,00'))p(stt,ma,sl,gia) CROSS JOIN erp.KhoHang k;
 INSERT wms.Chot_TonKho(SoChungTu,SoThuTuDong,NgayGoc,MaSanPhamNguon,MaKhoHangNguon,SoLuongGoc,DonGiaGoc)
 SELECT CONCAT('TK',CONVERT(char(8),@d,112),k.MaKhoHangNghiepVu),p.stt,CONVERT(char(10),@d,23),p.ma,k.MaKhoHangNghiepVu,CONVERT(varchar,100+@n*p.tang),'0' FROM (VALUES(1,'SP001',7),(2,'SP002',6),(3,'SP003',0))p(stt,ma,tang) CROSS JOIN erp.KhoHang k;
 SET @d=DATEADD(day,1,@d);SET @n+=1;
END;
COMMIT;
