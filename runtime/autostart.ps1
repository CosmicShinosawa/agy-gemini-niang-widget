function Get-WidgetStartupLink {
    Join-Path ([Environment]::GetFolderPath('Startup')) 'GeminiNiangWidget.lnk'
}
function Set-WidgetAutostart([bool]$enabled) {
    $path=Get-WidgetStartupLink
    if($enabled){
        $link=(New-Object -ComObject WScript.Shell).CreateShortcut($path)
        $link.TargetPath=Join-Path $PSHOME 'powershell.exe'
        $link.Arguments='-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+(Join-Path $script:appDir 'runtime\follow-launch.ps1')+'"'
        $link.WorkingDirectory=$script:appDir;$link.Save()
        Start-Process -FilePath $link.TargetPath -ArgumentList $link.Arguments -WindowStyle Hidden
    }elseif([IO.File]::Exists($path)){[IO.File]::Delete($path)}
}
