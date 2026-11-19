using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Windows.Forms;

internal static class WidgetSetup
{
    private const string Title = "Gemini 娘挂件 · 安装";

    [STAThread]
    private static int Main()
    {
        Application.EnableVisualStyles();
        if (MessageBox.Show("为当前 Windows 用户安装 Gemini 娘挂件和 Antigravity 配套插件？\n\n安装完成后会自动打开挂件。首次使用时默认开启「登录后随反重力启动」，可在挂件右键菜单关闭。已有的语录、形象和偏好会保留。",
            Title, MessageBoxButtons.OKCancel, MessageBoxIcon.Information) != DialogResult.OK)
            return 0;

        string temp = Path.Combine(Path.GetTempPath(), "GeminiNiangSetup-" + Guid.NewGuid().ToString("N"));
        try
        {
            Directory.CreateDirectory(temp);
            foreach (string name in new[] { "widget.zip", "install-widget.ps1" })
            {
                using (Stream input = Assembly.GetExecutingAssembly().GetManifestResourceStream(name))
                using (Stream output = File.Create(Path.Combine(temp, name)))
                    input.CopyTo(output);
            }
            string shell = Path.Combine(Environment.SystemDirectory, @"WindowsPowerShell\v1.0\powershell.exe");
            var start = new ProcessStartInfo(shell, "-NoProfile -STA -ExecutionPolicy Bypass -File \"" + Path.Combine(temp, "install-widget.ps1") + "\"");
            start.UseShellExecute = false;
            start.CreateNoWindow = true;
            using (Process install = Process.Start(start))
            {
                install.WaitForExit();
                string report = Path.Combine(temp, "result.txt");
                bool ok = install.ExitCode == 0 && File.Exists(report);
                MessageBox.Show(File.Exists(report) ? File.ReadAllText(report, Encoding.UTF8) : "安装程序未能完成。请检查 Windows PowerShell 是否可用。",
                    Title, MessageBoxButtons.OK, ok ? MessageBoxIcon.Information : MessageBoxIcon.Error);
                return ok ? 0 : 1;
            }
        }
        catch (Exception e)
        {
            MessageBox.Show(e.Message, Title, MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
        finally
        {
            try { if (Directory.Exists(temp)) Directory.Delete(temp, true); } catch (IOException) { }
            catch (UnauthorizedAccessException) { }
        }
    }
}
