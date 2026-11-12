param([string]$MayChuSQL='',[string]$MayChuSSAS='')
. (Join-Path $PSScriptRoot 'CauHinh.ps1')
if($MayChuSQL){$NMDW.SQLServer=$MayChuSQL};if($MayChuSSAS){$NMDW.SSASServer=$MayChuSSAS}
$ErrorActionPreference='Stop';$goc=Split-Path $PSScriptRoot -Parent
$null=New-Item -ItemType Directory -Force -Path (Join-Path $goc 'evidence/doi-ten')
$null=New-Item -ItemType Directory -Force -Path (Join-Path $goc 'reports')
NapThuVien ADOMD
$cube=New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection((ChuoiKetNoi-SSAS));$cube.Open()
$sql=New-Object Data.SqlClient.SqlConnection((ChuoiKetNoi-SQL $NMDW.KhoDuLieu));$sql.Open()
try{
 $q=$cube.CreateCommand();$q.CommandText='SELECT {[Measures].[So Luong Ban],[Measures].[So Luong Ton],[Measures].[Doanh Thu Ban Hang],[Measures].[Don Gia Ban Binh Quan],[Measures].[So Luong Mua],[Measures].[Thanh Tien Mua]} ON 0 FROM [NhaMangDW] WHERE ([Dim Thoi Gian].[Thang].&[202610])'
 $rd=$q.ExecuteReader();$null=$rd.Read();$ban=[int]$rd.GetValue(0);$ton=[int]$rd.GetValue(1);$thu=[decimal]$rd.GetValue(2);$gia=[decimal]$rd.GetValue(3);$mua=[int]$rd.GetValue(4);$tienMua=[decimal]$rd.GetValue(5);$rd.Close()
 $qsql=$sql.CreateCommand();$qsql.CommandText='SELECT SUM(SoLuongBan),SUM(DoanhThu) FROM dbo.Fact_BanHang WHERE ThoiGianID BETWEEN 20261001 AND 20261031';$rd=$qsql.ExecuteReader();$null=$rd.Read();$banSQL=[int]$rd.GetValue(0);$thuSQL=[decimal]$rd.GetValue(1);$rd.Close()
 $qsql.CommandText='SELECT SUM(SoLuongTon) FROM dbo.Fact_TonKho WHERE ThoiGianID=20261031';$tonSQL=[int]$qsql.ExecuteScalar()
 $qsql.CommandText='SELECT SUM(SoLuongMua),SUM(ThanhTienMua) FROM dbo.Fact_MuaHang WHERE ThoiGianID BETWEEN 20261001 AND 20261031';$rd=$qsql.ExecuteReader();$null=$rd.Read();$muaSQL=[int]$rd.GetValue(0);$tienMuaSQL=[decimal]$rd.GetValue(1);$rd.Close()
 if($ban -ne $banSQL -or $ton -ne $tonSQL -or $thu -ne $thuSQL -or $mua -ne $muaSQL -or $tienMua -ne $tienMuaSQL -or [Math]::Abs($gia-$thuSQL/$banSQL) -gt 0.001){throw 'Số liệu cube và SQL không khớp.'}
 [pscustomobject]@{TrangThai='THANH_CONG';MaThang=202610;SoLuongBan=$ban;SoLuongTon=$ton;DoanhThu=$thu;DonGiaBanBinhQuan=$gia;SoLuongMua=$mua;ThanhTienMua=$tienMua;SQLKhopCube=$true} | ConvertTo-Json | Set-Content (Join-Path $goc 'evidence\doi-ten\doi-soat-cube-sql.json') -Encoding UTF8
 foreach($file in Get-ChildItem (Join-Path $goc 'reports') -Filter '*.mdx'){
  $q=$cube.CreateCommand();$q.CommandText=[IO.File]::ReadAllText($file.FullName);$a=New-Object Microsoft.AnalysisServices.AdomdClient.AdomdDataAdapter($q);$t=New-Object Data.DataTable;$null=$a.Fill($t);$t | Export-Csv (Join-Path $goc "reports\$($file.BaseName).csv") -NoTypeInformation -Encoding UTF8;"THÀNH CÔNG MDX: $($file.Name), $($t.Rows.Count) dòng."
 }
 $q=$cube.CreateCommand();$q.CommandText='SELECT {[Measures].[Don Gia Ban Binh Quan]} ON 0 FROM [NhaMangDW] WHERE ([Dim Thoi Gian].[Thang].&[202610],[Dim San Pham].[San Pham ID].&[-1])';$rd=$q.ExecuteReader();$null=$rd.Read();if(!$rd.IsDBNull(0)){throw 'Mẫu số0 phải trả rỗng.'};$rd.Close()
 foreach($spec in @(@('sales-monthly','SELECT MaThang,NhomSanPham,SoLuongBan,DoanhThu FROM rpt.vw_BanHang_Thang ORDER BY MaThang,NhomSanPham'),@('drill-across','EXEC rpt.usp_DoiChieu_BanHang_TonKho'),@('integration',"SELECT p.NhomSanPham,SUM(f.SoLuongMua) SoLuongMua,SUM(f.ThanhTienMua) ThanhTienMua FROM dbo.Fact_MuaHang f JOIN dbo.Dim_SanPham p ON p.SanPhamID=f.SanPhamID WHERE ThoiGianID BETWEEN 20261001 AND 20261031 GROUP BY p.NhomSanPham"))){
  $a=New-Object Data.SqlClient.SqlDataAdapter($spec[1],$sql);$t=New-Object Data.DataTable;$null=$a.Fill($t);$t | Export-Csv (Join-Path $goc "reports\$($spec[0]).csv") -NoTypeInformation -Encoding UTF8
 }
 'THÀNH CÔNG: toàn bộ MDX trong reports, mẫu số0, sáu chỉ tiêu Mua/Bán/Tồn SQL/cube; cước kiểm tra riêng bằng scripts/DoiSoat_Cuoc.ps1.'
}finally{$cube.Close();$sql.Close()}
