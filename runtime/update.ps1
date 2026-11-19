# Update packages are installed beside one another. Personal files stay in DataDir.
function Get-WidgetVersion([string]$Root){
    $manifest=[IO.File]::ReadAllText((Join-Path $Root 'antigravity-plugin/plugin.json')) | ConvertFrom-Json
    [version]$manifest.version
}

function Get-WidgetUpdatePath([string]$Root,[string]$DataDir){
    $pointer=Join-Path $DataDir 'active-version.txt'
    if(![IO.File]::Exists($pointer)){return}
    $tag=[IO.File]::ReadAllText($pointer).Trim()
    if($tag -notmatch '^\d{1,8}\.\d{1,8}\.\d{1,8}$' -or [version]$tag -le (Get-WidgetVersion $Root)){return}
    $installed=Join-Path $DataDir "versions/$tag"
    try{if([IO.File]::Exists((Join-Path $installed 'widget.ps1')) -and (Get-WidgetVersion $installed) -eq [version]$tag){$installed}}catch{return}
}

function Sync-WidgetPlugin([string]$Root,[string]$Destination){
    $manifest=Join-Path $Destination 'plugin.json'
    if(![IO.File]::Exists($manifest)){return}
    $current=[IO.File]::ReadAllText($manifest) | ConvertFrom-Json
    if($current.name -ne 'gemini-niang' -or [version]$current.version -ge (Get-WidgetVersion $Root)){return}
    $source=Join-Path $Root 'antigravity-plugin'
    # Publish the version last so an interrupted copy can be retried on startup.
    $files=@(Get-ChildItem -LiteralPath $source -File -Recurse | Where-Object Name -ne 'plugin.json')+@(Get-Item (Join-Path $source 'plugin.json'))
    foreach($file in $files){
        $target=Join-Path $Destination $file.FullName.Substring($source.Length+1)
        $null=[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
        $temp=$target+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
        try{
            [IO.File]::Copy($file.FullName,$temp)
            if([IO.File]::Exists($target)){[IO.File]::Replace($temp,$target,[Management.Automation.Language.NullString]::Value)}else{[IO.File]::Move($temp,$target)}
        }finally{if([IO.File]::Exists($temp)){[IO.File]::Delete($temp)}}
    }
}

function Start-WidgetUpdate([switch]$Automatic){
    if($script:updateWorker -and !$script:updateWorker.HasExited){return}
    if($script:updateWorker){$script:updateWorker.Dispose()}
    $worker=Join-Path $script:appDir 'runtime/update-worker.ps1'
    $argsLine='-NoProfile -STA -ExecutionPolicy Bypass -File "'+$worker+'" -DataDir "'+$script:dataDir+'"'
    if($Automatic){$argsLine+=' -Automatic'}
    $script:updateWorker=Start-Process (Join-Path $PSHOME 'powershell.exe') -ArgumentList $argsLine -WindowStyle Hidden -PassThru
}

function Test-WidgetUpdateDue([long]$Now){
    if($Now -lt $script:nextUpdateProbe){return}
    $script:nextUpdateProbe=$Now+60000
    if([IO.File]::Exists($script:autoUpdateFlag) -and [IO.File]::GetLastWriteTimeUtc((Join-Path $script:dataDir 'last-update-check.txt')) -lt [DateTime]::UtcNow.AddDays(-1)){Start-WidgetUpdate -Automatic}
}
