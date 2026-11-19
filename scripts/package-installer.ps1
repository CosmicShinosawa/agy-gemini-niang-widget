param(
    [Parameter(Mandatory)][string]$PackageZip,
    [Parameter(Mandatory)][string]$OutputDir
)
$ErrorActionPreference='Stop'
$zip=(Get-Item -LiteralPath $PackageZip).FullName
$out=[IO.Directory]::CreateDirectory($OutputDir).FullName
$exe=Join-Path $out 'GeminiNiang-Setup.exe'
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
# A 256px PNG is a valid image payload for a Windows ICO file.
$icon=Join-Path ([IO.Path]::GetTempPath()) ('GeminiNiang-'+[guid]::NewGuid()+'.ico')
try{
    $logo=[IO.File]::ReadAllBytes((Join-Path $PSScriptRoot '../antigravity-plugin/logo.png'))
    $writer=[IO.BinaryWriter]::new([IO.File]::Create($icon))
    try{
        $writer.Write([byte[]](0,0,1,0,1,0,0,0,0,0,1,0,32,0))
        $writer.Write([int]$logo.Length)
        $writer.Write([int]22)
        $writer.Write($logo)
    }finally{$writer.Dispose()}
    & $compiler /nologo /target:winexe /platform:anycpu /codepage:65001 /reference:System.Windows.Forms.dll "/win32icon:$icon" "/out:$exe" "/resource:$zip,widget.zip" "/resource:$PSScriptRoot\install-widget.ps1,install-widget.ps1" (Join-Path $PSScriptRoot 'WidgetSetup.cs')
    if($LASTEXITCODE){throw 'Windows installer compilation failed.'}
}finally{if([IO.File]::Exists($icon)){[IO.File]::Delete($icon)}}
Get-Item -LiteralPath $exe
