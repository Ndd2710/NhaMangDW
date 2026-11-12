param([string]$MayChuSSAS='')
$ErrorActionPreference='Stop';. (Join-Path $PSScriptRoot 'CauHinh.ps1')
if($MayChuSSAS){$NMDW.SSASServer=$MayChuSSAS};NapThuVien AMO
$s=[Microsoft.AnalysisServices.Server]::new();$s.Connect($NMDW.SSASServer)
try{$db=$s.Databases.FindByName($NMDW.DatabaseSSAS);if(!$db -or !$db.Dimensions.Find('Dim Thoi Gian')){throw 'Không tìm thấy đúng mô hình cube.'};$db.Process([Microsoft.AnalysisServices.ProcessType]::ProcessFull);'Đã process cube thành công.'}finally{$s.Disconnect()}
