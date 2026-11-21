function Start-WidgetHiddenPowerShell([string]$Arguments,[string]$WorkingDirectory=$null,[switch]$PassThru) {
    $info=[Diagnostics.ProcessStartInfo]::new((Join-Path $PSHOME 'powershell.exe'),$Arguments)
    $info.UseShellExecute=$false
    $info.CreateNoWindow=$true
    if($WorkingDirectory){$info.WorkingDirectory=$WorkingDirectory}
    $process=[Diagnostics.Process]::Start($info)
    if($PassThru){return $process}
    if($process){$process.Dispose()}
}
function Get-WidgetStartupLink {
    Join-Path ([Environment]::GetFolderPath('Startup')) 'GeminiNiangWidget.lnk'
}
function Get-WidgetAutostartSpec([string]$AppDir) {
    $launcher=Join-Path $AppDir 'runtime\launch-hidden.vbs'
    $watcher=Join-Path $AppDir 'runtime\follow-launch.ps1'
    @{
        TargetPath=Join-Path ([Environment]::SystemDirectory) 'wscript.exe'
        Arguments='//B //NoLogo "'+$launcher+'" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$watcher+'"'
        WatcherArguments='-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$watcher+'"'
        WorkingDirectory=$AppDir
    }
}
function Repair-WidgetAutostartLink {
    $path=Get-WidgetStartupLink
    if(![IO.File]::Exists($path)){return}
    $link=(New-Object -ComObject WScript.Shell).CreateShortcut($path)
    if($link.Arguments -notmatch 'runtime[\\/]follow-launch\.ps1"\s*$'){return}
    $spec=Get-WidgetAutostartSpec $script:appDir
    if($link.TargetPath -ne $spec.TargetPath -or $link.Arguments -ne $spec.Arguments -or $link.WorkingDirectory -ne $spec.WorkingDirectory){
        $link.TargetPath=$spec.TargetPath
        $link.Arguments=$spec.Arguments
        $link.WorkingDirectory=$spec.WorkingDirectory
        $link.Save()
    }
}
function Set-WidgetAutostart([bool]$enabled) {
    $path=Get-WidgetStartupLink
    if($enabled){
        $spec=Get-WidgetAutostartSpec $script:appDir
        $link=(New-Object -ComObject WScript.Shell).CreateShortcut($path)
        $link.TargetPath=$spec.TargetPath
        $link.Arguments=$spec.Arguments
        $link.WorkingDirectory=$spec.WorkingDirectory
        $link.Save()
        Start-WidgetHiddenPowerShell -Arguments $spec.WatcherArguments -WorkingDirectory $spec.WorkingDirectory
    }elseif([IO.File]::Exists($path)){[IO.File]::Delete($path)}
}
