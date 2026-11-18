param([switch]$Check)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class WidgetWindow {
    [StructLayout(LayoutKind.Sequential)]
    public struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out int pid);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hwnd, int index);
    [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr hwnd, int index, int value);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
}
'@

$window = [Windows.Markup.XamlReader]::Parse(@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Width="236" Height="196" WindowStyle="None" AllowsTransparency="True"
        ShowActivated="False" ShowInTaskbar="False" ResizeMode="NoResize" SizeToContent="Manual">
  <Grid>
    <Border Name="Bubble" HorizontalAlignment="Right" VerticalAlignment="Bottom"
            Margin="0,0,36,125" CornerRadius="14" Padding="12,6" Visibility="Collapsed"
            BorderThickness="1.5" BorderBrush="#514074" Background="#FFFCFF">
      <TextBlock FontFamily="Microsoft YaHei UI" FontSize="13" Foreground="#393052">我在这儿。</TextBlock>
    </Border>
    <Image Name="Pet" Width="120" HorizontalAlignment="Right" VerticalAlignment="Bottom"
           Cursor="Hand" RenderOptions.BitmapScalingMode="HighQuality"/>
  </Grid>
</Window>
'@)
$window.Background = $null
$pet = $window.FindName('Pet')
$bubble = $window.FindName('Bubble')
$sprite = Join-Path $PSScriptRoot 'gemini-widget.png'
$pet.Source = [Windows.Media.Imaging.BitmapImage]::new([Uri]::new($sprite))
$pet.Add_MouseLeftButtonUp({
    if ($bubble.IsVisible) { $bubble.Visibility = 'Collapsed' }
    else { $bubble.Visibility = 'Visible' }
})
$pet.Add_MouseRightButtonUp({ $window.Close() })
$pet.ToolTip = '单击说话，右键退出'
$screen = [Windows.SystemParameters]::WorkArea
$window.Left = $screen.Right - $window.Width - 12
$window.Top = $screen.Bottom - $window.Height - 12

if ($Check) {
    if ($pet.Source.PixelWidth -lt 1 -or !$bubble) { throw 'Preview asset unavailable.' }
    Write-Output "Preview loaded: $($pet.Source.PixelWidth) x $($pet.Source.PixelHeight)"
    return
}
$timer = [Windows.Threading.DispatcherTimer]::new()
$timer.Interval = [TimeSpan]::FromMilliseconds(250)
$window.Add_SourceInitialized({
    $script:widgetHandle = [Windows.Interop.WindowInteropHelper]::new($window).Handle
    $style = [WidgetWindow]::GetWindowLong($widgetHandle, -20)
    [void][WidgetWindow]::SetWindowLong($widgetHandle, -20, $style -bor 0x08000000 -bor 0x80)
})
$timer.Add_Tick({
    $foreground = [WidgetWindow]::GetForegroundWindow()
    [int]$ownerPid = 0
    [void][WidgetWindow]::GetWindowThreadProcessId($foreground, [ref]$ownerPid)
    $proc = Get-Process -Id $ownerPid -ErrorAction SilentlyContinue
    if ($proc -and $proc.ProcessName -eq 'Antigravity' -and ![WidgetWindow]::IsIconic($foreground)) {
        $script:followed = $true
        $hostRect = [WidgetWindow+Rect]::new()
        $petRect = [WidgetWindow+Rect]::new()
        $interop = [Windows.Interop.WindowInteropHelper]::new($window)
        if ($interop.Owner -ne $foreground) { $interop.Owner = $foreground }
        if (!$window.IsVisible) { $window.Show() }
        if ([WidgetWindow]::GetWindowRect($foreground,[ref]$hostRect) -and [WidgetWindow]::GetWindowRect($widgetHandle,[ref]$petRect)) {
            $x = $hostRect.Right - ($petRect.Right - $petRect.Left) - 10
            $y = $hostRect.Bottom - ($petRect.Bottom - $petRect.Top) - 10
            if ($petRect.Left -ne $x -or $petRect.Top -ne $y) {
                [void][WidgetWindow]::SetWindowPos($widgetHandle,[IntPtr]::Zero,$x,$y,0,0,0x15)
            }
        }
    } elseif ($window.IsVisible -and $script:followed -and $foreground -ne $widgetHandle) {
        $window.Hide()
    }
})
$app = [Windows.Application]::new()
$app.ShutdownMode = 'OnMainWindowClose'
$window.Add_Closed({ $timer.Stop() })
$timer.Start()
[void]$app.Run($window)
