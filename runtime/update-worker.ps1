param([Parameter(Mandatory)][string]$DataDir,[switch]$Automatic)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'update.ps1')
Add-Type -AssemblyName PresentationFramework,System.IO.Compression.FileSystem
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$repo='https://github.com/CosmicShinosawa/gemini-niang-widget/releases'
$lock=[Threading.Mutex]::new($false,'Local\GeminiNiangReleaseUpdate')
$held=$false
function Get-WidgetFileSha256([string]$Path){
    $sha=[Security.Cryptography.SHA256]::Create()
    try{
        $stream=[IO.File]::OpenRead($Path)
        try{return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')}
        finally{$stream.Dispose()}
    }finally{$sha.Dispose()}
}
function Show-Result([string]$Text){if(!$Automatic){[void][Windows.MessageBox]::Show($Text,'Gemini 娘 · 更新')}}
try{
    try{$held=$lock.WaitOne(0)}catch [Threading.AbandonedMutexException]{$held=$true}
    if(!$held){Show-Result '已有更新检查正在运行。';return}
    $null=[IO.Directory]::CreateDirectory($DataDir)
    [IO.File]::WriteAllText((Join-Path $DataDir 'last-update-check.txt'),[DateTime]::UtcNow.ToString('o'))
    $info=Invoke-RestMethod "$repo/latest/download/gemini-niang-update.json" -UseBasicParsing -TimeoutSec 20
    $tag=[string]$info.version
    if($tag -notmatch '^\d{1,8}\.\d{1,8}\.\d{1,8}$' -or $info.sha256 -notmatch '^[a-fA-F0-9]{64}$'){throw '更新清单格式无效。'}
    if([version]$tag -le (Get-WidgetVersion $root)){Show-Result "当前已是最新版本 $(Get-WidgetVersion $root)。";return}
    $pending=Get-WidgetUpdatePath $root $DataDir
    $readyMessage='新版已就绪。右键挂件，打开「版本与更新」，点击「立即重启并更新」。'
    if($pending -and (Get-WidgetVersion $pending) -ge [version]$tag){Show-Result $readyMessage;return}
    if(!$Automatic -and [Windows.MessageBox]::Show("发现 $tag 版，是否下载安装？",'Gemini 娘 · 更新','YesNo') -ne 'Yes'){return}
    $versions=Join-Path $DataDir 'versions'
    $stage=Join-Path $versions ('.stage-'+[guid]::NewGuid().ToString('N'))
    $null=[IO.Directory]::CreateDirectory($stage)
    try{
        $zip=Join-Path $stage 'package.zip'
        Invoke-WebRequest "$repo/download/v$tag/gemini-niang-widget.zip" -UseBasicParsing -OutFile $zip -TimeoutSec 90
        if((Get-WidgetFileSha256 $zip) -ne $info.sha256){throw '更新包 SHA-256 校验失败。'}
        $expanded=Join-Path $stage 'package'
        [IO.Compression.ZipFile]::ExtractToDirectory($zip,$expanded)
        if((Get-WidgetVersion $expanded) -ne [version]$tag){throw '更新包版本与清单不符。'}
        $check=& (Join-Path $PSHOME 'powershell.exe') -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $expanded 'widget.ps1') -CheckOnly -DataDir (Join-Path $stage 'test-profile')
        if($LASTEXITCODE -ne 0 -or !(($check -join "`n"|ConvertFrom-Json).imageLoaded)){throw '新版挂件自检失败。'}
        $target=Join-Path $versions $tag
        if([IO.Directory]::Exists($target)){
            foreach($file in Get-ChildItem -LiteralPath $expanded -File -Recurse){
                $existing=Join-Path $target $file.FullName.Substring($expanded.Length+1)
                if(![IO.File]::Exists($existing) -or (Get-WidgetFileSha256 $existing) -ne (Get-WidgetFileSha256 $file.FullName)){throw '已有版本目录与更新包不同，请检查后重试。'}
            }
        }else{[IO.Directory]::Move($expanded,$target)}
        $pointer=Join-Path $DataDir 'active-version.txt'
        $tmp=Join-Path $stage 'active-version.tmp'
        [IO.File]::WriteAllText($tmp,$tag)
        if([IO.File]::Exists($pointer)){[IO.File]::Replace($tmp,$pointer,[Management.Automation.Language.NullString]::Value)}else{[IO.File]::Move($tmp,$pointer)}
    }finally{
        $base=[IO.Path]::GetFullPath($versions)
        if(([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($stage)) -eq $base) -and ([IO.Path]::GetFileName($stage) -match '^\.stage-[a-f0-9]{32}$')){Remove-Item -LiteralPath $stage -Recurse -Force}
    }
    Show-Result $readyMessage
}catch{
    [IO.File]::WriteAllText((Join-Path $DataDir 'update-error.txt'),$_.Exception.Message)
    Show-Result ('更新未完成：'+$_.Exception.Message)
    exit 1
}finally{if($held){$lock.ReleaseMutex()};$lock.Dispose()}
