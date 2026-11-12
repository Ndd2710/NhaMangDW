# Cấu hình máy hiện tại được bỏ khỏi Git; mẫu trong cau-hinh.mau.json.
$GocHeThong=Split-Path $PSScriptRoot -Parent
$tep=Join-Path $GocHeThong 'cau-hinh.mau.json'
if($env:NMDW_CONFIG){$tep=$env:NMDW_CONFIG}elseif(Test-Path (Join-Path $GocHeThong 'cau-hinh.local.json')){$tep=Join-Path $GocHeThong 'cau-hinh.local.json'}
$NMDW=Get-Content -LiteralPath $tep -Raw -Encoding UTF8|ConvertFrom-Json
foreach($key in @('KhoDuLieu','NguonOLTP','DatabaseSSAS')){if($NMDW.$key -notmatch '^[A-Za-z][A-Za-z0-9_]{0,79}$'){throw ('Tên database không hợp lệ: '+$key)}}
function ChuoiKetNoi-SQL([string]$Database){
 $b=[Data.SqlClient.SqlConnectionStringBuilder]::new();$b['Data Source']=$NMDW.SQLServer;$b['Initial Catalog']=$Database;$b['Integrated Security']=$true;$b['TrustServerCertificate']=$true;$b['Connect Timeout']=15;return $b.ConnectionString
}
function ChuoiKetNoi-SSAS{
 $b=[Data.Common.DbConnectionStringBuilder]::new();$b['Data Source']=$NMDW.SSASServer;$b['Catalog']=$NMDW.DatabaseSSAS;$b['Integrated Security']='SSPI';return $b.ConnectionString
}
function ChuyenThamChieuDB([string]$SQL){
 # Chỉ đổi định danh USE và tham chiếu ba phần đến hai database của hệ thống.
 foreach($item in @(@('NhaMangOLTP',$NMDW.NguonOLTP),@('NhaMangDW',$NMDW.KhoDuLieu))){
  $old=$item[0];$new=$item[1]
  $SQL=[regex]::Replace($SQL,'(?i)\b'+$old+'(?=\.(?:dbo|rpt|etl)\.)',$new)
  $SQL=[regex]::Replace($SQL,'(?im)\bUSE\s+\[?'+$old+'\]?\s*;','USE ['+$new+'];')
 }
 return $SQL
}
function NapThuVien([ValidateSet('AMO','ADOMD')][string]$Loai){
 $ten=if($Loai -eq 'AMO'){'Microsoft.AnalysisServices.dll'}else{'Microsoft.AnalysisServices.AdomdClient.dll'}
 $paths=[Collections.Generic.List[string]]::new()
 if($NMDW.($Loai+'Path')){$paths.Add([string]$NMDW.($Loai+'Path'))}
 foreach($v in @('160','170')){
  $paths.Add((Join-Path $env:ProgramFiles ('Microsoft SQL Server\'+$v+'\Setup Bootstrap\SQL2022\x64\'+$ten)))
  $paths.Add((Join-Path $env:ProgramFiles ('Microsoft SQL Server\'+$v+'\SDK\Assemblies\'+$ten)))
 }
 foreach($v in @('21','20','19')){$paths.Add((Join-Path $env:ProgramFiles ('Microsoft SQL Server Management Studio '+$v+'\Release\Common7\IDE\'+$ten)))}
 $file=$paths|Where-Object {Test-Path -LiteralPath $_}|Select-Object -First 1
 if(!$file){throw ('Chưa tìm được '+$ten+'. Cài SQL Server/SSMS hoặc điền '+$Loai+'Path trong cấu hình.')}
 Add-Type -Path $file
}
function ChayLenhSQL([Data.SqlClient.SqlConnection]$KetNoi,[string]$SQL){
 $q=$KetNoi.CreateCommand();$q.CommandTimeout=1800;$q.CommandText=ChuyenThamChieuDB $SQL
 $ds=[Data.DataSet]::new();$a=[Data.SqlClient.SqlDataAdapter]::new($q);[void]$a.Fill($ds);foreach($t in $ds.Tables){if($t.Rows.Count){$t|Format-Table|Out-String|Write-Output}};$q.Dispose();$ds.Dispose()
}
function ChayTepSQL([Data.SqlClient.SqlConnection]$KetNoi,[string]$Tep){
 $text=[IO.File]::ReadAllText($Tep)
 foreach($batch in [regex]::Split($text,'(?im)^\s*GO\s*(?:--[^\r\n]*)?\r?$')){if($batch.Trim()){ChayLenhSQL $KetNoi $batch}}
}
