SET QUOTED_IDENTIFIER ON;

USE NhaMangDW;

GO

SET NOCOUNT ON;

DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS;

IF EXISTS(SELECT 1 FROM rpt.vw_DoiSoat_TonKho WHERE SoLuongCuoiKy IS NULL OR SoLuongDauKy+SoLuongNhap-SoLuongXuat<>SoLuongCuoiKy) THROW 52000,'Stock mismatch',1;

IF EXISTS(SELECT 1 FROM dbo.Dim_SanPham a JOIN dbo.Dim_SanPham b ON a.MaSanPhamNghiepVu=b.MaSanPhamNghiepVu AND a.SanPhamID<b.SanPhamID AND a.NgayHieuLuc<b.NgayHetHieuLuc AND b.NgayHieuLuc<a.NgayHetHieuLuc) THROW 52000,'SCD overlap',1;

IF EXISTS(SELECT MaSanPhamNghiepVu FROM dbo.Dim_SanPham GROUP BY MaSanPhamNghiepVu HAVING SUM(CONVERT(int,HienHanh))<>1) THROW 52000,'SCD current uniqueness',1;

DECLARE @n bigint=(SELECT COUNT(*) FROM dbo.Fact_BanHang)+(SELECT COUNT(*) FROM dbo.Fact_MuaHang)+(SELECT COUNT(*) FROM dbo.Fact_TonKho);

EXEC etl.usp_NapDuLieu; EXEC etl.usp_NapDuLieu @NapLai=1;

IF @n<>(SELECT COUNT(*) FROM dbo.Fact_BanHang)+(SELECT COUNT(*) FROM dbo.Fact_MuaHang)+(SELECT COUNT(*) FROM dbo.Fact_TonKho) THROW 52000,'Rerun changed facts',1;

EXEC rpt.usp_DoiChieu_BanHang_TonKho;

IF EXISTS(SELECT 1 FROM dbo.Fact_MuaHang f JOIN dbo.Dim_SanPham p ON p.SanPhamID=f.SanPhamID JOIN dbo.Dim_ThoiGian d ON d.ThoiGianID=f.ThoiGianID WHERE d.Ngay<p.NgayHieuLuc OR d.Ngay>=p.NgayHetHieuLuc) THROW 52000,'Temporal FK Purchase mismatch',1;

IF EXISTS(SELECT 1 FROM dbo.Fact_BanHang f JOIN dbo.Dim_SanPham p ON p.SanPhamID=f.SanPhamID JOIN dbo.Dim_ThoiGian d ON d.ThoiGianID=f.ThoiGianID WHERE d.Ngay<p.NgayHieuLuc OR d.Ngay>=p.NgayHetHieuLuc) THROW 52000,'Temporal FK Sales mismatch',1;

IF EXISTS(SELECT 1 FROM dbo.Fact_TonKho f JOIN dbo.Dim_SanPham p ON p.SanPhamID=f.SanPhamID JOIN dbo.Dim_ThoiGian d ON d.ThoiGianID=f.ThoiGianID WHERE d.Ngay<p.NgayHieuLuc OR d.Ngay>=p.NgayHetHieuLuc) THROW 52000,'Temporal FK Inventory mismatch',1;

PRINT N'Kiểm tra thành công: repeatable invariants';

GO

