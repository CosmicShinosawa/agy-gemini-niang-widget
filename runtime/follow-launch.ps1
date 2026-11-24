$ErrorActionPreference='Stop'
$dataDir=Join-Path $env:LOCALAPPDATA 'GeminiNiangWidget'
$appDir=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'update.ps1')
$currentVersion=Get-WidgetVersion $appDir

$lock=[Threading.Mutex]::new($false,'Local\GeminiNiangLoginWatcher')
$lockOwned=$false
for($attempt=0;$attempt -lt 10;$attempt++){
    try{$lockOwned=$lock.WaitOne(0)}catch [Threading.AbandonedMutexException]{$lockOwned=$true}
    if($lockOwned){break}
    Start-Sleep -Milliseconds 300
}
if(!$lockOwned){$lock.Dispose();return}

if(!('GeminiNiangLaunchWatcherNative' -as [type])){
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

public static class GeminiNiangLaunchWatcherNative {
  static readonly int Session = CurrentSession();
  static int CurrentSession() { using (var p = Process.GetCurrentProcess()) return p.SessionId; }

  public delegate bool EnumProc(IntPtr h, IntPtr p);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr p);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder b, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder b, int n);
  [DllImport("user32.dll", EntryPoint="GetWindowLongPtrW")] static extern IntPtr GetWindowLongPtr(IntPtr h, int i);

  public static bool HasVisibleAntigravityWindow() {
    bool found = false;
    EnumWindows((h, p) => {
      if (!IsWindowVisible(h) || (GetWindowLongPtr(h, -20).ToInt64() & 0x80) != 0) return true;
      var title = new StringBuilder(256);
      GetWindowText(h, title, 256);
      if (title.Length == 0) return true;
      var cls = new StringBuilder(128);
      GetClassName(h, cls, 128);
      if (cls.ToString() != "Chrome_WidgetWin_1") return true;
      uint pid;
      GetWindowThreadProcessId(h, out pid);
      try {
        using (var proc = Process.GetProcessById((int)pid)) {
          if (proc.SessionId == Session && proc.ProcessName.Equals("Antigravity", StringComparison.OrdinalIgnoreCase)) {
            found = true;
            return false;
          }
        }
      } catch {}
      return true;
    }, IntPtr.Zero);
    return found;
  }

  public static string[] GetAntigravitySessionKeys() {
    var keys = new List<string>();
    foreach (var proc in Process.GetProcessesByName("Antigravity")) {
      try {
        if (proc.SessionId == Session) {
          keys.Add(proc.Id.ToString() + "@" + proc.StartTime.Ticks.ToString());
        }
      } catch {} finally { proc.Dispose(); }
    }
    return keys.ToArray();
  }
}
'@
}

function Test-WidgetRunning([string]$TargetDataDir) {
    $mutexKey='Local\GeminiNiangWidget_'+([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFullPath($TargetDataDir).ToUpperInvariant()))).Replace('/','_').Replace('+','-')
    $existing=$null
    if([Threading.Mutex]::TryOpenExisting($mutexKey,[ref]$existing)){
        $existing.Dispose()
        return $true
    }
    return $false
}

function Test-ManualExitActive([string]$TargetDataDir,[string[]]$ActiveKeys) {
    $file=Join-Path $TargetDataDir 'manual-exit.json'
    if(![IO.File]::Exists($file)){return $false}
    try{
        $record=[IO.File]::ReadAllText($file) | ConvertFrom-Json
        $saved=@($record.pids)
        if($saved.Count -and @($ActiveKeys | Where-Object {$_ -in $saved}).Count){
            return $true
        }
        Remove-Item -LiteralPath $file -ErrorAction SilentlyContinue
    }catch{
        Remove-Item -LiteralPath $file -ErrorAction SilentlyContinue
    }
    return $false
}

function Start-HiddenPowerShell([string]$Arguments,[string]$WorkingDirectory) {
    $info=[Diagnostics.ProcessStartInfo]::new((Join-Path $PSHOME 'powershell.exe'),$Arguments)
    $info.UseShellExecute=$false
    $info.CreateNoWindow=$true
    if($WorkingDirectory){$info.WorkingDirectory=$WorkingDirectory}
    $child=[Diagnostics.Process]::Start($info)
    if($child){$child.Dispose()}
}

$startup=Join-Path ([Environment]::GetFolderPath('Startup')) 'GeminiNiangWidget.lnk'
$lastLaunchAt=[DateTimeOffset]::MinValue
$handoffWatcher=$null
try{
    while([IO.File]::Exists($startup)){
        $updatedDir=Get-WidgetUpdatePath $appDir $dataDir
        if($updatedDir){
            $nextWatcher=Join-Path $updatedDir 'runtime\follow-launch.ps1'
            if([IO.File]::Exists($nextWatcher)){
                $handoffWatcher=@{script=$nextWatcher;dir=$updatedDir}
                break
            }
        }

        $hasWindow=[GeminiNiangLaunchWatcherNative]::HasVisibleAntigravityWindow()
        if($hasWindow){
            $sessionKeys=@([GeminiNiangLaunchWatcherNative]::GetAntigravitySessionKeys())
            $now=[DateTimeOffset]::UtcNow
            if(!(Test-WidgetRunning $dataDir) -and !(Test-ManualExitActive $dataDir $sessionKeys) -and ($now-$lastLaunchAt).TotalSeconds -ge 8){
                $widget=Join-Path $appDir 'widget.ps1'
                Start-HiddenPowerShell ('-NoProfile -STA -ExecutionPolicy Bypass -File "'+$widget+'"') $appDir
                $lastLaunchAt=$now
            }
        }
        Start-Sleep -Seconds 2
    }
}finally{
    if($lockOwned){try{$lock.ReleaseMutex()}catch{}}
    $lock.Dispose()
}

if($handoffWatcher){
    Start-HiddenPowerShell ('-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$handoffWatcher.script+'"') $handoffWatcher.dir
}
