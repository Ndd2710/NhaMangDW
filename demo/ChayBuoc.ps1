param([ValidateSet('nap','kiemtra','process','mdx','cuoc')][string]$Buoc)
$ErrorActionPreference='Stop';$OutputEncoding=[Text.UTF8Encoding]::new($false);[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$root=Split-Path $PSScriptRoot -Parent
switch($Buoc){
 'nap' {& (Join-Path $root 'scripts/run-etl.ps1')}
 'kiemtra' {. (Join-Path $root 'scripts/CauHinh.ps1');$c=[Data.SqlClient.SqlConnection]::new((ChuoiKetNoi-SQL $NMDW.KhoDuLieu));$c.Open();try{ChayTepSQL $c (Join-Path $root 'scripts/KiemTra_SQL.sql')}finally{$c.Close()}}
 'process' {& (Join-Path $root 'scripts/process.ps1')}
 'mdx' {& (Join-Path $root 'scripts/verify-cube.ps1')}
 'cuoc' {& (Join-Path $root 'scripts/DoiSoat_Cuoc.ps1')}
}
