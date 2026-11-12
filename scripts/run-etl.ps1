param([string]$MayChu='',[switch]$NapLai)
$ErrorActionPreference='Stop';. (Join-Path $PSScriptRoot 'CauHinh.ps1')
if($MayChu){$NMDW.SQLServer=$MayChu};$flag=if($NapLai){1}else{0}
$c=[Data.SqlClient.SqlConnection]::new((ChuoiKetNoi-SQL $NMDW.KhoDuLieu));$c.Open()
try{ChayLenhSQL $c "EXEC etl.usp_TrichCuoc_OLTP; EXEC etl.usp_NapDuLieu @NapLai=$flag; EXEC etl.usp_NapCuoc @NapLai=$flag;"}finally{$c.Close()}
