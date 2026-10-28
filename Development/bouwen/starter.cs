using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

[assembly: AssemblyTitle("Creative Connection")]
[assembly: AssemblyDescription("Starts Creative Connection.ps1 next to this file")]
[assembly: AssemblyProduct("Creative Connection")]
[assembly: AssemblyVersion("1.0.0")]
[assembly: AssemblyFileVersion("1.0.0")]
[assembly: AssemblyInformationalVersion("1.0.0")]

static class Starter
{
    [STAThread]
    static int Main()
    {
        string folder = AppDomain.CurrentDomain.BaseDirectory;
        string app = Path.Combine(folder, "Creative Connection.ps1");
        if (!File.Exists(app))
        {
            MessageBox.Show("Creative Connection.ps1 was not found next to this file.\nKeep Creative Connection.exe in the app folder.", "Creative Connection", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return 2;
        }

        // Windows PowerShell, never another one
        string shell = Path.Combine(Environment.SystemDirectory, "WindowsPowerShell\\v1.0\\powershell.exe");
        ProcessStartInfo start = new ProcessStartInfo(shell, "-NoProfile -ExecutionPolicy Bypass -File \"" + app + "\"");
        start.UseShellExecute = false;
        start.CreateNoWindow = true;
        start.WorkingDirectory = folder;
        try
        {
            Process.Start(start);
        }
        catch (Exception problem)
        {
            MessageBox.Show("Creative Connection could not start.\n" + problem.Message, "Creative Connection", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return 1;
        }
        return 0;
    }
}
