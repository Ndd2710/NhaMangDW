. (Join-Path $PSScriptRoot 'CauHinh.ps1')
$ErrorActionPreference='Stop';$goc=Split-Path $PSScriptRoot -Parent
$null=New-Item -ItemType Directory -Force -Path (Join-Path $goc 'evidence/mo-rong')
$null=New-Item -ItemType Directory -Force -Path (Join-Path $goc 'reports')
NapThuVien ADOMD
NapThuVien AMO
$as=New-Object Microsoft.AnalysisServices.Server;$as.Connect($NMDW.SSASServer);$db=$as.Databases.FindByName($NMDW.DatabaseSSAS);$cube=$db.Cubes['NhaMangDW']
if($db.Dimensions.Count -ne 7 -or $cube.MeasureGroups.Count -ne 4 -or $db.DataSourceViews['Nha Mang DW'].Schema.Tables.Count -ne 11){throw 'Sai quy mô7dimension/4nhóm/11bảng DSV'}
if($cube.MeasureGroups['Fact Ton Kho'].Measures['So Luong Ton'].AggregateFunction.ToString() -ne 'LastChild'){throw 'Tồn bị đổi tổng hợp'}
if($cube.MeasureGroups['Fact Cuoc Goi'].Dimensions.Count -ne 5){throw 'Sai liên kết chiều cước'}
$stored=0;foreach($g in $cube.MeasureGroups){$stored+=$g.Measures.Count};$as.Disconnect()
$conn=New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection((ChuoiKetNoi-SSAS));$conn.Open()
$sql=New-Object Data.SqlClient.SqlConnection((ChuoiKetNoi-SQL $NMDW.KhoDuLieu));$sql.Open();$ketqua=@()
try{
 $mq=$sql.CreateCommand();$mq.CommandText='SELECT DISTINCT d.MaThang FROM dbo.Fact_CuocGoi f JOIN dbo.Dim_ThoiGian d ON d.ThoiGianID=f.ThoiGianID ORDER BY d.MaThang';$mr=$mq.ExecuteReader();$months=@();while($mr.Read()){$months+=[string]$mr.GetInt32(0)};$mr.Close();$mq.Dispose()
 foreach($thang in $months){
  $q=$conn.CreateCommand();$q.CommandText="SELECT {[Measures].[So Phut Goi],[Measures].[Dung Luong Data MB],[Measures].[So Cuoc Goi],[Measures].[Doanh Thu Cuoc],[Measures].[Phi Vien Thong],[Measures].[Phi Xu Ly],[Measures].[Doanh Thu Thoai],[Measures].[Doanh Thu Data],[Measures].[So Ban Ghi Cuoc],[Measures].[Don Gia Thoai Binh Quan],[Measures].[Don Gia Data Binh Quan]} ON 0 FROM [NhaMangDW] WHERE ([Dim Thoi Gian].[Thang].&[$thang])";$rd=$q.ExecuteReader();$null=$rd.Read();$values=@();for($i=0;$i -lt 11;$i++){if($rd.IsDBNull($i)){$values+=$null}else{$values+=[decimal]$rd.GetValue($i)}};$rd.Close()
  $q=$sql.CreateCommand();$q.CommandText="SELECT SUM(f.SoPhutGoi),SUM(f.DungLuongDataMB),SUM(f.SoCuocGoi),SUM(f.DoanhThu),SUM(f.PhiVienThong),SUM(f.PhiXuLy),SUM(f.DoanhThuThoai),SUM(f.DoanhThuData),COUNT_BIG(*),SUM(f.DoanhThuThoai)/NULLIF(SUM(f.SoPhutGoi),0),SUM(f.DoanhThuData)/NULLIF(SUM(f.DungLuongDataMB),0) FROM dbo.Fact_CuocGoi f JOIN dbo.Dim_ThoiGian d ON d.ThoiGianID=f.ThoiGianID WHERE d.MaThang=$thang";$rd=$q.ExecuteReader();$null=$rd.Read();for($i=0;$i -lt 11;$i++){if($rd.IsDBNull($i) -and $null -eq $values[$i]){continue};if($rd.IsDBNull($i) -or $null -eq $values[$i] -or [Math]::Abs($values[$i]-[decimal]$rd.GetValue($i)) -gt 0.001){throw "SQL/cube không khớp tháng $thang chỉ tiêu $i"}};$rd.Close()
  # Đơn giá bình quân đối chiếu tổng tiền/tổng lượng; không giả định mọi gói cùng giá.
  $ketqua+=[pscustomobject]@{MaThang=$thang;SoPhutGoi=$values[0];DungLuongDataMB=$values[1];SoCuocGoi=$values[2];DoanhThu=$values[3];PhiVienThong=$values[4];PhiXuLy=$values[5];DoanhThuThoai=$values[6];DoanhThuData=$values[7];SoBanGhi=$values[8];DonGiaPhut=$values[9];DonGiaMB=$values[10];KetQua='KHOP_SQL_CUBE'}
 }
 $q=$conn.CreateCommand();$q.CommandText="SELECT {[Measures].[Don Gia Thoai Binh Quan],[Measures].[So Phut Trung Binh Moi Cuoc]} ON 0 FROM [NhaMangDW] WHERE ([Dim Dich Vu].[Loai Dich Vu].&[DATA])";$rd=$q.ExecuteReader();$null=$rd.Read();if(!$rd.IsDBNull(0) -or !$rd.IsDBNull(1)){throw 'Chia0trên phầnDATA phải trả rỗng'};$rd.Close()
 $q.CommandText="SELECT {[Measures].[So Luong Ban]} ON 0 FROM [NhaMangDW] WHERE ([Dim Dich Vu].[Loai Dich Vu].&[DATA])";$rd=$q.ExecuteReader();$null=$rd.Read();if(!$rd.IsDBNull(0)){throw 'Nhóm bán không được lặp số liệu theo chiều dịch vụ không liên quan'};$rd.Close()
 $ketqua|Export-Csv (Join-Path $goc 'evidence\mo-rong\doi-soat-cuoc.csv') -NoTypeInformation -Encoding UTF8
 $ketqua|Export-Csv (Join-Path $goc 'reports\cuoc-theo-thang.csv') -NoTypeInformation -Encoding UTF8
 [pscustomobject]@{TrangThai='THANH_CONG';Dimension=7;NhomSoDo=4;BangDSV=11;SoDoLuuTru=$stored;SoDoTinhToan=5;SoKPI=0;DonVi='Thoai:VND/phut;Data:VND/MB';ChiaKhong='TRA_RONG';ChieuKhongLienQuan='KHONG_LAP_SO_LIEU'}|ConvertTo-Json|Set-Content (Join-Path $goc 'evidence\mo-rong\ket-qua-cube.json') -Encoding UTF8
 $ketqua|Format-Table -AutoSize;'THÀNH CÔNG: đối soát11chỉ tiêu cước mọi tháng có dữ liệu,đơn giá riêng,mẫu0và chiều không liên quan.'
}finally{$conn.Close();$sql.Close()}
