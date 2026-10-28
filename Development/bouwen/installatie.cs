using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Text;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: AssemblyTitle("Creative Connection Setup")]
[assembly: AssemblyDescription("Installs Creative Connection for the current user")]
[assembly: AssemblyProduct("Creative Connection")]
[assembly: AssemblyVersion("1.0.1")]
[assembly: AssemblyFileVersion("1.0.1")]
[assembly: AssemblyInformationalVersion("1.0.1")]

namespace CreativeConnectionSetup
{
    public static class Facts
    {
        public const string Version = "1.0.1";
        public const string Name = "Creative Connection";
        public const string AppFile = "Creative Connection.ps1";
        public const string StarterFile = "Creative Connection.exe";
        public const string UninstallerFile = "Uninstall Creative Connection.exe";
        public const string LinkFile = "Creative Connection.lnk";
        public const string FolderLinkFile = "Creative Connection folder.lnk";
        public const string DefaultKey = "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\CreativeConnection";
    }

    public enum Code
    {
        Done = 0,
        Failed = 1,
        BadOptions = 2,
        InUse = 3,
        NotOurFolder = 4,
        NotInstalled = 5,
        Cancelled = 6
    }

    public sealed class Options
    {
        public bool Uninstall;
        public bool Quiet;
        public bool Start;
        public bool DirGiven;
        public bool KeyGiven;
        public string Dir;
        public string DesktopDir;
        public string StartMenuDir;
        public string Key = Facts.DefaultKey;
        public int WaitFor;

        public Options()
        {
            Dir = Path.Combine(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs"), Facts.Name);
            DesktopDir = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
            StartMenuDir = Environment.GetFolderPath(Environment.SpecialFolder.Programs);
        }

        static string Full(string value)
        {
            if (string.IsNullOrEmpty(value)) throw new ArgumentException("A folder is missing after =.");
            return Path.GetFullPath(value).TrimEnd('\\');
        }

        public static Options Parse(string[] args)
        {
            Options o = new Options();
            foreach (string raw in args)
            {
                string name = raw.Trim();
                string value = null;
                int equals = name.IndexOf('=');
                if (equals > 0)
                {
                    value = name.Substring(equals + 1).Trim('"');
                    name = name.Substring(0, equals);
                }
                name = name.ToLowerInvariant();
                if (name == "/uninstall") o.Uninstall = true;
                else if (name == "/quiet") o.Quiet = true;
                else if (name == "/start") o.Start = true;
                else if (name == "/dir") { o.Dir = Full(value); o.DirGiven = true; }
                else if (name == "/desktop") o.DesktopDir = value == "none" ? "" : Full(value);
                else if (name == "/startmenu") o.StartMenuDir = value == "none" ? "" : Full(value);
                else if (name == "/key") { o.Key = value ?? ""; o.KeyGiven = true; }
                else if (name == "/wait") o.WaitFor = int.Parse(value ?? "0");
                else throw new ArgumentException("Unknown option: " + raw);
            }
            // Never another program's key
            bool own = string.Equals(o.Key, Facts.DefaultKey, StringComparison.OrdinalIgnoreCase) || o.Key.StartsWith("Software\\CreativeConnection-", StringComparison.OrdinalIgnoreCase);
            if (!own) throw new ArgumentException("/key must be the Creative Connection key or start with Software\\CreativeConnection-");
            return o;
        }

        public string Again()
        {
            string line = "/uninstall /dir=\"" + Dir + "\"";
            if (Quiet) line += " /quiet";
            if (KeyGiven) line += " /key=\"" + Key + "\"";
            return line;
        }
    }

    public sealed class Outcome
    {
        public Code Code = Code.Done;
        public string Message = "";
        public string Note = "";
        public List<string> Left = new List<string>();
    }

    public static class Payload
    {
        public static List<KeyValuePair<string, byte[]>> Read()
        {
            List<KeyValuePair<string, byte[]>> files = new List<KeyValuePair<string, byte[]>>();
            using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("payload.zip"))
            using (ZipArchive zip = new ZipArchive(stream, ZipArchiveMode.Read))
            {
                foreach (ZipArchiveEntry entry in zip.Entries)
                {
                    if (entry.FullName.EndsWith("/")) continue;
                    using (Stream read = entry.Open())
                    using (MemoryStream copy = new MemoryStream())
                    {
                        read.CopyTo(copy);
                        files.Add(new KeyValuePair<string, byte[]>(Safe(entry.FullName), copy.ToArray()));
                    }
                }
            }
            return files;
        }

        // Only plain names inside folder
        static string Safe(string name)
        {
            string rel = name.Replace('/', '\\');
            if (rel.StartsWith("\\") || rel.IndexOf(':') >= 0) throw new InvalidDataException("Bad name in the payload: " + name);
            foreach (string part in rel.Split('\\'))
            {
                if (part.Length == 0 || part == "." || part == "..") throw new InvalidDataException("Bad name in the payload: " + name);
            }
            return rel;
        }
    }

