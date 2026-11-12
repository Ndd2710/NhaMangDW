. (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts/CauHinh.ps1')
$ErrorActionPreference='Stop'
[Console]::InputEncoding=[Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$r=[Console]::In.ReadToEnd() | ConvertFrom-Json
$c=[Data.SqlClient.SqlConnection]::new((ChuoiKetNoi-SQL $NMDW.NguonOLTP))
function Rows($cmd){
 $cmd.CommandText=ChuyenThamChieuDB $cmd.CommandText;$rd=$cmd.ExecuteReader();$rows=[Collections.Generic.List[object]]::new()
 try{while($rd.Read()){$row=[ordered]@{};for($i=0;$i -lt $rd.FieldCount;$i++){$v=$rd.GetValue($i);if($v -is [DBNull]){$v=$null};if($v -is [datetime]){$v=$v.ToString('yyyy-MM-ddTHH:mm:ss')};$row[$rd.GetName($i)]=$v};$rows.Add([pscustomobject]$row)}}finally{$rd.Close();$cmd.Dispose()}
 return ,($rows.ToArray())
}
function Query([string]$sql){
 $cmd=$c.CreateCommand();$cmd.CommandText=$sql;$cmd.CommandTimeout=30
 $null=$cmd.Parameters.Add('@tb',[Data.SqlDbType]::Int);$cmd.Parameters['@tb'].Value=[int]$r.subject
 $null=$cmd.Parameters.Add('@skip',[Data.SqlDbType]::Int);$cmd.Parameters['@skip'].Value=([int]$r.page-1)*50
 $null=$cmd.Parameters.Add('@q',[Data.SqlDbType]::NVarChar,120);$cmd.Parameters['@q'].Value='%'+([string]$r.q).Replace('~','~~').Replace('%','~%').Replace('_','~_').Replace('[','~[')+'%'
 return ,(Rows $cmd)
}
try{
 $c.Open()
 switch($r.mode){
 'catalog' {
  $data=[ordered]@{
   customers=(Query 'SELECT KhachHangID ID,MaKhachHang+N'' · ''+TenKhachHang Ten FROM dbo.KhachHang ORDER BY KhachHangID DESC')
   subscribers=(Query 'SELECT ThueBaoID ID,MaThueBao+N'' · ''+TenNhaMang+N'' · ''+CASE LoaiThueBao WHEN ''TRA_TRUOC'' THEN N''Trả trước'' ELSE N''Trả sau'' END Ten FROM rpt.vw_ThueBao ORDER BY ThueBaoID DESC')
   networks=(Query 'SELECT NhaMangID ID,TenNhaMang Ten FROM dbo.NhaMang ORDER BY MaNhaMang')
   regions=(Query 'SELECT KhuVucID ID,Vung+N'' · ''+TenTinh Ten FROM dbo.KhuVuc ORDER BY MaKhuVuc')
   plans=(Query 'SELECT GoiCuocID ID,MaGoiCuoc+N'' · ''+TenGoiCuoc+N'' · ''+CONVERT(nvarchar(30),DonGia)+N'' VND/''+DonViTinh Ten FROM rpt.vw_GoiCuoc ORDER BY GoiCuocID')
  }
  @{ok=$true;data=$data} | ConvertTo-Json -Depth 9 -Compress
 }
 'list' {
  $queries=@{
   customers=@('(SELECT k.KhachHangID,v.* FROM rpt.vw_KhachHang v JOIN dbo.KhachHang k ON k.MaKhachHang=v.MaKhachHang) AS kh','KhachHangID','(MaKhachHang LIKE @q ESCAPE ''~'' OR TenKhachHang LIKE @q ESCAPE ''~'')')
   subscribers=@('rpt.vw_ThueBao','ThueBaoID','(@tb=0 OR ThueBaoID=@tb) AND (MaThueBao LIKE @q ESCAPE ''~'' OR TenKhachHang LIKE @q ESCAPE ''~'')')
   registrations=@('rpt.vw_DangKy','DangKyID','(@tb=0 OR ThueBaoID=@tb) AND (MaThueBao LIKE @q ESCAPE ''~'' OR MaYeuCau LIKE @q ESCAPE ''~'')')
   topups=@('rpt.vw_NapTien','NapTienID','(@tb=0 OR ThueBaoID=@tb) AND (MaThueBao LIKE @q ESCAPE ''~'' OR MaYeuCau LIKE @q ESCAPE ''~'')')
   usage=@('(SELECT s.*,f.DoanhThu ThanhTienKho,CASE WHEN f.CuocGoiID IS NULL THEN N''Chờ nạp'' WHEN f.DoanhThu=s.ThanhTien THEN N''Đã nạp, khớp tiền'' ELSE N''Cần đối chiếu'' END TrangThaiKho FROM rpt.vw_SuDung s LEFT JOIN NhaMangDW.dbo.Fact_CuocGoi f ON f.MaSuDung=s.MaYeuCau) AS sd','DongNguonID DESC,LoaiDichVu','(@tb=0 OR ThueBaoID=@tb) AND (MaThueBao LIKE @q ESCAPE ''~'' OR MaYeuCau LIKE @q ESCAPE ''~'')')
   invoices=@('rpt.vw_HoaDon','HoaDonID','(@tb=0 OR ThueBaoID=@tb) AND (MaThueBao LIKE @q ESCAPE ''~'' OR MaYeuCau LIKE @q ESCAPE ''~'')')
   payments=@('rpt.vw_ThanhToan','ThanhToanID','(@tb=0 OR ThueBaoID=@tb) AND (MaThueBao LIKE @q ESCAPE ''~'' OR MaYeuCau LIKE @q ESCAPE ''~'')')
   ledger=@('(SELECT s.SoCaiID,s.ThueBaoID,v.* FROM rpt.vw_SoCaiTaiKhoan v JOIN dbo.SoCaiTaiKhoan s ON s.MaSoCai=v.MaSoCai) AS sc','SoCaiID','(@tb=0 OR ThueBaoID=@tb) AND MaThueBao LIKE @q ESCAPE ''~''')
   plans=@('rpt.vw_GoiCuoc','GoiCuocID','(MaGoiCuoc LIKE @q ESCAPE ''~'' OR TenGoiCuoc LIKE @q ESCAPE ''~'')')
  }
  $s=$queries[[string]$r.section];if(!$s){throw 'Danh sách nguồn không hợp lệ.'}
  $data=[ordered]@{rows=(Query ("SELECT * FROM "+$s[0]+" WHERE "+$s[2]+" ORDER BY "+$s[1]+" DESC OFFSET @skip ROWS FETCH NEXT 50 ROWS ONLY"));count=(Query ("SELECT COUNT_BIG(*) Total FROM "+$s[0]+" WHERE "+$s[2]))[0].Total}
  $data.registrations=Query 'SELECT DangKyID ID,MaDangKy+N'' · ''+TenGoiCuoc+N'' · ''+TrangThai Ten FROM rpt.vw_DangKy WHERE ThueBaoID=@tb ORDER BY DangKyID DESC'
  $data.invoices=Query 'SELECT HoaDonID ID,N''HD''+RIGHT(REPLICATE(''0'',10)+CONVERT(varchar(20),HoaDonID),10)+N'' · ''+CONVERT(nvarchar(6),Thang)+N'' · Còn nợ ''+CONVERT(nvarchar(30),SoTienConNo)+N'' VND'' Ten FROM rpt.vw_HoaDon WHERE ThueBaoID=@tb ORDER BY HoaDonID DESC'
  @{ok=$true;data=$data} | ConvertTo-Json -Depth 9 -Compress
 }
 'write' {
  $procs=@{'khach-hang'='usp_TaoKhachHang';'thue-bao'='usp_TaoThueBao';'trang-thai'='usp_DoiTrangThaiThueBao';'dang-ky'='usp_DangKyGoiCuoc';'huy-goi'='usp_HuyDangKy';'nap-tien'='usp_NapTien';'su-dung'='usp_GhiNhanSuDung';'hoa-don'='usp_LapHoaDon';'thanh-toan'='usp_ThanhToanHoaDon';'goi-cuoc'='usp_TaoGoiCuoc';'ma-yeu-cau'='usp_TaoMaYeuCau'}
  $proc=$procs[[string]$r.action];if(!$proc){throw 'Thao tác không hợp lệ.'}
  $cmd=$c.CreateCommand();$cmd.CommandType=[Data.CommandType]::StoredProcedure;$cmd.CommandText='dbo.'+$proc;$cmd.CommandTimeout=35
  [Data.SqlClient.SqlCommandBuilder]::DeriveParameters($cmd)
  foreach($p in $cmd.Parameters){
   if($p.Direction -eq [Data.ParameterDirection]::ReturnValue){continue}
   $v=$r.payload.($p.ParameterName.TrimStart('@'))
   if($null -eq $v){$p.Value=[DBNull]::Value;continue}
   switch($p.SqlDbType.ToString()){
    'DateTime2' {$p.Value=[datetime]::ParseExact([string]$v,[string[]]@('yyyy-MM-ddTHH:mm:ss','yyyy-MM-ddTHH:mm'),[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::None)}
    'Decimal' {$p.Value=[decimal]::Parse([string]$v,[Globalization.CultureInfo]::InvariantCulture)}
    'Int' {$p.Value=[int]$v}
    'BigInt' {$p.Value=[long]$v}
    default {$p.Value=[string]$v}
   }
  }
  @{ok=$true;data=@{rows=(Rows $cmd)}} | ConvertTo-Json -Depth 9 -Compress
 }
 default {throw 'Chức năng nguồn không hợp lệ.'}
 }
}catch [Data.SqlClient.SqlException]{
 @{ok=$false;error=$_.Exception.Message;code=$_.Exception.Number} | ConvertTo-Json -Compress
}catch{
 @{ok=$false;error='Không đọc/ghi được nguồn OLTP. Kiểm tra dịch vụ và quyền Windows.';code=0} | ConvertTo-Json -Compress
}finally{$c.Dispose()}
