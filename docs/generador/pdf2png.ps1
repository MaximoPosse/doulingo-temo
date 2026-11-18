param($pdf,$outDir,$w=900)
New-Item -ItemType Directory -Force $outDir | Out-Null
Get-ChildItem $outDir -Filter p*.png | Remove-Item
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[void][Windows.Data.Pdf.PdfDocument,Windows.Data.Pdf,ContentType=WindowsRuntime]
[void][Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]
[void][Windows.Storage.Streams.InMemoryRandomAccessStream,Windows.Storage.Streams,ContentType=WindowsRuntime]
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await($op, $type) { $t = $asTask.MakeGenericMethod($type).Invoke($null, @($op)); $t.Wait(-1) | Out-Null; $t.Result }
$file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($pdf)) ([Windows.Storage.StorageFile])
$doc = Await ([Windows.Data.Pdf.PdfDocument]::LoadFromFileAsync($file)) ([Windows.Data.Pdf.PdfDocument])
$asAction = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' })[0]
foreach ($i in 0..($doc.PageCount-1)) {
  $page = $doc.GetPage($i); $ms = New-Object Windows.Storage.Streams.InMemoryRandomAccessStream
  $opts = New-Object Windows.Data.Pdf.PdfPageRenderOptions; $opts.DestinationWidth = [uint32]$w
  $a = $page.RenderToStreamAsync($ms, $opts); $t = $asAction.Invoke($null, @($a)); $t.Wait(-1) | Out-Null
  $s = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($ms)
  $fs = [System.IO.File]::Create("$outDir\p$($i+1).png"); $s.CopyTo($fs); $fs.Close(); $page.Dispose()
}
"pages: $($doc.PageCount)"
