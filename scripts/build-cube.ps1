param([string]$MayChuSQL='',[string]$MayChuSSAS='',[switch]$Deploy)
$ErrorActionPreference='Stop';. (Join-Path $PSScriptRoot 'CauHinh.ps1')
if(!$Deploy){'Mở ssas/NhaMangDW.sln trong Visual Studio để Build. Triển khai đầy đủ nguồn/kho/cube bằng TrienKhai.ps1; -Deploy chỉ cài cube lần đầu khi SQL đã có và quyền nguồn đã được cấp.';return}
if($MayChuSQL){$NMDW.SQLServer=$MayChuSQL};if($MayChuSSAS){$NMDW.SSASServer=$MayChuSSAS};NapThuVien AMO
$s=[Microsoft.AnalysisServices.Server]::new();$s.Connect($NMDW.SSASServer)
try{
 if($s.Databases.FindByName($NMDW.DatabaseSSAS)){throw 'Database SSAS đích đã có; không deploy đè.'}
 [xml]$doc=[IO.File]::ReadAllText((Join-Path $GocHeThong 'ssas/NhaMangDW.xmla'))
 $ns=[Xml.XmlNamespaceManager]::new($doc.NameTable);$ns.AddNamespace('a','http://schemas.microsoft.com/analysisservices/2003/engine')
 $node=$doc.SelectSingleNode('/a:Create/a:ObjectDefinition/a:Database',$ns);$node.SelectSingleNode('a:ID',$ns).InnerText=$NMDW.DatabaseSSAS;$node.SelectSingleNode('a:Name',$ns).InnerText=$NMDW.DatabaseSSAS
 $b=[Data.Common.DbConnectionStringBuilder]::new();$b['Provider']='MSOLEDBSQL.1';$b['Data Source']=$NMDW.SQLServer;$b['Initial Catalog']=$NMDW.KhoDuLieu;$b['Integrated Security']='SSPI';$b['TrustServerCertificate']='True'
 foreach($cs in $doc.SelectNodes('//a:DataSource/a:ConnectionString',$ns)){$cs.InnerText=$b.ConnectionString}
 foreach($result in $s.Execute([regex]::Replace($doc.OuterXml,'^\s*<\?xml[^?]*\?>\s*',''))){foreach($msg in $result.Messages){if($msg -is [Microsoft.AnalysisServices.XmlaError]){throw $msg.Description}}}
 $s.Refresh();$s.Databases.FindByName($NMDW.DatabaseSSAS).Process([Microsoft.AnalysisServices.ProcessType]::ProcessFull);'Triển khai và process cube thành công.'
}finally{$s.Disconnect()}
