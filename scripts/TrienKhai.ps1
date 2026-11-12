param(
 [string]$SQLServer='localhost',[string]$SSASServer='localhost\SSAS2022',
 [string]$KhoDuLieu='NhaMangDW',[string]$NguonOLTP='NhaMangOLTP',[string]$DatabaseSSAS='NhaMangDW_OLAP',
 [string]$TaiKhoanDichVuSSAS='NT SERVICE\MSOLAP$SSAS2022',
 [string]$TepCauHinh='', [string]$AMOPath='', [string]$ADOMDPath='', [switch]$ChiSQL, [switch]$ChiKiemTra
)
$ErrorActionPreference='Stop';[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
. (Join-Path $PSScriptRoot 'CauHinh.ps1')
foreach($name in @($KhoDuLieu,$NguonOLTP,$DatabaseSSAS)){if($name -notmatch '^[A-Za-z][A-Za-z0-9_]{0,79}$' -or $name -in @('master','model','msdb','tempdb','NhaMang_DW','NhaMangDW_RestoreCheck')){throw 'Tên database đích không hợp lệ.'}}
if($KhoDuLieu -eq $NguonOLTP){throw 'Nguồn và kho phải có tên khác nhau.'}
if($AMOPath){$NMDW.AMOPath=$AMOPath};if($ADOMDPath){$NMDW.ADOMDPath=$ADOMDPath}
$NMDW.SQLServer=$SQLServer;$NMDW.SSASServer=$SSASServer;$NMDW.KhoDuLieu=$KhoDuLieu;$NMDW.NguonOLTP=$NguonOLTP;$NMDW.DatabaseSSAS=$DatabaseSSAS
if(!$TepCauHinh){$TepCauHinh=Join-Path $GocHeThong 'cau-hinh.local.json'}
if(Test-Path -LiteralPath $TepCauHinh){throw 'Đã có cấu hình đích; không ghi đè. Dùng tệp cấu hình mới khi cài một môi trường riêng.'}
$DaBatDauTao=$false
if(-not [Environment]::Is64BitProcess){throw 'Cần Windows PowerShell 64-bit để dùng provider SSAS 64-bit.'}
if(!(Test-Path -LiteralPath (Split-Path ([IO.Path]::GetFullPath($TepCauHinh)) -Parent))){throw 'Thư mục lưu cấu hình chưa tồn tại.'}
$c=[Data.SqlClient.SqlConnection]::new((ChuoiKetNoi-SQL 'master'));$as=$null;$c.Open()
try{
 $q=$c.CreateCommand();$q.CommandText="SELECT CONVERT(int,SERVERPROPERTY('ProductMajorVersion'))";if([int]$q.ExecuteScalar() -lt 16){throw 'Cần SQL Server 2022 hoặc mới hơn.'}
 foreach($name in @($KhoDuLieu,$NguonOLTP)){
  $q=$c.CreateCommand();$q.CommandText='SELECT DB_ID(@name)';[void]$q.Parameters.AddWithValue('@name',$name)
  if($q.ExecuteScalar() -isnot [DBNull]){throw ('Database '+$name+' đã tồn tại. Dừng trước mọi thay đổi; không xóa hoặc seed lại database này.')}
 }
 if(!$ChiSQL){
  NapThuVien AMO;NapThuVien ADOMD
  $as=[Microsoft.AnalysisServices.Server]::new();$as.Connect($SSASServer)
  if($as.Databases.FindByName($DatabaseSSAS)){throw 'Database SSAS đích đã tồn tại; không deploy đè.'}
  if(!$TaiKhoanDichVuSSAS){throw 'Cần tài khoản dịch vụ SSAS để cấp quyền đọc kho.'}
  $account=[Security.Principal.NTAccount]::new($TaiKhoanDichVuSSAS);[void]$account.Translate([Security.Principal.SecurityIdentifier])
 }
 foreach($file in @('oltp/NhaMangOLTP.sql','sql/NhaMangDW.sql','data/01_DanhMuc.sql','data/02_GiaoDichOLTP.sql','data/03_NguonKho.sql','ssas/NhaMangDW.xmla')){if(!(Test-Path (Join-Path $GocHeThong $file))){throw ('Thiếu tệp '+$file)}}
 if($ChiKiemTra){'Đủ điều kiện sơ bộ; chưa tạo database, seed, cấp quyền hoặc process.';return}
 # Từ đây chỉ tạo các database vừa xác minh chưa tồn tại; không có DROP/RESTORE/ghi đè.
 $DaBatDauTao=$true
 foreach($name in @($NguonOLTP,$KhoDuLieu)){ChayLenhSQL $c ('CREATE DATABASE ['+$name+'];')}
 $c.ChangeDatabase($NguonOLTP);ChayTepSQL $c (Join-Path $GocHeThong 'oltp/NhaMangOLTP.sql')
 # Mẫu mới có mã YC riêng, không dùng lại trạng thái sequence của máy phát triển.
 ChayLenhSQL $c 'ALTER SEQUENCE dbo.Seq_YeuCau RESTART WITH 1;'
 $c.ChangeDatabase($KhoDuLieu);ChayTepSQL $c (Join-Path $GocHeThong 'sql/NhaMangDW.sql')
 $c.ChangeDatabase($NguonOLTP)
 ChayTepSQL $c (Join-Path $GocHeThong 'data/01_DanhMuc.sql')
 'Đang sinh 378 thuê bao và giao dịch mẫu bằng thủ tục nghiệp vụ...'
 ChayTepSQL $c (Join-Path $GocHeThong 'data/02_GiaoDichOLTP.sql')
 $c.ChangeDatabase($KhoDuLieu);ChayTepSQL $c (Join-Path $GocHeThong 'data/03_NguonKho.sql')
 ChayLenhSQL $c 'EXEC etl.usp_TrichCuoc_OLTP; EXEC etl.usp_NapDuLieu; EXEC etl.usp_NapCuoc;'
 $q=$c.CreateCommand();$q.CommandText='SELECT COUNT_BIG(*) FROM dbo.Fact_CuocGoi';if([long]$q.ExecuteScalar() -ne 15120){throw 'Số bản ghi fact cước mẫu không đúng 15.120.'}
 if(!$ChiSQL){
  # Chỉ thêm login khi chưa có và chỉ cấp SELECT trên 11 bảng nguồn cube trong kho mới.
  $q=$c.CreateCommand();$q.CommandText='SELECT SUSER_ID(@name)';[void]$q.Parameters.AddWithValue('@name',$TaiKhoanDichVuSSAS)
  $accountSQL='['+$TaiKhoanDichVuSSAS.Replace(']',']]')+']'
  if($q.ExecuteScalar() -is [DBNull]){ChayLenhSQL $c ('CREATE LOGIN '+$accountSQL+' FROM WINDOWS;')}
  ChayLenhSQL $c ('CREATE USER '+$accountSQL+' FOR LOGIN '+$accountSQL+';')
  foreach($table in @('Dim_DichVu','Dim_KhoHang','Dim_KhuVuc','Dim_NhaMang','Dim_SanPham','Dim_ThoiGian','Dim_ThueBao','Fact_BanHang','Fact_MuaHang','Fact_TonKho','Fact_CuocGoi')){ChayLenhSQL $c ('GRANT SELECT ON OBJECT::dbo.['+$table+'] TO '+$accountSQL+';')}
  [xml]$xml=[IO.File]::ReadAllText((Join-Path $GocHeThong 'ssas/NhaMangDW.xmla'))
  $ns=[Xml.XmlNamespaceManager]::new($xml.NameTable);$ns.AddNamespace('a','http://schemas.microsoft.com/analysisservices/2003/engine')
  $node=$xml.SelectSingleNode('/a:Create/a:ObjectDefinition/a:Database',$ns);$node.SelectSingleNode('a:ID',$ns).InnerText=$DatabaseSSAS;$node.SelectSingleNode('a:Name',$ns).InnerText=$DatabaseSSAS
  $b=[Data.Common.DbConnectionStringBuilder]::new();$b['Provider']='MSOLEDBSQL.1';$b['Data Source']=$SQLServer;$b['Initial Catalog']=$KhoDuLieu;$b['Integrated Security']='SSPI';$b['TrustServerCertificate']='True'
  foreach($cs in $xml.SelectNodes('//a:DataSource/a:ConnectionString',$ns)){$cs.InnerText=$b.ConnectionString}
  foreach($result in $as.Execute([regex]::Replace($xml.OuterXml,'^\s*<\?xml[^?]*\?>\s*',''))){foreach($msg in $result.Messages){if($msg -is [Microsoft.AnalysisServices.XmlaError]){throw $msg.Description}}}
  $as.Refresh();$db=$as.Databases.FindByName($DatabaseSSAS);$db.Process([Microsoft.AnalysisServices.ProcessType]::ProcessFull)
  'Đã triển khai và process cube thành công.'
 }
 $NMDW|ConvertTo-Json|Set-Content -LiteralPath $TepCauHinh -Encoding UTF8
 'HOÀN TẤT. Cấu hình: '+$TepCauHinh
 if($ChiSQL){'Chỉ hoàn tất SQL/ETL; chưa triển khai SSAS. Cần triển khai cube riêng trước khi dùng menu đối soát cube.'}
}catch{if($DaBatDauTao){Write-Warning 'Database mới được giữ để chẩn đoán. Không tự xóa, chạy lại seed hoặc ghi đè.'}else{Write-Warning 'Chưa tạo database hoặc nạp dữ liệu; dừng ở bước kiểm tra điều kiện.'};throw}
finally{if($as){$as.Disconnect()};$c.Close()}