    static class Links
    {
        [ComImport, Guid("00021401-0000-0000-C000-000000000046")]
        class ShellLink
        {
        }

        [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("000214F9-0000-0000-C000-000000000046")]
        interface IShellLinkW
        {
            void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder file, int size, IntPtr data, int flags);
            void GetIDList(out IntPtr list);
            void SetIDList(IntPtr list);
            void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder name, int size);
            void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string name);
            void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder dir, int size);
            void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string dir);
            void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder args, int size);
            void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string args);
            void GetHotkey(out short key);
            void SetHotkey(short key);
            void GetShowCmd(out int show);
            void SetShowCmd(int show);
            void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder path, int size, out int index);
            void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string path, int index);
            void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string path, int reserved);
            void Resolve(IntPtr window, int flags);
            void SetPath([MarshalAs(UnmanagedType.LPWStr)] string file);
        }

        public static void Make(string file, string target, string folder)
        {
            IShellLinkW link = (IShellLinkW)new ShellLink();
            try
            {
                link.SetPath(target);
                link.SetWorkingDirectory(folder);
                link.SetIconLocation(target, 0);
                link.SetDescription(Facts.Name);
                ((IPersistFile)link).Save(file, true);
            }
            finally
            {
                Marshal.ReleaseComObject(link);
            }
        }

        public static string Target(string file)
        {
            IShellLinkW link = (IShellLinkW)new ShellLink();
            try
            {
                ((IPersistFile)link).Load(file, 0);
                StringBuilder path = new StringBuilder(1024);
                link.GetPath(path, path.Capacity, IntPtr.Zero, 4);
                return path.ToString();
            }
            catch (COMException)
            {
                return null;
            }
            finally
            {
                Marshal.ReleaseComObject(link);
            }
        }
    }

    public static class Engine
    {
        public static bool SamePath(string a, string b)
        {
            if (string.IsNullOrEmpty(a) || string.IsNullOrEmpty(b)) return false;
            return string.Equals(Path.GetFullPath(a).TrimEnd('\\'), Path.GetFullPath(b).TrimEnd('\\'), StringComparison.OrdinalIgnoreCase);
        }

        public static bool IsInside(string file, string dir)
        {
            return Path.GetFullPath(file).StartsWith(Path.GetFullPath(dir).TrimEnd('\\') + "\\", StringComparison.OrdinalIgnoreCase);
        }

        static bool IsEmpty(string dir)
        {
            using (IEnumerator<string> items = Directory.EnumerateFileSystemEntries(dir).GetEnumerator())
            {
                return !items.MoveNext();
            }
        }

        static bool Same(byte[] a, byte[] b)
        {
            if (a.Length != b.Length) return false;
            for (int i = 0; i < a.Length; i++)
            {
                if (a[i] != b[i]) return false;
            }
            return true;
        }

        // Nobody else has it open
        static bool Free(string file)
        {
            try
            {
                using (new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.None))
                {
                }
                return true;
            }
            catch (IOException)
            {
                return false;
            }
            catch (UnauthorizedAccessException)
            {
                return false;
            }
        }

        static void Write(string target, byte[] data)
        {
            if (File.Exists(target) && Same(File.ReadAllBytes(target), data)) return;
            Directory.CreateDirectory(Path.GetDirectoryName(target));
            string temp = target + ".new";
            try
            {
                File.WriteAllBytes(temp, data);
                if (File.Exists(target))
                {
                    File.SetAttributes(target, FileAttributes.Normal);
                    File.Replace(temp, target, null);
                }
                else
                {
                    File.Move(temp, target);
                }
            }
            finally
            {
                if (File.Exists(temp)) File.Delete(temp);
            }
        }

        static void TryRemoveEmpty(string dir)
        {
            try
            {
                if (Directory.Exists(dir) && IsEmpty(dir)) Directory.Delete(dir);
            }
            catch (IOException)
            {
            }
            catch (UnauthorizedAccessException)
            {
            }
        }

        static string Read(RegistryKey key, string name)
        {
            if (key == null) return "";
            return (key.GetValue(name) as string) ?? "";
        }

        public static string InstalledVersion(Options o)
        {
            using (RegistryKey key = Registry.CurrentUser.OpenSubKey(o.Key))
            {
                return key == null ? null : (key.GetValue("DisplayVersion") as string);
            }
        }

        public static string InstalledDir(Options o)
        {
            using (RegistryKey key = Registry.CurrentUser.OpenSubKey(o.Key))
            {
                string dir = Read(key, "InstallLocation");
                return dir.Length > 0 ? dir : null;
            }
        }

        public static bool HasLink(Options o, string name)
        {
            using (RegistryKey key = Registry.CurrentUser.OpenSubKey(o.Key))
            {
                string link = Read(key, name);
                return link.Length > 0 && File.Exists(link);
            }
        }

        static bool Ours(string link, string target)
        {
            return File.Exists(link) && SamePath(Links.Target(link), target);
        }

        static string MakeLink(string folder, string name, string target, string dir, Outcome result)
        {
            if (string.IsNullOrEmpty(folder)) return "";
            Directory.CreateDirectory(folder);
            string link = Path.Combine(folder, name);
            if (File.Exists(link) && !Ours(link, target))
            {
                result.Note = "A shortcut called " + Path.GetFileNameWithoutExtension(name) + " was already in " + folder + ". It was left as it is.";
                return "";
            }
            Links.Make(link, target, dir);
            return link;
        }

        static readonly string[] LinkNames = new string[] { "StartMenuShortcut", "DesktopShortcut", "StartMenuFolderShortcut", "DesktopFolderShortcut" };

        public static Outcome Install(Options o, bool desktop, bool desktopFolder)
        {
            Outcome result = new Outcome();
            try
            {
                string dir = o.Dir;
                if (Directory.Exists(dir) && !IsEmpty(dir) && !File.Exists(Path.Combine(dir, Facts.AppFile)))
                {
                    result.Code = Code.NotOurFolder;
                    result.Message = "This folder is not empty and has no Creative Connection in it: " + dir;
                    return result;
                }
                List<KeyValuePair<string, byte[]>> files = Payload.Read();
                string self = Application.ExecutablePath;
                string uninstaller = Path.Combine(dir, Facts.UninstallerFile);
                foreach (KeyValuePair<string, byte[]> file in files)
                {
                    string target = Path.Combine(dir, file.Key);
                    if (File.Exists(target) && !Free(target))
                    {
                        result.Code = Code.InUse;
                        result.Message = "Close Creative Connection first, then try again. This file is in use: " + file.Key;
                        return result;
                    }
                }
                if (File.Exists(uninstaller) && !SamePath(self, uninstaller) && !Free(uninstaller))
                {
                    result.Code = Code.InUse;
                    result.Message = "Close the other setup window first, then try again.";
                    return result;
                }

                long size = 0;
                foreach (KeyValuePair<string, byte[]> file in files)
                {
                    Write(Path.Combine(dir, file.Key), file.Value);
                    size += file.Value.Length;
                }
                byte[] me = File.ReadAllBytes(self);
                if (!SamePath(self, uninstaller)) Write(uninstaller, me);
                size += me.Length;

                string starter = Path.Combine(dir, Facts.StarterFile);
                string[] old = new string[LinkNames.Length];
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(o.Key))
                {
                    for (int i = 0; i < LinkNames.Length; i++) old[i] = Read(key, LinkNames[i]);
                }
                string[] made = new string[] {
                    MakeLink(o.StartMenuDir, Facts.LinkFile, starter, dir, result),
                    MakeLink(desktop ? o.DesktopDir : "", Facts.LinkFile, starter, dir, result),
                    MakeLink(o.StartMenuDir, Facts.FolderLinkFile, dir, dir, result),
                    MakeLink(desktopFolder ? o.DesktopDir : "", Facts.FolderLinkFile, dir, dir, result)
                };
                foreach (string gone in old)
                {
                    if (gone.Length == 0 || Array.Exists(made, delegate(string m) { return SamePath(m, gone); })) continue;
                    if (Ours(gone, starter) || Ours(gone, dir)) File.Delete(gone);
                }

                string extra = o.KeyGiven ? " /key=\"" + o.Key + "\"" : "";
                using (RegistryKey key = Registry.CurrentUser.CreateSubKey(o.Key))
                {
                    key.SetValue("DisplayName", Facts.Name);
                    key.SetValue("DisplayVersion", Facts.Version);
                    key.SetValue("DisplayIcon", starter + ",0");
                    key.SetValue("InstallLocation", dir);
                    key.SetValue("InstallDate", DateTime.Now.ToString("yyyyMMdd"));
                    key.SetValue("UninstallString", "\"" + uninstaller + "\" /uninstall" + extra);
                    key.SetValue("QuietUninstallString", "\"" + uninstaller + "\" /uninstall /quiet" + extra);
                    key.SetValue("NoModify", 1, RegistryValueKind.DWord);
                    key.SetValue("NoRepair", 1, RegistryValueKind.DWord);
                    key.SetValue("EstimatedSize", (int)(size / 1024), RegistryValueKind.DWord);
                    for (int i = 0; i < LinkNames.Length; i++) key.SetValue(LinkNames[i], made[i]);
                }
            }
            catch (Exception problem)
            {
                result.Code = Code.Failed;
                result.Message = problem.Message;
            }
            return result;
        }

        public static Outcome Uninstall(Options o)
        {
            Outcome result = new Outcome();
            try
            {
                string dir;
                string[] links = new string[LinkNames.Length];
                bool known;
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(o.Key))
                {
                    known = key != null;
                    dir = o.DirGiven ? o.Dir : Read(key, "InstallLocation");
                    for (int i = 0; i < LinkNames.Length; i++) links[i] = Read(key, LinkNames[i]);
                }
                if (dir.Length == 0 || !File.Exists(Path.Combine(dir, Facts.StarterFile)) && !known)
                {
                    result.Code = Code.NotInstalled;
                    result.Message = "Creative Connection is not installed for this user.";
                    return result;
                }
                List<KeyValuePair<string, byte[]>> files = Payload.Read();
                foreach (KeyValuePair<string, byte[]> file in files)
                {
                    string target = Path.Combine(dir, file.Key);
                    if (File.Exists(target) && !Free(target))
                    {
                        result.Code = Code.InUse;
                        result.Message = "Close Creative Connection first, then try again. This file is in use: " + file.Key;
                        return result;
                    }
                }

                // Only files we put there
                List<string> folders = new List<string>();
                foreach (KeyValuePair<string, byte[]> file in files)
                {
                    string target = Path.Combine(dir, file.Key);
                    if (File.Exists(target) && Same(File.ReadAllBytes(target), file.Value))
                    {
                        File.SetAttributes(target, FileAttributes.Normal);
                        File.Delete(target);
                    }
                    string parent = Path.GetDirectoryName(file.Key);
                    while (!string.IsNullOrEmpty(parent))
                    {
                        if (!folders.Contains(parent)) folders.Add(parent);
                        parent = Path.GetDirectoryName(parent);
                    }
                }
                string uninstaller = Path.Combine(dir, Facts.UninstallerFile);
                if (File.Exists(uninstaller) && !SamePath(uninstaller, Application.ExecutablePath)) File.Delete(uninstaller);
                folders.Sort(delegate(string a, string b) { return b.Length.CompareTo(a.Length); });
                foreach (string folder in folders) TryRemoveEmpty(Path.Combine(dir, folder));
                TryRemoveEmpty(dir);

                string starter = Path.Combine(dir, Facts.StarterFile);
                foreach (string link in links)
                {
                    if (link.Length > 0 && (Ours(link, starter) || Ours(link, dir))) File.Delete(link);
                }
                Registry.CurrentUser.DeleteSubKeyTree(o.Key, false);
                o.Dir = dir;
                if (Directory.Exists(dir))
                {
                    foreach (string left in Directory.EnumerateFiles(dir, "*", SearchOption.AllDirectories)) result.Left.Add(left.Substring(dir.Length + 1));
                }
            }
            catch (Exception problem)
            {
                result.Code = Code.Failed;
                result.Message = problem.Message;
            }
            return result;
        }

        public static string StartApp(string dir)
        {
            try
            {
                ProcessStartInfo start = new ProcessStartInfo(Path.Combine(dir, Facts.StarterFile));
                start.UseShellExecute = false;
                start.WorkingDirectory = dir;
                Process.Start(start);
                return null;
            }
            catch (Exception problem)
            {
                return problem.Message;
            }
        }
    }

    static class Program
    {
        [STAThread]
        static int Main(string[] args)
        {
            Options o;
            try
            {
                o = Options.Parse(args);
            }
            catch (Exception problem)
            {
                if (Array.IndexOf(args, "/quiet") < 0) MessageBox.Show(problem.Message, "Creative Connection Setup");
                return (int)Code.BadOptions;
            }
            if (o.WaitFor > 0)
            {
                try
                {
                    Process.GetProcessById(o.WaitFor).WaitForExit(15000);
                }
                catch (ArgumentException)
                {
                }
            }

            // Update where it already is
            if (!o.Uninstall && !o.DirGiven)
            {
                string known = Engine.InstalledDir(o);
                if (known != null) o.Dir = known;
            }

            // Uninstaller cannot delete itself
            if (o.Uninstall)
            {
                string dir = o.DirGiven ? o.Dir : Engine.InstalledDir(o);
                if (dir != null && Engine.IsInside(Application.ExecutablePath, dir))
                {
                    o.Dir = dir;
                    string copy = Path.Combine(Path.GetTempPath(), "cc-uninstall-" + Guid.NewGuid().ToString("N") + ".exe");
                    File.Copy(Application.ExecutablePath, copy);
                    ProcessStartInfo again = new ProcessStartInfo(copy, o.Again() + " /wait=" + Process.GetCurrentProcess().Id);
                    again.UseShellExecute = false;
                    Process.Start(again);
                    return 0;
                }
            }

            if (o.Quiet)
            {
                Outcome result = o.Uninstall ? Engine.Uninstall(o) : Engine.Install(o, o.DesktopDir.Length > 0, o.DesktopDir.Length > 0);
                if (result.Code == Code.Done && o.Start && !o.Uninstall && Engine.StartApp(o.Dir) != null) return (int)Code.Failed;
                return (int)result.Code;
            }

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            SetupForm form = new SetupForm(o);
            Application.Run(form);
            return (int)form.Result;
        }
    }

    public enum Stage
    {
        Install,
        Update,
        Remove,
        Removed,
        Installed,
        Failed
    }

    public sealed class SetupForm : Form
    {
        public static readonly Color Card = Color.FromArgb(28, 29, 35);
        public static readonly Color Well = Color.FromArgb(43, 47, 53);
        public static readonly Color WellHover = Color.FromArgb(52, 56, 64);
        public static readonly Color Ink = Color.FromArgb(255, 255, 255);
        public static readonly Color Soft = Color.FromArgb(201, 204, 209);
        public static readonly Color Muted = Color.FromArgb(151, 154, 160);
        public static readonly Color Mint = Color.FromArgb(140, 250, 215);
        public static readonly Color Coral = Color.FromArgb(255, 155, 145);

        [DllImport("dwmapi.dll")]
        static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);

        readonly Options options;
        readonly float scale;
        readonly Font titleFont, bodyFont, smallFont, buttonFont;
        readonly Image mascot;
        readonly PillButton main, other, change;
        readonly TickBox desktop, folderLink;
        Stage stage;
        bool tick, canChange;
        Stage before;
        string title = "", sub = "", body = "", path = "", note = "";
        Rectangle mascotBox, titleBox, subBox, bodyBox, wellBox, noteBox;

        public Code Result = Code.Cancelled;

        public SetupForm(Options o) : this(o, null)
        {
        }

        public SetupForm(Options o, Stage? show)
        {
            options = o;
            using (Graphics screen = Graphics.FromHwnd(IntPtr.Zero)) scale = screen.DpiX / 96f;
            titleFont = Pick("Segoe UI Variable Display Semib", "Segoe UI Semibold", 15f);
            bodyFont = Pick("Segoe UI Variable Text", "Segoe UI", 10f);
            smallFont = Pick("Segoe UI Variable Small", "Segoe UI", 9f);
            buttonFont = Pick("Segoe UI Variable Text Semibold", "Segoe UI Semibold", 10f);
            Assembly me = Assembly.GetExecutingAssembly();
            using (Stream png = me.GetManifestResourceStream("logo.png")) mascot = png == null ? null : new Bitmap(png);
            using (Stream ico = me.GetManifestResourceStream("logo.ico")) if (ico != null) Icon = new Icon(ico);

            Text = "Creative Connection Setup";
            AutoScaleMode = AutoScaleMode.None;
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            BackColor = Card;
            ForeColor = Ink;
            Font = bodyFont;
            DoubleBuffered = true;

            main = new PillButton();
            main.Font = buttonFont;
            main.Radius = Px(8);
            main.Click += delegate { Go(); };
            other = new PillButton();
            other.Font = buttonFont;
            other.Radius = Px(8);
            other.Fill = Well;
            other.Hover = WellHover;
            other.Ink = Ink;
            other.Click += delegate { Other(); };
            change = new PillButton();
            change.Font = smallFont;
            change.Radius = Px(8);
            change.Fill = Well;
            change.Hover = WellHover;
            change.Ink = Ink;
            change.Text = "Change\u2026";
            change.Click += delegate { ChooseFolder(); };
            desktop = new TickBox();
            desktop.Font = bodyFont;
            desktop.Text = "App shortcut on the desktop";
            desktop.Box = Px(18);
            desktop.Gap = Px(10);
            folderLink = new TickBox();
            folderLink.Font = bodyFont;
            folderLink.Text = "Folder shortcut on the desktop";
            folderLink.Box = Px(18);
            folderLink.Gap = Px(10);
            Controls.Add(change);
            Controls.Add(desktop);
            Controls.Add(folderLink);
            Controls.Add(other);
            Controls.Add(main);
            AcceptButton = main;

            Stage first;
            if (show.HasValue) first = show.Value;
            else if (o.Uninstall) first = Stage.Remove;
            else first = Engine.InstalledVersion(o) != null || File.Exists(Path.Combine(o.Dir, Facts.AppFile)) ? Stage.Update : Stage.Install;
            desktop.Checked = first == Stage.Update ? Engine.HasLink(o, "DesktopShortcut") : true;
            folderLink.Checked = first == Stage.Update ? Engine.HasLink(o, "DesktopFolderShortcut") : true;
            ShowStage(first, "");
        }

        Font Pick(string family, string fallback, float size)
        {
            using (InstalledFontCollection fonts = new InstalledFontCollection())
            {
                foreach (FontFamily f in fonts.Families)
                {
                    if (f.Name == family) return new Font(family, size);
                }
            }
            return new Font(fallback, size);
        }

        int Px(float value)
        {
            return (int)Math.Round(value * scale);
        }

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            int on = 1;
            DwmSetWindowAttribute(Handle, 20, ref on, 4);
            int caption = Card.R | (Card.G << 8) | (Card.B << 16);
            DwmSetWindowAttribute(Handle, 35, ref caption, 4);
            int text = Muted.R | (Muted.G << 8) | (Muted.B << 16);
            DwmSetWindowAttribute(Handle, 36, ref text, 4);
            int border = Well.R | (Well.G << 8) | (Well.B << 16);
            DwmSetWindowAttribute(Handle, 34, ref border, 4);
        }

        protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
        {
            if (keyData == Keys.Escape && other.Enabled)
            {
                Close();
                return true;
            }
            return base.ProcessCmdKey(ref msg, keyData);
        }

        protected override void OnShown(EventArgs e)
        {
            base.OnShown(e);
            main.Focus();
        }

        public void ShowStage(Stage next, string message)
        {
            if (next != Stage.Failed) before = next;
            stage = next;
            path = options.Dir;
            note = "";
            main.Enabled = true;
            main.Fill = Mint;
            main.Hover = Color.FromArgb(170, 252, 226);
            main.Ink = Card;
            tick = false;
            canChange = false;
            other.Visible = true;
            if (next == Stage.Install)
            {
                title = "Ready to install";
                sub = "Version " + Facts.Version;
                body = "Installs for you only, no admin rights needed. You also find the folder in Start, as Creative Connection folder.";
                tick = true;
                canChange = true;
                main.Text = "Install";
                other.Text = "Cancel";
            }
            else if (next == Stage.Update)
            {
                string now = Engine.InstalledVersion(options);
                title = "Ready to update";
                sub = "Version " + Facts.Version + (now != null && now != Facts.Version ? ", now " + now : "");
                body = "Your own scripts, log and names stay as they are.";
                tick = true;
                main.Text = "Update";
                other.Text = "Cancel";
            }
            else if (next == Stage.Remove)
            {
                string dir = options.DirGiven ? options.Dir : Engine.InstalledDir(options);
                if (dir != null) path = dir;
                title = "Remove the app?";
                sub = "Version " + (Engine.InstalledVersion(options) ?? Facts.Version);
                body = "The app, its shortcuts and its entry in Windows go. Your own scripts, log and names stay in this folder.";
                main.Text = "Remove";
                main.Fill = Coral;
                main.Hover = Color.FromArgb(255, 180, 172);
                other.Text = "Cancel";
            }
            else if (next == Stage.Removed)
            {
                title = "Removed";
                sub = "";
                body = message.Length > 0 ? "Your own files are still in this folder." : "Nothing was left behind.";
                if (message.Length == 0) path = "";
                main.Text = "Close";
                other.Text = "Open folder";
                other.Visible = message.Length > 0;
            }
            else if (next == Stage.Installed)
            {
                title = "Installed";
                sub = "Version " + Facts.Version;
                body = "Creative Connection is starting.";
                note = message;
                main.Text = "Close";
                other.Visible = false;
            }
            else
            {
                title = before == Stage.Remove ? "Not removed" : "Not installed";
                sub = "";
                body = message;
                main.Text = "Try again";
                other.Text = "Close";
            }
            Arrange();
            Invalidate();
        }

        void Arrange()
        {
            int pad = Px(24);
            int width = Px(420);
            int inner = width - 2 * pad;
            int logo = Px(56);
            mascotBox = new Rectangle(pad, pad, logo, logo);
            int textLeft = pad + logo + Px(16);
            int titleHeight = TextRenderer.MeasureText(title, titleFont, Size.Empty, TextFormatFlags.NoPadding).Height;
            int subHeight = sub.Length > 0 ? TextRenderer.MeasureText(sub, smallFont, Size.Empty, TextFormatFlags.NoPadding).Height + Px(2) : 0;
            int block = titleHeight + subHeight;
            int top = pad + Math.Max(0, (logo - block) / 2);
            titleBox = new Rectangle(textLeft, top, width - pad - textLeft, titleHeight);
            subBox = new Rectangle(textLeft, top + titleHeight, width - pad - textLeft, subHeight);
            int y = pad + logo + Px(20);
            Size bodySize = TextRenderer.MeasureText(body, bodyFont, new Size(inner, 1000), TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix | TextFormatFlags.NoPadding);
            bodyBox = new Rectangle(pad, y, inner, bodySize.Height);
            y = bodyBox.Bottom + Px(12);
            change.Visible = canChange && path.Length > 0;
            if (path.Length > 0)
            {
                int wellWidth = inner;
                if (canChange)
                {
                    int changeWidth = Math.Max(Px(88), TextRenderer.MeasureText(change.Text, smallFont).Width + Px(28));
                    wellWidth = inner - changeWidth - Px(8);
                    change.Bounds = new Rectangle(pad + wellWidth + Px(8), y, changeWidth, Px(36));
                }
                wellBox = new Rectangle(pad, y, wellWidth, Px(36));
                y = wellBox.Bottom + Px(12);
            }
            else
            {
                wellBox = Rectangle.Empty;
            }
            desktop.Visible = tick;
            folderLink.Visible = tick;
            if (tick)
            {
                desktop.Bounds = new Rectangle(pad, y, inner, Px(28));
                folderLink.Bounds = new Rectangle(pad, desktop.Bottom + Px(2), inner, Px(28));
                y = folderLink.Bottom + Px(8);
            }
            if (note.Length > 0)
            {
                Size noteSize = TextRenderer.MeasureText(note, smallFont, new Size(inner, 1000), TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix | TextFormatFlags.NoPadding);
                noteBox = new Rectangle(pad, y, inner, noteSize.Height);
                y = noteBox.Bottom + Px(8);
            }
            else
            {
                noteBox = Rectangle.Empty;
            }
            y += Px(12);
            int buttonHeight = Px(36);
            int mainWidth = Math.Max(Px(104), TextRenderer.MeasureText(main.Text, buttonFont).Width + Px(36));
            int otherWidth = Math.Max(Px(104), TextRenderer.MeasureText(other.Text, buttonFont).Width + Px(36));
            main.Bounds = new Rectangle(width - pad - mainWidth, y, mainWidth, buttonHeight);
            other.Bounds = new Rectangle(main.Left - Px(10) - otherWidth, y, otherWidth, buttonHeight);
            ClientSize = new Size(width, y + buttonHeight + pad);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.Clear(Card);
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            if (mascot != null) g.DrawImage(mascot, mascotBox);
            TextFormatFlags line = TextFormatFlags.Left | TextFormatFlags.NoPrefix | TextFormatFlags.NoPadding | TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis;
            TextFormatFlags wrap = TextFormatFlags.Left | TextFormatFlags.NoPrefix | TextFormatFlags.NoPadding | TextFormatFlags.WordBreak;
            TextRenderer.DrawText(g, title, titleFont, titleBox, Ink, line);
            if (sub.Length > 0) TextRenderer.DrawText(g, sub, smallFont, subBox, Muted, line);
            TextRenderer.DrawText(g, body, bodyFont, bodyBox, stage == Stage.Failed ? Coral : Soft, wrap);
            if (!wellBox.IsEmpty)
            {
                using (GraphicsPath shape = PillButton.Round(wellBox, Px(8)))
                using (SolidBrush fill = new SolidBrush(Well))
                {
                    g.FillPath(fill, shape);
                }
                Rectangle text = Rectangle.Inflate(wellBox, -Px(12), 0);
                TextRenderer.DrawText(g, path, smallFont, text, Soft, TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPrefix | TextFormatFlags.SingleLine | TextFormatFlags.PathEllipsis);
            }
            if (!noteBox.IsEmpty) TextRenderer.DrawText(g, note, smallFont, noteBox, Muted, wrap);
        }

        void Go()
        {
            if (stage == Stage.Removed || stage == Stage.Installed)
            {
                Result = Code.Done;
                Close();
                return;
            }
            if (stage == Stage.Failed)
            {
                ShowStage(before, "");
                return;
            }
            bool removing = stage == Stage.Remove;
            main.Enabled = false;
            other.Enabled = false;
            main.Text = removing ? "Removing\u2026" : "Installing\u2026";
            Cursor = Cursors.WaitCursor;
            Update();
            Outcome result = removing ? Engine.Uninstall(options) : Engine.Install(options, desktop.Checked, folderLink.Checked);
            Cursor = Cursors.Default;
            other.Enabled = true;
            if (result.Code != Code.Done)
            {
                Result = result.Code;
                ShowStage(Stage.Failed, result.Message);
                return;
            }
            if (removing)
            {
                Result = Code.Done;
                ShowStage(Stage.Removed, result.Left.Count > 0 ? "left" : "");
                return;
            }
            string trouble = Engine.StartApp(options.Dir);
            if (trouble != null)
            {
                Result = Code.Failed;
                ShowStage(Stage.Failed, "Installed, but the app did not start: " + trouble);
                return;
            }
            Result = Code.Done;
            if (result.Note.Length > 0)
            {
                ShowStage(Stage.Installed, result.Note);
                return;
            }
            Close();
        }

        void ChooseFolder()
        {
            using (FolderBrowserDialog pick = new FolderBrowserDialog())
            {
                pick.Description = "Choose where Creative Connection goes. A folder called Creative Connection is made inside it.";
                pick.ShowNewFolderButton = true;
                string parent = Path.GetDirectoryName(options.Dir);
                if (parent != null && Directory.Exists(parent)) pick.SelectedPath = parent;
                if (pick.ShowDialog(this) != DialogResult.OK) return;
                string chosen = pick.SelectedPath.TrimEnd('\\');
                bool already = File.Exists(Path.Combine(chosen, Facts.AppFile)) || string.Equals(Path.GetFileName(chosen), Facts.Name, StringComparison.OrdinalIgnoreCase);
                options.Dir = already ? chosen : Path.Combine(chosen, Facts.Name);
                ShowStage(Stage.Install, "");
            }
        }

        void Other()
        {
            if (stage == Stage.Removed)
            {
                Process.Start("explorer.exe", "\"" + path + "\"");
                return;
            }
            Close();
        }
    }

    public sealed class PillButton : Button
    {
        public Color Fill = Color.FromArgb(140, 250, 215);
        public Color Hover = Color.FromArgb(170, 252, 226);
        public Color Ink = Color.FromArgb(28, 29, 35);
        public int Radius = 8;
        bool over, down;

        public PillButton()
        {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
            FlatStyle = FlatStyle.Flat;
            FlatAppearance.BorderSize = 0;
            Cursor = Cursors.Hand;
        }

        public static GraphicsPath Round(Rectangle box, int radius)
        {
            GraphicsPath shape = new GraphicsPath();
            int d = Math.Max(1, radius * 2);
            shape.AddArc(box.Left, box.Top, d, d, 180, 90);
            shape.AddArc(box.Right - d - 1, box.Top, d, d, 270, 90);
            shape.AddArc(box.Right - d - 1, box.Bottom - d - 1, d, d, 0, 90);
            shape.AddArc(box.Left, box.Bottom - d - 1, d, d, 90, 90);
            shape.CloseFigure();
            return shape;
        }

        protected override void OnMouseEnter(EventArgs e) { over = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { over = false; down = false; Invalidate(); base.OnMouseLeave(e); }
        protected override void OnMouseDown(MouseEventArgs e) { down = true; Invalidate(); base.OnMouseDown(e); }
        protected override void OnMouseUp(MouseEventArgs e) { down = false; Invalidate(); base.OnMouseUp(e); }
        protected override void OnEnabledChanged(EventArgs e) { Invalidate(); base.OnEnabledChanged(e); }
        protected override void OnTextChanged(EventArgs e) { Invalidate(); base.OnTextChanged(e); }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.Clear(SetupForm.Card);
            g.SmoothingMode = SmoothingMode.AntiAlias;
            Rectangle box = new Rectangle(2, 2, Width - 4, Height - 4);
            if (down) box.Inflate(-1, -1);
            Color fill = !Enabled ? SetupForm.Well : over ? Hover : Fill;
            Color ink = !Enabled ? SetupForm.Muted : Ink;
            using (GraphicsPath shape = Round(box, Radius))
            using (SolidBrush brush = new SolidBrush(fill))
            {
                g.FillPath(brush, shape);
            }
            if (Focused && ShowFocusCues)
            {
                using (GraphicsPath ring = Round(new Rectangle(0, 0, Width - 1, Height - 1), Radius + 2))
                using (Pen pen = new Pen(SetupForm.Soft, 1))
                {
                    g.DrawPath(pen, ring);
                }
            }
            TextRenderer.DrawText(g, Text, Font, box, ink, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPrefix | TextFormatFlags.SingleLine);
        }
    }

    public sealed class TickBox : CheckBox
    {
        public int Box = 18;
        public int Gap = 10;
        bool over;

        public TickBox()
        {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
            Cursor = Cursors.Hand;
        }

        protected override void OnMouseEnter(EventArgs e) { over = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { over = false; Invalidate(); base.OnMouseLeave(e); }
        protected override void OnCheckedChanged(EventArgs e) { Invalidate(); base.OnCheckedChanged(e); }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.Clear(SetupForm.Card);
            g.SmoothingMode = SmoothingMode.AntiAlias;
            Rectangle square = new Rectangle(1, (Height - Box) / 2, Box, Box);
            using (GraphicsPath shape = PillButton.Round(square, Math.Max(2, Box / 5)))
            {
                using (SolidBrush fill = new SolidBrush(over ? SetupForm.WellHover : SetupForm.Well)) g.FillPath(fill, shape);
                if (Focused && ShowFocusCues)
                {
                    using (Pen ring = new Pen(SetupForm.Soft, 1)) g.DrawPath(ring, shape);
                }
            }
            if (Checked)
            {
                float u = Box / 18f;
                using (Pen tick = new Pen(SetupForm.Mint, 2.2f * u))
                {
                    tick.StartCap = LineCap.Round;
                    tick.EndCap = LineCap.Round;
                    tick.LineJoin = LineJoin.Round;
                    g.DrawLines(tick, new PointF[] {
                        new PointF(square.Left + 4.5f * u, square.Top + 9.5f * u),
                        new PointF(square.Left + 7.8f * u, square.Top + 12.6f * u),
                        new PointF(square.Left + 13.5f * u, square.Top + 5.8f * u)
                    });
                }
            }
            Rectangle text = new Rectangle(square.Right + Gap, 0, Width - square.Right - Gap, Height);
            TextRenderer.DrawText(g, Text, Font, text, SetupForm.Soft, TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPrefix | TextFormatFlags.NoPadding | TextFormatFlags.SingleLine);
        }
    }
}
