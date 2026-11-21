param(
    [string]$DataDir=(Join-Path $env:LOCALAPPDATA 'GeminiNiangWidget'),
    [string]$PluginDir=(Join-Path $env:USERPROFILE '.gemini\config\plugins\gemini-niang'),
    [switch]$NoLaunch
)
$ErrorActionPreference='Stop'
$report=Join-Path $PSScriptRoot 'result.txt'
$lock=[Threading.Mutex]::new($false,'Local\GeminiNiangReleaseUpdate')
$held=$false
$stage=$null
try{
    try{$held=$lock.WaitOne(0)}catch [Threading.AbandonedMutexException]{$held=$true}
    if(!$held){throw '另一个安装或更新正在进行，请稍后再试。'}
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $versions=Join-Path $DataDir 'versions'
    $stage=Join-Path $versions ('.install-'+[guid]::NewGuid().ToString('N'))
    $null=[IO.Directory]::CreateDirectory($stage)
    $source=Join-Path $stage 'package'
    [IO.Compression.ZipFile]::ExtractToDirectory((Join-Path $PSScriptRoot 'widget.zip'),$source)
    . (Join-Path $source 'runtime/update.ps1')
    $version=Get-WidgetVersion $source
    $target=Get-WidgetUpdatePath $source $DataDir
    if(!$target){$target=Join-Path $versions $version.ToString()}
    $candidate=if([IO.Directory]::Exists($target)){$target}else{$source}
    if((Get-WidgetVersion $candidate).ToString() -ne [IO.Path]::GetFileName($target)){throw '已安装的挂件版本目录与清单不符。'}
    $shell=Join-Path $PSHOME 'powershell.exe'
    $check=& $shell -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $candidate 'widget.ps1') -CheckOnly -DataDir (Join-Path $stage 'test-profile')
    if($LASTEXITCODE -ne 0 -or !(($check -join "`n"|ConvertFrom-Json).imageLoaded)){throw '挂件启动自检失败，请重新下载安装包。'}

    $pluginManifest=Join-Path $PluginDir 'plugin.json'
    if([IO.Directory]::Exists($PluginDir)){
        if(![IO.File]::Exists($pluginManifest) -or ([IO.File]::ReadAllText($pluginManifest)|ConvertFrom-Json).name -ne 'gemini-niang'){
            throw "配套插件目录中有其他文件，已保留原内容：$PluginDir"
        }
        Sync-WidgetPlugin $candidate $PluginDir
    }else{
        $plugins=[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($PluginDir)).FullName
        $tempPlugin=Join-Path $plugins ('.gemini-niang-install-'+[guid]::NewGuid().ToString('N'))
        try{
            Copy-Item -LiteralPath (Join-Path $candidate 'antigravity-plugin') -Destination $tempPlugin -Recurse
            [IO.Directory]::Move($tempPlugin,$PluginDir)
        }finally{
            if([IO.Directory]::Exists($tempPlugin) -and [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($tempPlugin)) -eq $plugins){Remove-Item -LiteralPath $tempPlugin -Recurse -Force}
        }
    }
    # Older ZIPs of the same widget version predate the standalone icon notice.
    $notice=Join-Path $source 'antigravity-plugin/ICON-NOTICE.md'
    $installedNotice=Join-Path $PluginDir 'ICON-NOTICE.md'
    if([IO.File]::Exists($notice) -and ![IO.File]::Exists($installedNotice)){[IO.File]::Copy($notice,$installedNotice)}
    if($candidate -eq $source){[IO.Directory]::Move($source,$target)}
    $activeVersion=(Get-WidgetVersion $target).ToString()
    $pointer=Join-Path $DataDir 'active-version.txt'
    $tempPointer=Join-Path $stage 'active-version.tmp'
    [IO.File]::WriteAllText($tempPointer,$activeVersion)
    if([IO.File]::Exists($pointer)){[IO.File]::Replace($tempPointer,$pointer,[Management.Automation.Language.NullString]::Value)}else{[IO.File]::Move($tempPointer,$pointer)}

    $argsLine='-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+(Join-Path $target 'widget.ps1')+'" -DataDir "'+$DataDir+'"'
    $startup=[Environment]::GetFolderPath('Startup')
    if($startup -and $DataDir -eq (Join-Path $env:LOCALAPPDATA 'GeminiNiangWidget')){
        $existing=Join-Path $startup 'GeminiNiangWidget.lnk'
        if([IO.File]::Exists($existing)){
            $autostart=(New-Object -ComObject WScript.Shell).CreateShortcut($existing)
            if($autostart.Arguments -match 'runtime[\\/]follow-launch\.ps1"\s*$'){
                $autostart.TargetPath=Join-Path ([Environment]::SystemDirectory) 'wscript.exe'
                $autostart.Arguments='//B //NoLogo "'+(Join-Path $target 'runtime\launch-hidden.vbs')+'" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+(Join-Path $target 'runtime\follow-launch.ps1')+'"'
                $autostart.WorkingDirectory=$target
                $autostart.Save()
            }
        }
    }
    if(!$NoLaunch){
        $launchInfo=[Diagnostics.ProcessStartInfo]::new($shell,$argsLine)
        $launchInfo.UseShellExecute=$false
        $launchInfo.CreateNoWindow=$true
        $launched=[Diagnostics.Process]::Start($launchInfo)
        if($launched){$launched.Dispose()}
    }
    $message="Gemini 娘挂件 $activeVersion 已安装。打开 Antigravity 即可查看挂件。以后也可以双击安装目录中的「预览挂件.cmd」重新打开。`r`n$target`r`n`r`n已打开的 Antigravity 可在方便时重新启动，以加载配套插件。"
    if(!(Get-Command node.exe -ErrorAction SilentlyContinue)){$message+="`r`n`r`n额度气泡可以直接使用。如需配套插件的 MCP 和回复结束提醒，请安装 Node.js LTS 后重新打开 Antigravity。"}
    [IO.File]::WriteAllText($report,$message)
}catch{
    [IO.File]::WriteAllText($report,('安装未完成。'+[Environment]::NewLine+$_.Exception.Message))
    exit 1
}finally{
    if($stage -and [IO.Directory]::Exists($stage) -and [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($stage)) -eq [IO.Path]::GetFullPath($versions) -and [IO.Path]::GetFileName($stage) -match '^\.install-[0-9a-f]{32}$'){
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
    if($held){$lock.ReleaseMutex()}
    $lock.Dispose()
}
