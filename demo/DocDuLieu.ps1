. (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts/CauHinh.ps1')
$ErrorActionPreference='Stop'
[Console]::InputEncoding=[Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$request=[Console]::In.ReadToEnd() | ConvertFrom-Json
$month=[int]$request.month
if([string]$month -notmatch '^20[0-9]{2}(0[1-9]|1[0-2])$'){throw 'Tháng không hợp lệ.'}
$first=[datetime]::ParseExact("${month}01",'yyyyMMdd',[Globalization.CultureInfo]::InvariantCulture)
$last=$first.AddMonths(1).AddDays(-1)
$conn=New-Object Data.SqlClient.SqlConnection((ChuoiKetNoi-SQL $NMDW.KhoDuLieu))
function Query([string]$text){
 $cmd=$conn.CreateCommand();$cmd.CommandTimeout=30;$cmd.CommandText="SET @network=etl.fn_MaChuan('NHA_MANG',@network); SET @region=etl.fn_MaChuan('KHU_VUC',@region); SET @subscriber=etl.fn_MaChuan('THUE_BAO',@subscriber); "+$text
 $null=$cmd.Parameters.Add('@dau',[Data.SqlDbType]::Date);$cmd.Parameters['@dau'].Value=$first
 $null=$cmd.Parameters.Add('@cuoi',[Data.SqlDbType]::Date);$cmd.Parameters['@cuoi'].Value=$last
 $null=$cmd.Parameters.Add('@month',[Data.SqlDbType]::Int);$cmd.Parameters['@month'].Value=$month
 $null=$cmd.Parameters.Add('@kho',[Data.SqlDbType]::Int);$cmd.Parameters['@kho'].Value=[int]$request.warehouse
 foreach($spec in @(@('type',10),@('network',20),@('region',20),@('subscriber',30))){
  $name='@'+$spec[0];$null=$cmd.Parameters.Add($name,[Data.SqlDbType]::VarChar,[int]$spec[1]);$cmd.Parameters[$name].Value=[string]$request.($spec[0])
 }
 $rd=$cmd.ExecuteReader();$rows=New-Object 'Collections.Generic.List[object]'
 try{
  while($rd.Read()){
   $row=[ordered]@{}
   for($i=0;$i -lt $rd.FieldCount;$i++){$value=$rd.GetValue($i);if($value -is [DBNull]){$value=$null};if($value -is [datetime]){$value=$value.ToString('yyyy-MM-ddTHH:mm:ss')};$row[$rd.GetName($i)]=$value}
   $rows.Add([pscustomobject]$row)
  }
 }finally{$rd.Close();$cmd.Dispose()}
 return ,($rows.ToArray())
}
try{
 $conn.Open();$result=[ordered]@{source=('SQL Server · '+$NMDW.KhoDuLieu);month=$month;readAt=[datetime]::UtcNow.ToString('o')}
 switch($request.mode){
  'snapshot' {
   $tables=@('Dim_ThoiGian','Dim_SanPham','Dim_KhoHang','Dim_DichVu','Dim_NhaMang','Dim_ThueBao','Dim_KhuVuc','Fact_BanHang','Fact_MuaHang','Fact_TonKho','Fact_CuocGoi')
   $result.tables=@()
   foreach($name in $tables){
    $pk=switch($name){'Dim_ThoiGian' {'ThoiGianID'} 'Dim_SanPham' {'SanPhamID'} 'Dim_KhoHang' {'KhoHangID'} 'Dim_DichVu' {'DichVuID'} 'Dim_NhaMang' {'NhaMangID'} 'Dim_ThueBao' {'ThueBaoID'} 'Dim_KhuVuc' {'KhuVucID'} 'Fact_BanHang' {'BanHangID'} 'Fact_MuaHang' {'MuaHangID'} 'Fact_TonKho' {'TonKhoID'} 'Fact_CuocGoi' {'CuocGoiID'}}
    $rows=Query "SELECT * FROM dbo.[$name] ORDER BY [$pk]"
    $bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $rows -Depth 6 -Compress))
    $sha=[Security.Cryptography.SHA256]::Create();$hash=[BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','');$sha.Dispose()
    $result.tables+=@{Bang=$name;SoDong=$rows.Count;SHA256=$hash}
   }
  }
  'catalog' {
   $result.months=Query 'SELECT DISTINCT MaThang ID,TenThang Ten FROM dbo.Dim_ThoiGian WHERE ThoiGianID<>-1 ORDER BY MaThang DESC'
   $result.warehouses=Query 'SELECT KhoHangID ID,Vung+N'' · ''+TenKhoHang Ten FROM dbo.Dim_KhoHang WHERE KhoHangID<>-1 ORDER BY KhoHangID'
   $result.networks=Query 'SELECT MaNhaMang ID,TenNhaMang Ten FROM dbo.Dim_NhaMang WHERE NhaMangID<>-1 ORDER BY MaNhaMang'
   $result.regions=Query 'SELECT MaKhuVuc ID,Vung+N'' · ''+TenTinh Ten FROM dbo.Dim_KhuVuc WHERE KhuVucID<>-1 ORDER BY MaKhuVuc'
   $result.subscribers=Query 'SELECT t.MaThueBao ID,t.MaThueBao+CASE WHEN m.MaCu IS NOT NULL AND m.MaCu<>t.MaThueBao THEN N'' (nguồn ''+m.MaCu+N'')'' ELSE N'''' END+N'' · ''+t.LoaiKhachHang Ten FROM dbo.Dim_ThueBao t LEFT JOIN etl.DoiChieu_Ma m ON m.LoaiMa=''THUE_BAO_OLTP'' AND m.MaMoi=t.MaThueBao WHERE t.ThueBaoID<>-1 ORDER BY t.MaThueBao'
  }
  'analysis' {
   $result.rows=Query @'
;WITH f AS(
 SELECT d.Ngay,n.MaNhaMang,n.TenNhaMang,k.MaKhuVuc,k.TenTinh,k.Vung,v.MaDichVu,v.TenGoiCuoc,v.LoaiDichVu,
  b.ThueBaoID,c.SoPhutGoi,c.DungLuongDataMB,c.SoCuocGoi,c.DoanhThuThoai,c.DoanhThuData,c.DoanhThu
 FROM dbo.Fact_CuocGoi c JOIN dbo.Dim_ThoiGian d ON d.ThoiGianID=c.ThoiGianID
 JOIN dbo.Dim_NhaMang n ON n.NhaMangID=c.NhaMangID JOIN dbo.Dim_KhuVuc k ON k.KhuVucID=c.KhuVucID
 JOIN dbo.Dim_DichVu v ON v.DichVuID=c.DichVuID JOIN dbo.Dim_ThueBao b ON b.ThueBaoID=c.ThueBaoID
 WHERE d.MaThang=@month AND (@type='' OR v.LoaiDichVu=@type) AND (@network='' OR n.MaNhaMang=@network)
  AND (@region='' OR k.MaKhuVuc=@region) AND (@subscriber='' OR b.MaThueBao=@subscriber)
)
SELECT CASE WHEN GROUPING(MaNhaMang)=0 THEN 'networks' WHEN GROUPING(MaKhuVuc)=0 THEN 'provinces'
 WHEN GROUPING(Vung)=0 THEN 'regions' WHEN GROUPING(MaDichVu)=0 THEN 'plans' WHEN GROUPING(Ngay)=0 THEN 'days' ELSE 'total' END GocNhin,
 CASE WHEN GROUPING(MaNhaMang)=0 THEN MaNhaMang WHEN GROUPING(MaKhuVuc)=0 THEN MaKhuVuc
 WHEN GROUPING(Vung)=0 THEN Vung WHEN GROUPING(MaDichVu)=0 THEN MaDichVu WHEN GROUPING(Ngay)=0 THEN CONVERT(varchar(10),Ngay,23) ELSE '' END Ma,
 CASE WHEN GROUPING(MaNhaMang)=0 THEN TenNhaMang WHEN GROUPING(MaKhuVuc)=0 THEN TenTinh
 WHEN GROUPING(Vung)=0 THEN Vung WHEN GROUPING(MaDichVu)=0 THEN TenGoiCuoc WHEN GROUPING(Ngay)=0 THEN CONVERT(nvarchar(10),Ngay,103) ELSE N'Tổng cộng' END Ten,
 LoaiDichVu,COUNT_BIG(*) SoBanGhi,COUNT(DISTINCT ThueBaoID) SoThueBao,
 COALESCE(SUM(SoPhutGoi),0) SoPhutGoi,COALESCE(SUM(DungLuongDataMB),0) DungLuongDataMB,
 COALESCE(SUM(CONVERT(bigint,SoCuocGoi)),0) SoCuocGoi,COALESCE(SUM(DoanhThuThoai),0) DoanhThuThoai,
 COALESCE(SUM(DoanhThuData),0) DoanhThuData,COALESCE(SUM(DoanhThu),0) DoanhThu,
 SUM(DoanhThuThoai)/NULLIF(SUM(SoPhutGoi),0) DonGiaThoaiBinhQuan,
 SUM(DoanhThuData)/NULLIF(SUM(DungLuongDataMB),0) DonGiaDataBinhQuan
FROM f GROUP BY GROUPING SETS((MaNhaMang,TenNhaMang),(Vung),(MaKhuVuc,TenTinh),(MaDichVu,TenGoiCuoc,LoaiDichVu),(Ngay),());
'@
  }
  'report' {
   $result.goods=Query @'
;WITH b AS (
 SELECT p.NhomSanPham,SUM(CONVERT(bigint,f.SoLuongBan)) SoLuongBan,SUM(f.DoanhThu) DoanhThu
 FROM dbo.Fact_BanHang f JOIN dbo.Dim_SanPham p ON p.SanPhamID=f.SanPhamID
 JOIN dbo.Dim_ThoiGian d ON d.ThoiGianID=f.ThoiGianID
 WHERE d.Ngay BETWEEN @dau AND @cuoi AND (@kho=0 OR f.KhoHangID=@kho) GROUP BY p.NhomSanPham
),m AS (
 SELECT p.NhomSanPham,SUM(CONVERT(bigint,f.SoLuongMua)) SoLuongMua,SUM(f.ThanhTienMua) ThanhTienMua
 FROM dbo.Fact_MuaHang f JOIN dbo.Dim_SanPham p ON p.SanPhamID=f.SanPhamID
 JOIN dbo.Dim_ThoiGian d ON d.ThoiGianID=f.ThoiGianID
 WHERE d.Ngay BETWEEN @dau AND @cuoi AND (@kho=0 OR f.KhoHangID=@kho) GROUP BY p.NhomSanPham
),t AS (
 SELECT p.NhomSanPham,SUM(CONVERT(bigint,f.SoLuongTon)) SoLuongTon
 FROM dbo.Fact_TonKho f JOIN dbo.Dim_SanPham p ON p.SanPhamID=f.SanPhamID
 JOIN dbo.Dim_ThoiGian d ON d.ThoiGianID=f.ThoiGianID
 WHERE d.Ngay=@cuoi AND (@kho=0 OR f.KhoHangID=@kho) GROUP BY p.NhomSanPham
),g AS (SELECT DISTINCT NhomSanPham FROM dbo.Dim_SanPham WHERE SanPhamID<>-1)
SELECT g.NhomSanPham,COALESCE(b.SoLuongBan,0) SoLuongBan,COALESCE(b.DoanhThu,0) DoanhThu,
 COALESCE(m.SoLuongMua,0) SoLuongMua,COALESCE(m.ThanhTienMua,0) ThanhTienMua,t.SoLuongTon
FROM g LEFT JOIN b ON b.NhomSanPham=g.NhomSanPham LEFT JOIN m ON m.NhomSanPham=g.NhomSanPham LEFT JOIN t ON t.NhomSanPham=g.NhomSanPham ORDER BY g.NhomSanPham;
'@
   $result.coverage=Query @'
SELECT (SELECT COUNT(*) FROM wms.TonKho_DauKy o JOIN dbo.Dim_KhoHang k ON k.MaKhoHangNghiepVu=o.MaKhoHangNghiepVu WHERE @kho=0 OR k.KhoHangID=@kho) SoCapCanCo,
 (SELECT COUNT(*) FROM dbo.Fact_TonKho f JOIN dbo.Dim_ThoiGian d ON d.ThoiGianID=f.ThoiGianID WHERE d.Ngay=@cuoi AND (@kho=0 OR f.KhoHangID=@kho)) SoCapDaChot;
'@
   $result.telecom=Query @'
SELECT dv.LoaiDichVu,n.TenNhaMang,k.TenTinh,k.Vung,b.MaThueBao,b.LoaiKhachHang,
 SUM(f.SoPhutGoi) SoPhutGoi,SUM(f.DungLuongDataMB) DungLuongDataMB,SUM(CONVERT(bigint,f.SoCuocGoi)) SoCuocGoi,
 SUM(f.DoanhThuThoai) DoanhThuThoai,SUM(f.DoanhThuData) DoanhThuData,SUM(f.DoanhThu) DoanhThu,
 SUM(f.PhiVienThong) PhiVienThong,SUM(f.PhiXuLy) PhiXuLy,COUNT_BIG(*) SoBanGhi
FROM dbo.Fact_CuocGoi f JOIN dbo.Dim_ThoiGian t ON t.ThoiGianID=f.ThoiGianID
 JOIN dbo.Dim_DichVu dv ON dv.DichVuID=f.DichVuID JOIN dbo.Dim_NhaMang n ON n.NhaMangID=f.NhaMangID
 JOIN dbo.Dim_KhuVuc k ON k.KhuVucID=f.KhuVucID JOIN dbo.Dim_ThueBao b ON b.ThueBaoID=f.ThueBaoID
WHERE t.MaThang=@month AND (@type='' OR dv.LoaiDichVu=@type) AND (@network='' OR n.MaNhaMang=@network)
 AND (@region='' OR k.MaKhuVuc=@region) AND (@subscriber='' OR b.MaThueBao=@subscriber)
GROUP BY dv.LoaiDichVu,n.TenNhaMang,k.TenTinh,k.Vung,b.MaThueBao,b.LoaiKhachHang
ORDER BY dv.LoaiDichVu,n.TenNhaMang,k.TenTinh,b.MaThueBao;
'@
  }
  'admin' {
   $result.connector=Query "IF OBJECT_ID('etl.NhatKy_TrichOLTP') IS NOT NULL SELECT TOP(8) TrichID,BatDauUTC,KetThucUTC,TrangThai,SoDongDoc,SoDongTrich,SoGoiThem,SoThueBaoThem,SoNgayThem,ThongBaoLoi FROM etl.NhatKy_TrichOLTP ORDER BY TrichID DESC"
   $result.batches=Query 'SELECT TOP(16) DotNapID,ThoiDiemBatDauUTC,ThoiDiemKetThucUTC,TrangThai,SoDongDoc,SoDongNap,SoDongLoi,COALESCE(ThongBaoLoi,N''Không có thông báo lỗi'') ThongBaoLoi FROM etl.Dot_NapDuLieu ORDER BY DotNapID DESC'
   $result.watermarks=Query 'SELECT HeThongNguon,DongNguonCuoiID FROM etl.Moc_NapDuLieu ORDER BY HeThongNguon'
   $result.errors=Query @'
SELECT TOP(12) DotNapID,HeThongNguon,DongNguonID,LyDoLoi FROM (
 SELECT DotNapID,HeThongNguon,DongNguonID,CONVERT(nvarchar(200),LyDoLoi) LyDoLoi FROM etl.DuLieu_Loi
 UNION ALL SELECT DotNapID,'CUOC',DongNguonID,LyDoLoi FROM etl.DuLieu_LoiCuoc
) x ORDER BY DotNapID DESC,DongNguonID;
'@
   $result.facts=Query "SELECT N'Bán hàng' Ten,COUNT_BIG(*) SoDong FROM dbo.Fact_BanHang UNION ALL SELECT N'Mua hàng',COUNT_BIG(*) FROM dbo.Fact_MuaHang UNION ALL SELECT N'Tồn kho',COUNT_BIG(*) FROM dbo.Fact_TonKho UNION ALL SELECT N'Cước',COUNT_BIG(*) FROM dbo.Fact_CuocGoi"
  }
  'cube' {
   $result.sql=Query @'
SELECT
 (SELECT SUM(SoLuongBan) FROM dbo.Fact_BanHang WHERE ThoiGianID BETWEEN @month*100+1 AND @month*100+31) SoLuongBan,
 (SELECT SUM(DoanhThu) FROM dbo.Fact_BanHang WHERE ThoiGianID BETWEEN @month*100+1 AND @month*100+31) DoanhThuBan,
 (SELECT SUM(SoLuongTon) FROM dbo.Fact_TonKho WHERE ThoiGianID=CONVERT(int,CONVERT(char(8),@cuoi,112))) SoLuongTon,
 (SELECT SUM(SoLuongMua) FROM dbo.Fact_MuaHang WHERE ThoiGianID BETWEEN @month*100+1 AND @month*100+31) SoLuongMua,
 (SELECT SUM(ThanhTienMua) FROM dbo.Fact_MuaHang WHERE ThoiGianID BETWEEN @month*100+1 AND @month*100+31) ThanhTienMua,
 (SELECT SUM(DoanhThu) FROM dbo.Fact_CuocGoi WHERE ThoiGianID BETWEEN @month*100+1 AND @month*100+31) DoanhThuCuoc,
 (SELECT SUM(SoPhutGoi) FROM dbo.Fact_CuocGoi WHERE ThoiGianID BETWEEN @month*100+1 AND @month*100+31) SoPhutGoi,
 (SELECT SUM(DungLuongDataMB) FROM dbo.Fact_CuocGoi WHERE ThoiGianID BETWEEN @month*100+1 AND @month*100+31) DungLuongDataMB,
 (SELECT SUM(SoCuocGoi) FROM dbo.Fact_CuocGoi WHERE ThoiGianID BETWEEN @month*100+1 AND @month*100+31) SoCuocGoi;
'@
   NapThuVien ADOMD
   $cube=New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection((ChuoiKetNoi-SSAS))
   try{
    $cube.Open();$cmd=$cube.CreateCommand();$cmd.CommandTimeout=30
    $cmd.CommandText="SELECT {[Measures].[So Luong Ban],[Measures].[Doanh Thu Ban Hang],[Measures].[So Luong Ton],[Measures].[So Luong Mua],[Measures].[Thanh Tien Mua],[Measures].[Doanh Thu Cuoc],[Measures].[So Phut Goi],[Measures].[Dung Luong Data MB],[Measures].[So Cuoc Goi]} ON 0 FROM [NhaMangDW] WHERE ([Dim Thoi Gian].[Thang].&[$month])"
    $rd=$cmd.ExecuteReader();$null=$rd.Read();$names=@('SoLuongBan','DoanhThuBan','SoLuongTon','SoLuongMua','ThanhTienMua','DoanhThuCuoc','SoPhutGoi','DungLuongDataMB','SoCuocGoi');$values=[ordered]@{}
    for($i=0;$i -lt $names.Count;$i++){$v=$rd.GetValue($i);if($v -is [DBNull]){$v=$null};$values[$names[$i]]=$v};$rd.Close()
    $result.cube=[pscustomobject]$values;$result.cubeSource='SSAS · '+$NMDW.DatabaseSSAS+'/NhaMangDW'
   }finally{$cube.Close()}
  }
  default {throw 'Loại truy vấn không được hỗ trợ.'}
 }
 [Console]::Write(($result | ConvertTo-Json -Depth 10 -Compress))
}catch{[Console]::Error.Write($_.Exception.Message);exit 1}finally{$conn.Dispose()}
