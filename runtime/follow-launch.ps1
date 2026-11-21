$ErrorActionPreference='Stop'
$created=$false
$lock=[Threading.Mutex]::new($true,'Local\GeminiNiangLoginWatcher',[ref]$created)
if(!$created){$lock.Dispose();return}
$startup=Join-Path ([Environment]::GetFolderPath('Startup')) 'GeminiNiangWidget.lnk'
$widget=Join-Path (Split-Path $PSScriptRoot -Parent) 'widget.ps1'
$previous=@()
try{
    while([IO.File]::Exists($startup)){
        $current=@(Get-Process Antigravity -ErrorAction SilentlyContinue |
            Where-Object MainWindowHandle -ne 0 | ForEach-Object {$_.Id.ToString()+'@'+$_.StartTime.Ticks})
        if($current.Count -and !@($current | Where-Object {$_ -in $previous}).Count){
            $info=[Diagnostics.ProcessStartInfo]::new((Join-Path $PSHOME 'powershell.exe'),('-NoProfile -STA -ExecutionPolicy Bypass -File "'+$widget+'"'))
            $info.UseShellExecute=$false
            $info.CreateNoWindow=$true
            $child=[Diagnostics.Process]::Start($info)
            if($child){$child.Dispose()}
        }
        $previous=$current
        Start-Sleep -Seconds 3
    }
}finally{$lock.ReleaseMutex();$lock.Dispose()}
