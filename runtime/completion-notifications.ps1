if(!('CompletionWindowLayer' -as [type])){
  Add-Type -TypeDefinition @'
using System;using System.Runtime.InteropServices;
public static class CompletionWindowLayer {
 [StructLayout(LayoutKind.Sequential)]public struct Rect{public int Left,Top,Right,Bottom;}
 [DllImport("user32.dll")]public static extern bool GetWindowRect(IntPtr h,out Rect r);
 [DllImport("user32.dll")]public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")]public static extern IntPtr GetWindow(IntPtr h,uint command);
 [DllImport("user32.dll")]public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")]public static extern bool IsWindow(IntPtr h);
 [DllImport("user32.dll",EntryPoint="GetWindowLongPtrW")]public static extern IntPtr GetWindowLongPtr(IntPtr h,int i);
 [DllImport("user32.dll",EntryPoint="SetWindowLongPtrW")]public static extern IntPtr SetWindowLongPtr(IntPtr h,int i,IntPtr value);
 [DllImport("user32.dll")]public static extern bool SetWindowPos(IntPtr h,IntPtr after,int x,int y,int width,int height,uint flags);
}
'@
}

function Test-CompletionFullscreen([IntPtr]$Handle){
  if($Handle-eq [IntPtr]::Zero -or ![CompletionWindowLayer]::IsWindow($Handle)){return $false}
  $rect=New-Object CompletionWindowLayer+Rect
  if(![CompletionWindowLayer]::GetWindowRect($Handle,[ref]$rect)){return $false}
  $area=[Windows.Forms.Screen]::FromHandle($Handle).Bounds
  return $rect.Left-le $area.Left -and $rect.Top-le $area.Top -and $rect.Right-ge $area.Right -and $rect.Bottom-ge $area.Bottom
}
function Stop-TemporaryCompletion {
  $state=$script:completionTemporary;$script:completionTemporary=$null
  if(!$state){return}
  if($state.timer){$state.timer.Stop()}
  try{
    if([CompletionWindowLayer]::IsWindow($script:widgetHandle)){
      $script:window.Topmost=$state.topmost
      [CompletionWindowLayer]::SetWindowLongPtr($script:widgetHandle,-20,$state.style)|Out-Null
      $owner=if([CompletionWindowLayer]::IsWindow($state.owner)){$state.owner}else{[IntPtr]::Zero}
      $band=if(($state.style.ToInt64()-band 8)-ne 0){[IntPtr](-1)}else{[IntPtr](-2)}
      # Demote and place the detached widget before restoring its owner. An
      # owned window near the front can otherwise raise Codex with it.
      [CompletionWindowLayer]::SetWindowPos($script:widgetHandle,$band,0,0,0,0,0x213)|Out-Null
      if(!$state.visible){$script:window.Hide()}
      $after=if($owner-ne [IntPtr]::Zero){[CompletionWindowLayer]::GetWindow($owner,3)}else{$state.previous}
      while($after-ne [IntPtr]::Zero -and [CompletionWindowLayer]::IsWindow($after) -and ($after-eq $script:widgetHandle -or ![CompletionWindowLayer]::IsWindowVisible($after))){$after=[CompletionWindowLayer]::GetWindow($after,3)}
      if($after-eq $script:widgetHandle -or ![CompletionWindowLayer]::IsWindow($after) -or ([CompletionWindowLayer]::GetWindowLongPtr($after,-20).ToInt64()-band 8)-ne ($state.style.ToInt64()-band 8)){$after=[IntPtr]::Zero}
      [CompletionWindowLayer]::SetWindowPos($script:widgetHandle,$after,0,0,0,0,0x213)|Out-Null
      [CompletionWindowLayer]::SetWindowLongPtr($script:widgetHandle,-8,$owner)|Out-Null
    }
  }catch{}
  $script:lastPosition=$null;$script:attachedHost=[IntPtr]::Zero
}
function Start-TemporaryCompletion {
  if($script:completionTemporary){return $true}
  $foreground=[CompletionWindowLayer]::GetForegroundWindow()
  $script:completionTemporary=@{owner=[CompletionWindowLayer]::GetWindowLongPtr($script:widgetHandle,-8);style=[CompletionWindowLayer]::GetWindowLongPtr($script:widgetHandle,-20);topmost=$script:window.Topmost;visible=$script:window.IsVisible;previous=[CompletionWindowLayer]::GetWindow($script:widgetHandle,3);foreground=$foreground;fullscreen=(Test-CompletionFullscreen $foreground);expiresAt=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()+7000;timer=$null}
  try{
    if($script:occlusionRecovery){$script:occlusionRecovery.Configure([IntPtr]::Zero,$false)}
    if($script:hostFollower){$script:hostFollower.Detach()}
    [CompletionWindowLayer]::SetWindowLongPtr($script:widgetHandle,-8,[IntPtr]::Zero)|Out-Null
    $script:window.Show()
    $style=$script:completionTemporary.style.ToInt64()-bor 0x08000020
    [CompletionWindowLayer]::SetWindowLongPtr($script:widgetHandle,-20,[IntPtr]$style)|Out-Null
    $script:window.Topmost=$true
    if(![CompletionWindowLayer]::SetWindowPos($script:widgetHandle,[IntPtr](-1),0,0,0,0,0x13)){throw 'Temporary reminder layer failed'}
    $timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[TimeSpan]::FromMilliseconds(100)
    $timer.Add_Tick({
      if(!$script:completionTemporary){return}
      try{
        $now=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $active=Test-WidgetCompletionHostForeground
        $foreground=[CompletionWindowLayer]::GetForegroundWindow()
        $leftFullscreen=$script:completionTemporary.fullscreen -and ($foreground-ne $script:completionTemporary.foreground -or !(Test-CompletionFullscreen $foreground))
        if($active -or $leftFullscreen){Dismiss-CompletionNotification;if(!$script:collapsed){Hide-Quota -KeepCompletion}}
        # An error while opening the scene must never leave a topmost
        # click-through reminder layer pinned on screen. This independent
        # deadline works even when sceneDeadline was never set.
        elseif($now-ge $script:completionTemporary.expiresAt){Hide-Quota}
        elseif($script:sceneDeadline-gt 0 -and $now-ge $script:sceneDeadline){Hide-Quota}
      }catch{try{Stop-TemporaryCompletion}catch{}}
    })
    $script:completionTemporary.timer=$timer;$timer.Start();return $true
  }catch{
    Stop-TemporaryCompletion;$script:completionLastError=$_.Exception.Message;return $false
  }
}

