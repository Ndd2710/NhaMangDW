-- Sinh 126 khach hang, 378 thue bao, 15120 giao dich moi hoan toan gia lap.
IF EXISTS(SELECT 1 FROM dbo.KhachHang) THROW 57001,N'Khach hang da co; khong seed lai.',1;
SET NOCOUNT ON;SET XACT_ABORT ON;SET QUOTED_IDENTIFIER ON;SET ANSI_NULLS ON;
IF (SELECT COUNT(*) FROM dbo.TinhThanh_LichSu)<>63 THROW 56300,N'Chưa đủ 63 tỉnh lịch sử.',1;
DECLARE @i int=1,@kh int,@tb int,@kv int,@nm int,@g1 int,@g2 int,@d1 bigint,@d2 bigint,
 @mac varchar(30),@mat varchar(30),@so varchar(25),@ten nvarchar(150),@mang varchar(20),
 @loai varchar(10),@loaikh varchar(20),@round int,@yc varchar(60),@slot int,@day int,@bat datetime2(0),@ket datetime2(0),@mb decimal(18,2),
 @seq bigint,@thang int,@hoadon bigint,@tong decimal(18,2),@phan decimal(18,2),@lap datetime2(0),@thu datetime2(0);
DECLARE @r TABLE(ID bigint);
DECLARE @u TABLE(ID bigint,LoaiDichVu varchar(10));
WHILE @i<=378
BEGIN
 BEGIN TRAN;
 SET @mac=CONCAT('KH',RIGHT('000000'+CONVERT(varchar,(@i-1)/3+1),6));
 SET @mat=CONCAT('TB',RIGHT('000000'+CONVERT(varchar,@i),6));
 SET @so=CONCAT('DEMO-',RIGHT('000000'+CONVERT(varchar,@i),6));
 SET @ten=CONCAT(N'Khách hàng mô phỏng ',RIGHT('0000'+CONVERT(varchar,(@i-1)/3+1),4));
 SET @loaikh=CASE WHEN ((@i-1)/3+1)%10=0 THEN 'DOANH_NGHIEP' ELSE 'CA_NHAN' END;
 DELETE @r;INSERT @r EXEC dbo.usp_TaoKhachHang @mac,@ten,@loaikh;
 SELECT @kh=ID FROM @r;
 SELECT @kv=KhuVucID FROM dbo.TinhThanh_LichSu WHERE ThuTu=(@i-1)%63+1;
 SET @round=(@i-1)/189;
 SET @mang=CASE ((@i-1)/63)%3 WHEN 0 THEN 'NM003' WHEN 1 THEN 'NM004' ELSE 'NM005' END;
 SELECT @nm=NhaMangID FROM dbo.NhaMang WHERE MaNhaMang=@mang;
 SET @loai=CASE WHEN @round%4=0 THEN 'TRA_SAU' ELSE 'TRA_TRUOC' END;
 DELETE @r;INSERT @r EXEC dbo.usp_TaoThueBao @mat,@so,@kh,@nm,@kv,@loai,'20260801';
 SELECT @tb=ID FROM @r;
 SELECT @g1=GoiCuocID FROM dbo.GoiCuoc WHERE MaGoiCuoc=CASE @mang WHEN 'NM003' THEN 'GC001' WHEN 'NM004' THEN 'GC003' ELSE 'GC005' END;
 SELECT @g2=GoiCuocID FROM dbo.GoiCuoc WHERE MaGoiCuoc=CASE @mang WHEN 'NM003' THEN 'GC002' WHEN 'NM004' THEN 'GC004' ELSE 'GC006' END;
 SET @seq=NEXT VALUE FOR dbo.Seq_YeuCau; SET @yc='YC'+RIGHT('000000000000'+CONVERT(varchar(20),@seq),12);DELETE @r;INSERT @r EXEC dbo.usp_DangKyGoiCuoc @yc,@tb,@g1,'20260901','20261101';SELECT @d1=ID FROM @r;
 SET @seq=NEXT VALUE FOR dbo.Seq_YeuCau; SET @yc='YC'+RIGHT('000000000000'+CONVERT(varchar(20),@seq),12);DELETE @r;INSERT @r EXEC dbo.usp_DangKyGoiCuoc @yc,@tb,@g2,'20260901','20261101';SELECT @d2=ID FROM @r;
 SET @slot=1;
 WHILE @slot<=20
 BEGIN
  SET @day=(@slot-1)*61/20;
  SET @bat=DATEADD(second,36000+(@i%3000),DATEADD(day,@day,CONVERT(datetime2(0),'20260901')));
  IF @loai='TRA_TRUOC' AND @slot IN(1,11)
  BEGIN
   SET @thang=YEAR(@bat)*100+MONTH(@bat);SET @seq=NEXT VALUE FOR dbo.Seq_YeuCau; SET @yc='YC'+RIGHT('000000000000'+CONVERT(varchar(20),@seq),12);
   SET @thu=DATEFROMPARTS(YEAR(@bat),MONTH(@bat),1);
   DELETE @r;INSERT @r EXEC dbo.usp_NapTien @yc,@tb,500000,@thu;
  END;
  SET @ket=DATEADD(second,30+(@i*7+@slot*31)%870,@bat);
  SET @seq=NEXT VALUE FOR dbo.Seq_YeuCau; SET @yc='YC'+RIGHT('000000000000'+CONVERT(varchar(20),@seq),12);
  DELETE @u;INSERT @u EXEC dbo.usp_GhiNhanSuDung @yc,@d1,@kv,@bat,@ket,0;
  SET @bat=DATEADD(hour,2,@bat);SET @ket=DATEADD(minute,10+(@i+@slot)%50,@bat);
  SET @mb=50+(@i*13+@slot*47)%1450;
  SET @seq=NEXT VALUE FOR dbo.Seq_YeuCau; SET @yc='YC'+RIGHT('000000000000'+CONVERT(varchar(20),@seq),12);
  DELETE @u;INSERT @u EXEC dbo.usp_GhiNhanSuDung @yc,@d2,@kv,@bat,@ket,@mb;
  SET @slot+=1;
 END;
 IF @loai='TRA_SAU'
 BEGIN
  SET @thang=202609;
  WHILE @thang<=202610
  BEGIN
   SET @lap=DATEADD(month,1,CONVERT(datetime2(0),DATEFROMPARTS(@thang/100,@thang%100,1)));
   SET @seq=NEXT VALUE FOR dbo.Seq_YeuCau; SET @yc='YC'+RIGHT('000000000000'+CONVERT(varchar(20),@seq),12);DELETE @r;INSERT @r EXEC dbo.usp_LapHoaDon @yc,@tb,@thang,@lap;
   SELECT @hoadon=ID FROM @r;SELECT @tong=TongTien FROM dbo.HoaDon WHERE HoaDonID=@hoadon;
   SET @phan=ROUND(@tong/2,2);SET @thu=DATEADD(day,1,@lap);
   SET @seq=NEXT VALUE FOR dbo.Seq_YeuCau; SET @yc='YC'+RIGHT('000000000000'+CONVERT(varchar(20),@seq),12);DELETE @r;INSERT @r EXEC dbo.usp_ThanhToanHoaDon @yc,@hoadon,@phan,@thu,'CHUYEN_KHOAN';
   -- Cố ý để 20% hóa đơn còn nợ một phần nhằm minh họa công nợ.
   IF @i%5<>0
   BEGIN
    SET @phan=@tong-@phan;SET @thu=DATEADD(day,2,@lap);
    SET @seq=NEXT VALUE FOR dbo.Seq_YeuCau; SET @yc='YC'+RIGHT('000000000000'+CONVERT(varchar(20),@seq),12);DELETE @r;INSERT @r EXEC dbo.usp_ThanhToanHoaDon @yc,@hoadon,@phan,@thu,'TIEN_MAT';
   END;
   SET @thang+=1;
  END;
 END;
 COMMIT;
 IF @i%63=0 RAISERROR(N'Đã xử lý %d / 378 thuê bao.',10,1,@i) WITH NOWAIT;
 SET @i+=1;
END;
GO