function Initialize-CompletionNotificationState($Settings=$null) {
  $script:completionNotificationsEnabled=($Settings.taskCompletionBubble-is [bool] -and $Settings.taskCompletionBubble)
  $script:completionPending=$false;$script:completionProcess=$null;$script:completionRetryAfter=0
  $script:completionReceived=0;$script:completionDisplayCount=0;$script:completionLastError=$null
  $script:completionAcknowledgedAt=0;$script:completionTemporary=$null
}
function Clear-CompletionNotifications {$script:completionPending=$false}
function Dismiss-CompletionNotification {
  Stop-TemporaryCompletion
  $script:completionAcknowledgedAt=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $script:completionPending=$false;Reset-WidgetAutoQuoteSchedule
}

function Set-CompletionNotificationEnabled([bool]$Enabled) {
  if($Enabled-eq $script:completionNotificationsEnabled){return}
  $script:completionNotificationsEnabled=$Enabled;$script:completionRetryAfter=0
  if(!$Enabled){
    Clear-CompletionNotifications
    $script:completionLastError=$null
    if(!$script:collapsed -and $script:bubbleMode-eq 'completion'){Hide-Quota}
  }
  Reset-WidgetAutoQuoteSchedule;Save-Settings
}
function Receive-CompletionMonitorLine([string]$Line) {
  if(!$script:completionNotificationsEnabled -or $Line.Length-gt 2048){return}
  try{
    $event=$Line|ConvertFrom-Json
    if($event.type-ne 'completion' -or $event.sessionId-isnot [string] -or $event.turnId-isnot [string] -or !$event.sessionId -or !$event.turnId){return}
    if($null-eq $event.endedAt -or [double]$event.endedAt-lt $script:completionAcknowledgedAt){return}
    $script:completionReceived++;$script:completionPending=$true
  }catch{}
}
function Read-CompletionMonitorOutput {
  $file=Join-Path $script:dataDir 'completion.json'
  if(![IO.File]::Exists($file)){return}
  $stamp=[IO.File]::GetLastWriteTimeUtc($file)
  if($stamp -eq $script:lastCompletionStamp -or ([DateTime]::UtcNow-$stamp).TotalSeconds -gt 60){return}
  try{
    $line=[IO.File]::ReadAllText($file)
    Receive-CompletionMonitorLine $line
    $script:lastCompletionStamp=$stamp
  }catch [IO.IOException]{}
}
function Test-CompletionDisplayAllowed([bool]$Visible) {
  return $Visible -and $script:window.IsVisible -and ![bool]$script:drag -and !$script:context.IsOpen -and !$script:settingsSizePreview -and !(Test-WidgetEditorOpen) -and (Test-WidgetCompletionForeground)
}
function Pause-CompletionNotification {
  Stop-TemporaryCompletion
  if(!$script:collapsed -and $script:bubbleMode-eq 'completion'){Hide-Quota -KeepCompletion}
}
function Tick-CompletionNotifications([bool]$Visible) {
  if(!$script:completionNotificationsEnabled){return}
  Read-CompletionMonitorOutput
  $busy=[bool]$script:drag -or $script:context.IsOpen -or $script:settingsSizePreview -or (Test-WidgetEditorOpen)
  if($busy){Pause-CompletionNotification;return}
  if($script:completionTemporary){return}
  $foreground=Test-WidgetCompletionHostForeground
  if($foreground){
    if(!(Test-CompletionDisplayAllowed $Visible)){Pause-CompletionNotification;return}
  }elseif(!$script:collapsed){
    if($script:bubbleMode-eq 'completion'){Pause-CompletionNotification};return
  }
  if(!$script:completionPending -or !$script:collapsed -or ($script:closeTimer -and $script:closeTimer.IsEnabled)){return}
  if(!$foreground -and !(Start-TemporaryCompletion)){return}
  Open-WidgetBubble 'completion';$script:completionDisplayCount++
}
function Get-CompletionNotificationStatus {
  $monitorPid=0
  if($script:completionProcess){try{if(!$script:completionProcess.HasExited){$monitorPid=$script:completionProcess.Id}}catch{}}
  return @{enabled=[bool]$script:completionNotificationsEnabled;pending=[bool]$script:completionPending;temporaryTopmost=[bool]$script:completionTemporary;showing=(!$script:collapsed -and $script:bubbleMode-eq 'completion');received=$script:completionReceived;displayCount=$script:completionDisplayCount;monitorPid=$monitorPid;error=$script:completionLastError}
}
