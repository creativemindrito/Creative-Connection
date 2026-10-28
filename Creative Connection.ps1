# One row per script.
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

if (-not ('LogView' -as [type])) {
  Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

public static class Glyph
{
    public static GraphicsPath Rounded(RectangleF r, float radius)
    {
        float d = radius * 2;
        GraphicsPath p = new GraphicsPath();
        p.AddArc(r.X, r.Y, d, d, 180, 90);
        p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }

    public static Bitmap Tint(Image source, Color color, int size)
    {
        float ratio = Math.Min((float)size / source.Width, (float)size / source.Height);
        int w = Math.Max(1, (int)Math.Round(source.Width * ratio));
        int h = Math.Max(1, (int)Math.Round(source.Height * ratio));
        Bitmap result = new Bitmap(w, h, PixelFormat.Format32bppPArgb);
        using (Graphics g = Graphics.FromImage(result))
        using (ImageAttributes a = new ImageAttributes())
        {
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            a.SetWrapMode(WrapMode.TileFlipXY);
            a.SetColorMatrix(new ColorMatrix(new float[][] {
                new float[] { 0, 0, 0, 0, 0 },
                new float[] { 0, 0, 0, 0, 0 },
                new float[] { 0, 0, 0, 0, 0 },
                new float[] { 0, 0, 0, 1, 0 },
                new float[] { color.R / 255f, color.G / 255f, color.B / 255f, 0, 1 }
            }));
            g.DrawImage(source, new Rectangle(0, 0, w, h), 0, 0, source.Width, source.Height, GraphicsUnit.Pixel, a);
        }
        return result;
    }
}

public static class Motion
{
    [DllImport("user32.dll")]
    static extern bool SystemParametersInfo(int action, int param, ref bool value, int ini);

    public static bool Enabled
    {
        get { bool on = true; SystemParametersInfo(0x1042, 0, ref on, 0); return on; }
    }
}

public class PowerButton : Control
{
    public Color Well = Color.FromArgb(43, 47, 53);
    public Color WellHover = Color.FromArgb(52, 56, 64);
    public Color WellDown = Color.FromArgb(60, 65, 74);
    public Color Accent = Color.FromArgb(140, 250, 215);
    Bitmap glyph, glyphLit;
    bool busy, hover, down, motion;
    float angle;
    Timer spin = new Timer();

    public PowerButton()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.Selectable, true);
        SetStyle(ControlStyles.StandardClick | ControlStyles.StandardDoubleClick, false);
        TabStop = true;
        motion = Motion.Enabled;
        spin.Interval = 16;
        spin.Tick += delegate { angle = (angle + 6f) % 360f; Invalidate(); };
    }

    public void SetGlyph(Image source, Color idle, int size)
    {
        if (glyph != null) glyph.Dispose();
        if (glyphLit != null) glyphLit.Dispose();
        glyph = Glyph.Tint(source, idle, size);
        glyphLit = Glyph.Tint(source, Accent, size);
        Invalidate();
    }

    public bool Busy
    {
        get { return busy; }
        set
        {
            busy = value;
            if (busy && motion) spin.Start(); else spin.Stop();
            Invalidate();
        }
    }

    public void Press()
    {
        if (!busy) OnClick(EventArgs.Empty);
    }

    bool Inside(Point p)
    {
        float r = Width / 2f, dx = p.X - r, dy = p.Y - Height / 2f;
        return dx * dx + dy * dy <= r * r;
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        bool h = Inside(e.Location);
        if (h != hover) { hover = h; Invalidate(); }
        Cursor = h && !busy ? Cursors.Hand : Cursors.Default;
        base.OnMouseMove(e);
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        hover = false; down = false; Invalidate();
        base.OnMouseLeave(e);
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        if (e.Button == MouseButtons.Left && Inside(e.Location)) { down = true; Focus(); Invalidate(); }
        base.OnMouseDown(e);
    }

    protected override void OnMouseUp(MouseEventArgs e)
    {
        bool was = down;
        down = false; Invalidate();
        if (was && Inside(e.Location)) Press();
        base.OnMouseUp(e);
    }

    protected override bool IsInputKey(Keys k)
    {
        return k == Keys.Enter || k == Keys.Space || base.IsInputKey(k);
    }

    protected override void OnKeyUp(KeyEventArgs e)
    {
        if (e.KeyCode == Keys.Enter || e.KeyCode == Keys.Space) Press();
        base.OnKeyUp(e);
    }

    protected override void OnGotFocus(EventArgs e) { Invalidate(); base.OnGotFocus(e); }
    protected override void OnLostFocus(EventArgs e) { Invalidate(); base.OnLostFocus(e); }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        g.Clear(Parent != null ? Parent.BackColor : BackColor);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        float stroke = Math.Max(2f, Width / 22f);
        float edge = stroke * 2f;
        RectangleF disc = new RectangleF(edge, edge, Width - 2 * edge, Height - 2 * edge);
        RectangleF ring = new RectangleF(stroke / 2f + 0.5f, stroke / 2f + 0.5f, Width - stroke - 1f, Height - stroke - 1f);
        Color fill = busy ? Well : down ? WellDown : hover ? WellHover : Well;
        using (SolidBrush b = new SolidBrush(fill)) g.FillEllipse(b, disc);
        if (busy || (Focused && ShowFocusCues))
        {
            using (Pen p = new Pen(Accent, stroke))
            {
                p.StartCap = LineCap.Round;
                p.EndCap = LineCap.Round;
                if (busy && motion) g.DrawArc(p, ring, angle - 90f, 110f);
                else g.DrawEllipse(p, ring);
            }
        }
        Bitmap gl = busy || hover ? glyphLit : glyph;
        if (gl != null) g.DrawImage(gl, (Width - gl.Width) / 2, (Height - gl.Height) / 2, gl.Width, gl.Height);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            spin.Dispose();
            if (glyph != null) glyph.Dispose();
            if (glyphLit != null) glyphLit.Dispose();
        }
        base.Dispose(disposing);
    }
}

public class IconButton : Control
{
    public Color Idle = Color.FromArgb(151, 154, 160);
    public Color Lit = Color.White;
    public Color HoverFill = Color.FromArgb(43, 47, 53);
    Bitmap glyph, glyphLit;
    bool hover, down;

    public IconButton()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.Selectable, true);
        SetStyle(ControlStyles.StandardClick | ControlStyles.StandardDoubleClick, false);
        TabStop = true;
        Cursor = Cursors.Hand;
    }

    public void SetGlyph(Image source, int size)
    {
        if (glyph != null) glyph.Dispose();
        if (glyphLit != null) glyphLit.Dispose();
        glyph = Glyph.Tint(source, Idle, size);
        glyphLit = Glyph.Tint(source, Lit, size);
        Invalidate();
    }

    public void Press()
    {
        OnClick(EventArgs.Empty);
    }

    protected override void OnMouseEnter(EventArgs e) { hover = true; Invalidate(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { hover = false; down = false; Invalidate(); base.OnMouseLeave(e); }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        if (e.Button == MouseButtons.Left) { down = true; Invalidate(); }
        base.OnMouseDown(e);
    }

    protected override void OnMouseUp(MouseEventArgs e)
    {
        bool was = down;
        down = false; Invalidate();
        if (was && ClientRectangle.Contains(e.Location)) Press();
        base.OnMouseUp(e);
    }

    protected override bool IsInputKey(Keys k)
    {
        return k == Keys.Enter || k == Keys.Space || base.IsInputKey(k);
    }

    protected override void OnKeyUp(KeyEventArgs e)
    {
        if (e.KeyCode == Keys.Enter || e.KeyCode == Keys.Space) Press();
        base.OnKeyUp(e);
    }

    protected override void OnGotFocus(EventArgs e) { Invalidate(); base.OnGotFocus(e); }
    protected override void OnLostFocus(EventArgs e) { Invalidate(); base.OnLostFocus(e); }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        g.Clear(Parent != null ? Parent.BackColor : BackColor);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        bool lit = hover || down || (Focused && ShowFocusCues);
        if (lit)
        {
            using (SolidBrush b = new SolidBrush(HoverFill)) g.FillEllipse(b, 0, 0, Width - 1, Height - 1);
        }
        Bitmap gl = lit ? glyphLit : glyph;
        if (gl != null) g.DrawImage(gl, (Width - gl.Width) / 2, (Height - gl.Height) / 2, gl.Width, gl.Height);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            if (glyph != null) glyph.Dispose();
            if (glyphLit != null) glyphLit.Dispose();
        }
        base.Dispose(disposing);
    }
}

public class DeviceRow : Control
{
    const TextFormatFlags Flags = TextFormatFlags.Left | TextFormatFlags.NoPadding | TextFormatFlags.SingleLine | TextFormatFlags.NoPrefix;
    public Color Well = Color.FromArgb(43, 47, 53);
    public Color Ink = Color.White;
    public Font NameFont;
    public Font StatusFont;
    public float MinNameSize = 9f;
    public int WellSize = 44;
    public int Gap = 14;
    public int EditGap = 4;
    public int MaxNameLength = 24;
    public string DefaultName = "";
    public Font HouseFont;
    public Color HouseBack = Color.FromArgb(43, 47, 53);
    public Color HouseInk = Color.FromArgb(201, 204, 209);
    public Color AlertBack = Color.FromArgb(74, 38, 40);
    public Color AlertInk = Color.FromArgb(255, 155, 145);
    public int HouseGap = 8;
    public int HouseColumn = 0;
    public readonly PowerButton Button = new PowerButton();
    public readonly IconButton Edit = new IconButton();
    public event EventHandler NameCommitted;
    TextBox editor;
    bool editing;
    Bitmap icon;
    Font fitted;
    Rectangle nameArea, statusArea, houseArea;
    int wellLeft;
    string status = "";
    string house = "";
    bool alert;
    Color statusColor = Color.Gray;

    public DeviceRow()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        Controls.Add(Button);
        Controls.Add(Edit);
        Edit.Click += delegate { BeginEdit(); };
    }

    public string Status { get { return status; } }
    public TextBox Editor { get { return editor; } }
    public bool Editing { get { return editing; } }
    public float NameSize { get { return fitted != null ? fitted.Size : 0f; } }

    public string HouseNumber
    {
        get { return house; }
        set { house = value ?? ""; Arrange(); }
    }

    public bool HouseAlert
    {
        get { return alert; }
        set { alert = value; Invalidate(); }
    }

    public int WellLeft { get { return wellLeft; } }
    public int NameLeft { get { return wellLeft + WellSize + Gap; } }

    public void SetIcon(Image source, Color color, int size)
    {
        if (icon != null) icon.Dispose();
        icon = Glyph.Tint(source, color, size);
        Invalidate();
    }

    public void SetStatus(string text, Color color)
    {
        status = text;
        statusColor = color;
        AccessibleDescription = text;
        Button.AccessibleDescription = text;
        Invalidate();
    }

    public void Arrange()
    {
        Button.Location = new Point(Width - Button.Width, (Height - Button.Height) / 2);
        houseArea = Rectangle.Empty;
        wellLeft = HouseColumn > 0 ? HouseColumn + HouseGap : 0;
        if (house.Length > 0 && HouseFont != null && HouseColumn > 0)
        {
            Size wide = TextRenderer.MeasureText("000", HouseFont, Size.Empty, Flags);
            int h = wide.Height + Math.Max(6, wide.Height / 2);
            houseArea = new Rectangle(0, (Height - h) / 2, HouseColumn, h);
        }
        if (NameFont == null || StatusFont == null) return;
        int x = wellLeft + WellSize + Gap;
        int room = Math.Max(0, Button.Left - Gap - x - EditGap - Edit.Width);
        if (fitted != null && fitted != NameFont) fitted.Dispose();
        fitted = NameFont;
        while (fitted.Size > MinNameSize && TextRenderer.MeasureText(Text, fitted, Size.Empty, Flags).Width > room)
        {
            Font smaller = new Font(fitted.FontFamily, Math.Max(MinNameSize, fitted.Size - 0.5f), fitted.Style);
            if (fitted != NameFont) fitted.Dispose();
            fitted = smaller;
        }
        int nameWidth = Math.Min(TextRenderer.MeasureText(Text, fitted, Size.Empty, Flags).Width, room);
        int nameHeight = TextRenderer.MeasureText("Xg", NameFont, Size.Empty, Flags).Height;
        int lineHeight = TextRenderer.MeasureText("Xg", StatusFont, Size.Empty, Flags).Height;
        int space = Math.Max(2, lineHeight / 5);
        int y = (Height - nameHeight - space - lineHeight) / 2;
        nameArea = new Rectangle(x, y, nameWidth, nameHeight);
        statusArea = new Rectangle(x, y + nameHeight + space, Math.Max(0, Button.Left - Gap - x), lineHeight);
        Edit.Location = new Point(x + nameWidth + EditGap, y + (nameHeight - Edit.Height) / 2);
        if (editing) PlaceEditor();
        Invalidate();
    }

    void PlaceEditor()
    {
        int x = wellLeft + WellSize + Gap;
        int w = Math.Max(40, Button.Left - Gap - x);
        int h = editor.PreferredHeight;
        editor.Bounds = new Rectangle(x, nameArea.Y + (nameArea.Height - h) / 2, w, h);
    }

    public void BeginEdit()
    {
        if (editing) return;
        if (editor == null)
        {
            editor = new TextBox();
            editor.BorderStyle = BorderStyle.None;
            editor.Visible = false;
            editor.KeyDown += delegate(object s, KeyEventArgs e)
            {
                if (e.KeyCode == Keys.Enter) { e.SuppressKeyPress = true; EndEdit(true); }
                else if (e.KeyCode == Keys.Escape) { e.SuppressKeyPress = true; EndEdit(false); }
            };
            editor.LostFocus += delegate { EndEdit(true); };
            Controls.Add(editor);
        }
        editor.Font = NameFont;
        editor.BackColor = Well;
        editor.ForeColor = Ink;
        editor.MaxLength = MaxNameLength;
        editor.Text = Text;
        editing = true;
        PlaceEditor();
        Edit.Visible = false;
        editor.Visible = true;
        editor.Focus();
        editor.SelectAll();
        Invalidate();
    }

    public void EndEdit(bool keep)
    {
        if (!editing) return;
        editing = false;
        string value = editor.Text.Replace('\t', ' ').Trim();
        if (value.Length > MaxNameLength)
        {
            value = value.Substring(0, MaxNameLength);
            if (char.IsHighSurrogate(value[value.Length - 1])) value = value.Substring(0, value.Length - 1);
            value = value.Trim();
        }
        editor.Visible = false;
        Edit.Visible = true;
        if (keep)
        {
            if (value.Length == 0) value = DefaultName;
            if (value != Text)
            {
                Text = value;
                if (NameCommitted != null) NameCommitted(this, EventArgs.Empty);
            }
        }
        Arrange();
    }

    protected override void OnResize(EventArgs e) { base.OnResize(e); Arrange(); }
    protected override void OnTextChanged(EventArgs e) { base.OnTextChanged(e); Arrange(); }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        g.Clear(BackColor);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        if (!houseArea.IsEmpty)
        {
            using (GraphicsPath p = Glyph.Rounded(new RectangleF(houseArea.X, houseArea.Y, houseArea.Width - 1, houseArea.Height - 1), Math.Max(3, houseArea.Height / 4)))
            using (SolidBrush b = new SolidBrush(alert ? AlertBack : HouseBack)) g.FillPath(b, p);
            TextRenderer.DrawText(g, house, HouseFont, houseArea, alert ? AlertInk : HouseInk, Flags | TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
        }
        int top = (Height - WellSize) / 2;
        using (SolidBrush b = new SolidBrush(Well)) g.FillEllipse(b, wellLeft, top, WellSize, WellSize);
        if (icon != null) g.DrawImage(icon, wellLeft + (WellSize - icon.Width) / 2, top + (WellSize - icon.Height) / 2, icon.Width, icon.Height);
        if (fitted == null) return;
        if (!editing) TextRenderer.DrawText(g, Text, fitted, nameArea, Ink, BackColor, Flags | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
        TextRenderer.DrawText(g, status, StatusFont, statusArea, statusColor, BackColor, Flags | TextFormatFlags.EndEllipsis);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            if (icon != null) icon.Dispose();
            if (fitted != null && fitted != NameFont) fitted.Dispose();
        }
        base.Dispose(disposing);
    }
}

public class HelpTile : Control
{
    const TextFormatFlags Wrap = TextFormatFlags.Left | TextFormatFlags.NoPadding | TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix | TextFormatFlags.EndEllipsis;
    public Color Ink = Color.White;
    public Color Fill = Color.FromArgb(35, 37, 43);
    public Color HoverFill = Color.FromArgb(43, 47, 53);
    public Color DownFill = Color.FromArgb(52, 56, 63);
    public Color Ring = Color.FromArgb(151, 154, 160);
    public int Radius = 10;
    public int Inset = 10;
    public int MaxLines = 2;
    bool hover, down;

    public HelpTile()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.Selectable, true);
        SetStyle(ControlStyles.StandardClick | ControlStyles.StandardDoubleClick, false);
        TabStop = true;
        Cursor = Cursors.Hand;
        AccessibleRole = AccessibleRole.PushButton;
    }

    public int TextLines
    {
        get
        {
            if (Font == null || Width <= 2 * Inset) return 0;
            Size none = new Size(int.MaxValue, int.MaxValue);
            using (Graphics g = Graphics.FromHwnd(IntPtr.Zero))
            {
                int line = TextRenderer.MeasureText(g, "Xg", Font, none, Wrap).Height;
                int all = TextRenderer.MeasureText(g, Text, Font, new Size(Width - 2 * Inset, int.MaxValue), Wrap).Height;
                return (int)Math.Ceiling(all / (double)line);
            }
        }
    }

    public void Press()
    {
        OnClick(EventArgs.Empty);
    }

    protected override void OnMouseEnter(EventArgs e) { hover = true; Invalidate(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { hover = false; down = false; Invalidate(); base.OnMouseLeave(e); }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        if (e.Button == MouseButtons.Left) { down = true; Invalidate(); }
        base.OnMouseDown(e);
    }

    protected override void OnMouseUp(MouseEventArgs e)
    {
        bool was = down;
        down = false; Invalidate();
        if (was && ClientRectangle.Contains(e.Location)) Press();
        base.OnMouseUp(e);
    }

    protected override bool IsInputKey(Keys k)
    {
        return k == Keys.Enter || k == Keys.Space || base.IsInputKey(k);
    }

    protected override void OnKeyUp(KeyEventArgs e)
    {
        if (e.KeyCode == Keys.Enter || e.KeyCode == Keys.Space) Press();
        base.OnKeyUp(e);
    }

    protected override void OnGotFocus(EventArgs e) { Invalidate(); base.OnGotFocus(e); }
    protected override void OnLostFocus(EventArgs e) { Invalidate(); base.OnLostFocus(e); }
    protected override void OnTextChanged(EventArgs e) { Invalidate(); base.OnTextChanged(e); }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        g.Clear(Parent != null ? Parent.BackColor : BackColor);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        bool keys = Focused && ShowFocusCues;
        Color fill = down ? DownFill : ((hover || keys) ? HoverFill : Fill);
        using (GraphicsPath p = Glyph.Rounded(new RectangleF(0, 0, Width - 1, Height - 1), Radius))
        {
            using (SolidBrush b = new SolidBrush(fill)) g.FillPath(b, p);
            if (keys) using (Pen ring = new Pen(Ring, 1)) g.DrawPath(ring, p);
        }
        if (Font == null) return;
        int room = Math.Max(0, Width - 2 * Inset);
        int line = TextRenderer.MeasureText(g, "Xg", Font, new Size(int.MaxValue, int.MaxValue), Wrap).Height;
        int wanted = TextRenderer.MeasureText(g, Text, Font, new Size(room, int.MaxValue), Wrap).Height;
        int shown = Math.Min(wanted, line * MaxLines);
        TextRenderer.DrawText(g, Text, Font, new Rectangle(Inset, (Height - shown) / 2, room, shown), Ink, fill, Wrap);
    }
}
public class HelpText : Control
{
    const TextFormatFlags Wrap = TextFormatFlags.Left | TextFormatFlags.NoPadding | TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix | TextFormatFlags.TextBoxControl;
    public Color Ink = Color.FromArgb(201, 204, 209);
    public Color Muted = Color.FromArgb(151, 154, 160);
    public int ParagraphGap = 8;
    public string EmptyText = "";
    readonly List<string> paragraphs = new List<string>();

    public HelpText()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
    }

    public string AllText { get { return string.Join("\n", paragraphs.ToArray()); } }
    readonly Dictionary<string, Image> images = new Dictionary<string, Image>();

    Image Picture(string item)
    {
        int open = item.IndexOf("](");
        if (!item.StartsWith("![") || open < 0 || !item.EndsWith(")")) return null;
        string path = item.Substring(open + 2, item.Length - open - 3);
        Image found;
        if (!images.TryGetValue(path, out found))
        {
            try { found = Image.FromFile(path); } catch { found = null; }
            images[path] = found;
        }
        return found;
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing) foreach (Image i in images.Values) if (i != null) i.Dispose();
        base.Dispose(disposing);
    }

    public void SetText(string[] items)
    {
        paragraphs.Clear();
        paragraphs.AddRange(items);
        Invalidate();
    }

    public int MeasureHeight(int width)
    {
        using (Graphics g = Graphics.FromHwnd(IntPtr.Zero)) return Flow(g, width, false);
    }

    int Flow(Graphics g, int width, bool paint)
    {
        if (Font == null) return 0;
        if (paragraphs.Count == 0 && !string.IsNullOrEmpty(EmptyText))
        {
            int ew = Math.Max(10, width - 2);
            Size es = TextRenderer.MeasureText(g, EmptyText, Font, new Size(ew, int.MaxValue), Wrap);
            if (paint) TextRenderer.DrawText(g, EmptyText, Font, new Rectangle(0, 0, ew, es.Height), Muted, BackColor, Wrap);
            return es.Height + Font.Height / 2;
        }
        int indent = TextRenderer.MeasureText("8.", Font, Size.Empty, Wrap).Width + Font.Height / 2;
        int y = 0;
        foreach (string item in paragraphs)
        {
            if (item.StartsWith("!["))
            {
                Image picture = Picture(item);
                if (picture != null)
                {
                    int pw = Math.Max(10, width - 2);
                    int ph = (int)Math.Round(pw * (double)picture.Height / picture.Width);
                    if (paint)
                    {
                        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                        g.DrawImage(picture, new Rectangle(0, y, pw, ph));
                        g.PixelOffsetMode = PixelOffsetMode.None;
                        g.SmoothingMode = SmoothingMode.None;
                        using (Pen p = new Pen(Muted, 1)) g.DrawRectangle(p, 0, y, pw - 1, ph - 1);
                    }
                    y += ph + ParagraphGap;
                }
                continue;
            }
            string number = null;
            string text = item;
            int left = 0;
            Color color = Ink;
            int dot = item.IndexOf(". ");
            if (dot > 0 && dot <= 2 && char.IsDigit(item[0]))
            {
                number = item.Substring(0, dot + 1);
                text = item.Substring(dot + 2);
                left = indent;
            }
            else if (item.StartsWith("Tip: "))
            {
                left = indent;
                color = Muted;
            }
            int w = Math.Max(10, width - left - 2);
            Size s = TextRenderer.MeasureText(g, text, Font, new Size(w, int.MaxValue), Wrap);
            if (paint)
            {
                if (number != null) TextRenderer.DrawText(g, number, Font, new Rectangle(0, y, indent, s.Height), Muted, BackColor, Wrap);
                TextRenderer.DrawText(g, text, Font, new Rectangle(left, y, w, s.Height), color, BackColor, Wrap);
            }
            y += s.Height + ParagraphGap;
        }
        return Math.Max(0, y - ParagraphGap) + Font.Height / 2;
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        e.Graphics.Clear(BackColor);
        Flow(e.Graphics, Width, true);
    }
}

public class AddRow : Control
{
    const TextFormatFlags Flags = TextFormatFlags.Left | TextFormatFlags.NoPadding | TextFormatFlags.SingleLine | TextFormatFlags.NoPrefix | TextFormatFlags.VerticalCenter;
    public Color Ink = Color.White;
    public Color Idle = Color.FromArgb(151, 154, 160);
    public Color Border = Color.FromArgb(74, 78, 87);
    public Color HoverFill = Color.FromArgb(35, 37, 43);
    public int Radius = 10;
    public int GlyphLeft = 16;
    public int TextGap = 12;
    Bitmap glyph, glyphLit;
    bool hover, down;

    public AddRow()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.Selectable, true);
        SetStyle(ControlStyles.StandardClick | ControlStyles.StandardDoubleClick, false);
        TabStop = true;
        Cursor = Cursors.Hand;
        AccessibleRole = AccessibleRole.PushButton;
    }

    public void SetGlyph(Image source, int size)
    {
        glyph = Glyph.Tint(source, Idle, size);
        glyphLit = Glyph.Tint(source, Ink, size);
        Invalidate();
    }

    public void Press()
    {
        OnClick(EventArgs.Empty);
    }

    protected override void OnMouseEnter(EventArgs e) { hover = true; Invalidate(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { hover = false; down = false; Invalidate(); base.OnMouseLeave(e); }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        if (e.Button == MouseButtons.Left) { down = true; Invalidate(); }
        base.OnMouseDown(e);
    }

    protected override void OnMouseUp(MouseEventArgs e)
    {
        bool was = down;
        down = false; Invalidate();
        if (was && ClientRectangle.Contains(e.Location)) Press();
        base.OnMouseUp(e);
    }

    protected override bool IsInputKey(Keys k)
    {
        return k == Keys.Enter || k == Keys.Space || base.IsInputKey(k);
    }

    protected override void OnKeyUp(KeyEventArgs e)
    {
        if (e.KeyCode == Keys.Enter || e.KeyCode == Keys.Space) Press();
        base.OnKeyUp(e);
    }

    protected override void OnGotFocus(EventArgs e) { Invalidate(); base.OnGotFocus(e); }
    protected override void OnLostFocus(EventArgs e) { Invalidate(); base.OnLostFocus(e); }
    protected override void OnTextChanged(EventArgs e) { Invalidate(); base.OnTextChanged(e); }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        Color back = Parent != null ? Parent.BackColor : BackColor;
        g.Clear(back);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        bool lit = hover || down || (Focused && ShowFocusCues);
        RectangleF box = new RectangleF(1, 1, Width - 3, Height - 3);
        using (GraphicsPath p = Glyph.Rounded(box, Radius))
        {
            if (lit)
            {
                back = HoverFill;
                using (SolidBrush b = new SolidBrush(HoverFill)) g.FillPath(b, p);
            }
            using (Pen pen = new Pen(lit ? Idle : Border, 1.5f))
            {
                pen.DashPattern = new float[] { 4f, 3f };
                g.DrawPath(pen, p);
            }
        }
        Bitmap gl = lit ? glyphLit : glyph;
        int x = GlyphLeft;
        if (gl != null)
        {
            g.DrawImage(gl, x, (Height - gl.Height) / 2, gl.Width, gl.Height);
            x += gl.Width + TextGap;
        }
        TextRenderer.DrawText(g, Text, Font, new Rectangle(x, 0, Math.Max(0, Width - x - GlyphLeft), Height), Ink, back, Flags);
    }
}

public class ChipButton : Control
{
    const TextFormatFlags Flags = TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding | TextFormatFlags.SingleLine | TextFormatFlags.NoPrefix;

    public Color Ink = Color.White;
    public Color Idle = Color.FromArgb(151, 154, 160);
    public Color Fill = Color.FromArgb(43, 47, 53);
    public Color HoverFill = Color.FromArgb(35, 37, 43);
    public Color Alert = Color.FromArgb(255, 155, 145);
    public bool AlertWhenCounted;
    string label = "";
    int count;
    bool active, hover, down;

    public ChipButton()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.Selectable, true);
        SetStyle(ControlStyles.StandardClick | ControlStyles.StandardDoubleClick, false);
        TabStop = true;
        Cursor = Cursors.Hand;
    }

    public string Label
    {
        get { return label; }
        set { label = value ?? ""; Invalidate(); }
    }

    public int Count
    {
        get { return count; }
        set { count = value; Invalidate(); }
    }

    public bool Active
    {
        get { return active; }
        set { active = value; Invalidate(); }
    }

    public int FitWidth(int padding, int gap)
    {
        Size a = TextRenderer.MeasureText(label, Font, Size.Empty, Flags);
        Size b = TextRenderer.MeasureText(count.ToString(), Font, Size.Empty, Flags);
        return padding * 2 + a.Width + gap + b.Width;
    }

    public void Press()
    {
        OnClick(EventArgs.Empty);
    }

    protected override void OnMouseEnter(EventArgs e) { hover = true; Invalidate(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { hover = false; down = false; Invalidate(); base.OnMouseLeave(e); }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        if (e.Button == MouseButtons.Left) { down = true; Invalidate(); }
        base.OnMouseDown(e);
    }

    protected override void OnMouseUp(MouseEventArgs e)
    {
        bool was = down;
        down = false; Invalidate();
        if (was && ClientRectangle.Contains(e.Location)) Press();
        base.OnMouseUp(e);
    }

    protected override bool IsInputKey(Keys k)
    {
        return k == Keys.Enter || k == Keys.Space || base.IsInputKey(k);
    }

    protected override void OnKeyUp(KeyEventArgs e)
    {
        if (e.KeyCode == Keys.Enter || e.KeyCode == Keys.Space) Press();
        base.OnKeyUp(e);
    }

    protected override void OnGotFocus(EventArgs e) { Invalidate(); base.OnGotFocus(e); }
    protected override void OnLostFocus(EventArgs e) { Invalidate(); base.OnLostFocus(e); }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        g.Clear(Parent != null ? Parent.BackColor : BackColor);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        bool lit = hover || down || (Focused && ShowFocusCues);
        RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);
        using (GraphicsPath p = Glyph.Rounded(r, r.Height / 2f))
        {
            if (active || lit)
            {
                using (SolidBrush b = new SolidBrush(active ? Fill : HoverFill)) g.FillPath(b, p);
            }
            using (Pen pen = new Pen(Fill, 1f)) g.DrawPath(pen, p);
        }
        string number = count.ToString();
        Size a = TextRenderer.MeasureText(label, Font, Size.Empty, Flags);
        Size n = TextRenderer.MeasureText(number, Font, Size.Empty, Flags);
        int gap = Math.Max(4, Height / 5);
        int x = (Width - (a.Width + gap + n.Width)) / 2;
        Color text = active || lit ? Ink : Idle;
        Color tone = AlertWhenCounted && count > 0 ? Alert : text;
        TextRenderer.DrawText(g, label, Font, new Rectangle(x, 0, a.Width + 2, Height), text, Flags);
        TextRenderer.DrawText(g, number, Font, new Rectangle(x + a.Width + gap, 0, n.Width + 2, Height), tone, Flags);
    }
}

public static class LogFiles
{
    public static int KindOf(string line)
    {
        int a = line.IndexOf('\t');
        if (a < 0) return -1;
        int b = line.IndexOf('\t', a + 1);
        if (b < 0) return -1;
        if (line.IndexOf('\t', b + 1) < 0) return -1;
        int length = b - a - 1;
        if (Is(line, a + 1, length, "sent") || Is(line, a + 1, length, "ran") || Is(line, a + 1, length, "already-on")) return 0;
        if (Is(line, a + 1, length, "test")) return 2;
        return 1;
    }

    static bool Is(string s, int start, int length, string word)
    {
        return length == word.Length && string.CompareOrdinal(s, start, word, 0, length) == 0;
    }

    public static int[] Count(string path)
    {
        int[] n = new int[4];
        try
        {
            using (FileStream f = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
            using (StreamReader r = new StreamReader(f, new UTF8Encoding(false)))
            {
                string line;
                while ((line = r.ReadLine()) != null)
                {
                    int k = KindOf(line);
                    if (k < 0) continue;
                    n[0]++;
                    if (k == 0) n[1]++;
                    else if (k == 1) n[2]++;
                    else n[3]++;
                }
            }
        }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
        return n;
    }

    public static string[] Tail(string[] files, int kind, int count)
    {
        List<string> found = new List<string>();
        if (count <= 0) return new string[0];
        foreach (string file in files)
        {
            if (found.Count >= count) break;
            ScanBackwards(file, delegate(string line)
            {
                int k = KindOf(line);
                if (k < 0) return true;
                if (kind == 1 && k != 0) return true;
                if (kind == 2 && k != 1) return true;
                found.Add(line);
                return found.Count < count;
            });
        }
        found.Reverse();
        return found.ToArray();
    }

    static string Decode(byte[] data, int start, int length)
    {
        if (length > 0 && data[start + length - 1] == 13) length--;
        string s = Encoding.UTF8.GetString(data, start, length);
        if (s.Length > 0 && s[0] == (char)0xFEFF) s = s.Substring(1);
        return s;
    }

    static void ScanBackwards(string path, Func<string, bool> accept)
    {
        FileStream f = null;
        try { f = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite); }
        catch (IOException) { return; }
        catch (UnauthorizedAccessException) { return; }
        using (f)
        {
            long end = f.Length;
            byte[] block = new byte[65536];
            byte[] tail = new byte[0];
            while (end > 0)
            {
                int size = (int)Math.Min(block.Length, end);
                end -= size;
                f.Position = end;
                int got = 0;
                while (got < size)
                {
                    int n = f.Read(block, got, size - got);
                    if (n <= 0) break;
                    got += n;
                }
                byte[] data = new byte[got + tail.Length];
                Buffer.BlockCopy(block, 0, data, 0, got);
                Buffer.BlockCopy(tail, 0, data, got, tail.Length);
                int lineEnd = data.Length;
                for (int i = data.Length - 1; i >= 0; i--)
                {
                    if (data[i] != 10) continue;
                    if (lineEnd > i + 1 && !accept(Decode(data, i + 1, lineEnd - i - 1))) return;
                    lineEnd = i;
                }
                tail = new byte[lineEnd];
                Buffer.BlockCopy(data, 0, tail, 0, lineEnd);
            }
            if (tail.Length > 0) accept(Decode(tail, 0, tail.Length));
        }
    }
}

public class CopyEventArgs : EventArgs
{
    public string Text;
    public CopyEventArgs(string text) { Text = text; }
}

public class LogView : ScrollableControl
{
    const TextFormatFlags Flags = TextFormatFlags.Left | TextFormatFlags.NoPadding | TextFormatFlags.SingleLine | TextFormatFlags.NoPrefix;

    struct Run
    {
        public string Text;
        public Color Tone;
        public Run(string text, Color tone) { Text = text; Tone = tone; }
    }

    class Entry
    {
        public string Dir, Script, Time, Name, Result, Tags, Copy;
        public int Kind, Top;
        public List<List<Run>> Lines = new List<List<Run>>();
        public int Columns = -1;
    }

    readonly List<Entry> entries = new List<Entry>();
    public Font LogFont;
    public Color Text1 = Color.FromArgb(201, 204, 209);
    public Color Muted = Color.FromArgb(151, 154, 160);
    public Color Ink = Color.White;
    public Color Good = Color.FromArgb(140, 250, 215);
    public Color Bad = Color.FromArgb(255, 155, 145);
    public Color Neutral = Color.FromArgb(201, 204, 209);
    public Color Rule = Color.FromArgb(43, 47, 53);
    public string EmptyText = "";
    public int Limit = 2000;
    int columns = 40, fullColumns = 44, lineHeight = 16, gapBefore = 7, gapAfter = 8;
    int iconSize = 14, iconGap = 6, slop = 3;
    double charWidth = 7;
    Bitmap copyIdle, copyLit, copyDone, copyFail;
    Entry hot, pressed, clicked, flashing;
    bool flashOk;
    Timer flashTimer = new Timer();

    public event EventHandler<CopyEventArgs> CopyRequested;

    public LogView()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        AutoScroll = true;
        flashTimer.Interval = 1600;
        flashTimer.Tick += delegate { flashTimer.Stop(); flashing = null; Invalidate(); };
    }

    public int Count { get { return entries.Count; } }
    public int Columns { get { return columns; } }
    public bool Flashing { get { return flashing != null; } }
    public bool FlashOk { get { return flashOk; } }

    int Reserve { get { return copyIdle == null ? 0 : (int)Math.Ceiling((iconSize + iconGap) / charWidth); } }
    int IconLeftPx { get { return (int)Math.Round(fullColumns * charWidth) - iconSize; } }
    public int IconLeft { get { Relayout(); return IconLeftPx; } }
    public int IconSize { get { return iconSize; } }
    public int TextRight { get { Relayout(); return (int)Math.Round(columns * charWidth); } }

    public void SetCopyGlyph(Image source, int size, Color idle, Color lit, Color done, Color fail)
    {
        DisposeGlyphs();
        iconSize = size;
        copyIdle = Glyph.Tint(source, idle, size);
        copyLit = Glyph.Tint(source, lit, size);
        copyDone = Glyph.Tint(source, done, size);
        copyFail = Glyph.Tint(source, fail, size);
        Relayout();
        Invalidate();
    }

    void DisposeGlyphs()
    {
        if (copyIdle != null) copyIdle.Dispose();
        if (copyLit != null) copyLit.Dispose();
        if (copyDone != null) copyDone.Dispose();
        if (copyFail != null) copyFail.Dispose();
        copyIdle = copyLit = copyDone = copyFail = null;
    }

    public void Add(string dir, string script, string time, string name, string result, string tags, int kind, string copy)
    {
        Entry e = new Entry();
        e.Dir = dir ?? ""; e.Script = script ?? ""; e.Time = time ?? ""; e.Name = name ?? "";
        e.Result = result ?? ""; e.Tags = tags ?? ""; e.Kind = kind; e.Copy = copy ?? "";
        entries.Add(e);
        if (entries.Count > Limit)
        {
            Entry gone = entries[0];
            if (hot == gone) hot = null;
            if (pressed == gone) pressed = null;
            if (clicked == gone) clicked = null;
            if (flashing == gone) flashing = null;
            entries.RemoveAt(0);
        }
    }

    public void ShowLatest()
    {
        Relayout();
        AutoScrollPosition = new Point(0, AutoScrollMinSize.Height);
        Invalidate();
    }

    public void ScrollToTop()
    {
        Relayout();
        AutoScrollPosition = new Point(0, 0);
        Invalidate();
    }

    public void Clear()
    {
        hot = pressed = clicked = flashing = null;
        entries.Clear();
    }

    public string CopyText()
    {
        StringBuilder text = new StringBuilder();
        foreach (Entry e in entries) text.Append(e.Copy).Append("\r\n");
        return text.ToString();
    }

    public string[] VisibleLines()
    {
        Relayout();
        List<string> result = new List<string>();
        bool first = true;
        foreach (Entry e in entries)
        {
            if (!first) result.Add("-----");
            first = false;
            foreach (List<Run> line in e.Lines)
            {
                StringBuilder row = new StringBuilder();
                foreach (Run r in line) row.Append(r.Text);
                result.Add(row.ToString());
            }
        }
        return result.ToArray();
    }

    public int LongestLine
    {
        get
        {
            Relayout();
            int most = 0;
            foreach (Entry e in entries)
            {
                foreach (List<Run> line in e.Lines)
                {
                    int length = 0;
                    foreach (Run r in line) length += r.Text.Length;
                    if (length > most) most = length;
                }
            }
            return most;
        }
    }

    public Point CopyIconCenter(int index)
    {
        Relayout();
        if (index < 0 || index >= entries.Count) return new Point(-1, -1);
        Entry e = entries[index];
        return new Point(IconLeftPx + iconSize / 2, AutoScrollPosition.Y + e.Top + lineHeight / 2);
    }

    public bool ClickCopyAt(Point p)
    {
        Relayout();
        Entry e = HitIcon(p);
        if (e == null) return false;
        Raise(e);
        return true;
    }

    public void MarkCopied(bool ok)
    {
        if (clicked == null) return;
        flashing = clicked;
        flashOk = ok;
        flashTimer.Stop();
        flashTimer.Start();
        Invalidate();
    }

    void Raise(Entry e)
    {
        clicked = e;
        if (CopyRequested != null) CopyRequested(this, new CopyEventArgs(e.Copy));
    }

    Entry HitIcon(Point p)
    {
        if (copyIdle == null) return null;
        int left = IconLeftPx;
        if (p.X < left - slop || p.X >= left + iconSize + slop) return null;
        int cy = p.Y - AutoScrollPosition.Y;
        foreach (Entry e in entries)
        {
            int top = e.Top + (lineHeight - iconSize) / 2;
            if (cy >= top - slop && cy < top + iconSize + slop) return e;
        }
        return null;
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        Entry over = HitIcon(e.Location);
        if (over != hot) { hot = over; Invalidate(); }
        Cursor = over != null ? Cursors.Hand : Cursors.Default;
        base.OnMouseMove(e);
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        if (hot != null) { hot = null; Invalidate(); }
        pressed = null;
        Cursor = Cursors.Default;
        base.OnMouseLeave(e);
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        if (e.Button == MouseButtons.Left) pressed = HitIcon(e.Location);
        base.OnMouseDown(e);
    }

    protected override void OnMouseUp(MouseEventArgs e)
    {
        Entry hit = e.Button == MouseButtons.Left ? HitIcon(e.Location) : null;
        if (hit != null && hit == pressed) Raise(hit);
        pressed = null;
        base.OnMouseUp(e);
    }

    static List<Run> One(string text, Color tone)
    {
        List<Run> line = new List<Run>();
        line.Add(new Run(text, tone));
        return line;
    }

    static List<string> Break(string text, int cols, char separator)
    {
        List<string> parts = new List<string>();
        string rest = text ?? "";
        while (rest.Length > cols)
        {
            int cut = separator == ' ' ? rest.LastIndexOf(' ', cols) : rest.LastIndexOf(separator, cols - 1);
            if (cut < cols / 3)
            {
                parts.Add(rest.Substring(0, cols));
                rest = rest.Substring(cols);
            }
            else if (separator == ' ')
            {
                parts.Add(rest.Substring(0, cut));
                rest = rest.Substring(cut + 1);
            }
            else
            {
                parts.Add(rest.Substring(0, cut + 1));
                rest = rest.Substring(cut + 1);
            }
        }
        parts.Add(rest);
        return parts;
    }

    static List<Run> Colored(string piece, int offset, int firstLength, Color first, Color rest)
    {
        List<Run> runs = new List<Run>();
        int inFirst = Math.Max(0, Math.Min(piece.Length, firstLength - offset));
        if (inFirst > 0) runs.Add(new Run(piece.Substring(0, inFirst), first));
        if (inFirst < piece.Length) runs.Add(new Run(piece.Substring(inFirst), rest));
        return runs;
    }

    static List<List<Run>> Painted(string text, int firstLength, Color first, Color rest, int cols)
    {
        List<List<Run>> lines = new List<List<Run>>();
        int pos = 0;
        while (pos < text.Length)
        {
            int remain = text.Length - pos;
            int len = remain, skip = 0;
            if (remain > cols)
            {
                int cut = text.LastIndexOf(' ', pos + cols, cols + 1);
                if (cut > pos + cols / 3) { len = cut - pos; skip = 1; }
                else len = cols;
            }
            lines.Add(Colored(text.Substring(pos, len), pos, firstLength, first, rest));
            pos += len + skip;
        }
        if (lines.Count == 0) lines.Add(new List<Run>());
        return lines;
    }

    void Build(Entry e)
    {
        List<List<Run>> lines = new List<List<Run>>();
        foreach (string part in Break(e.Dir, columns, '\\')) lines.Add(One(part, Text1));
        foreach (string part in Break(e.Script, columns, ' ')) lines.Add(One(part, Text1));
        if (e.Time.Length + 2 + e.Name.Length <= columns)
        {
            List<Run> both = new List<Run>();
            both.Add(new Run(e.Time, Muted));
            both.Add(new Run("  ", Muted));
            both.Add(new Run(e.Name, Ink));
            lines.Add(both);
        }
        else
        {
            lines.Add(One(e.Time, Muted));
            foreach (string part in Break(e.Name, columns, ' ')) lines.Add(One(part, Ink));
        }
        Color tone = e.Kind == 1 ? Bad : (e.Kind == 2 ? Neutral : Good);
        lines.AddRange(Painted(e.Result + e.Tags, e.Result.Length, tone, Muted, columns));
        e.Lines = lines;
        e.Columns = columns;
    }

    void Measure()
    {
        Size a = TextRenderer.MeasureText(new string('M', 100), LogFont, Size.Empty, Flags);
        Size b = TextRenderer.MeasureText(new string('M', 200), LogFont, Size.Empty, Flags);
        charWidth = Math.Max(1.0, (b.Width - a.Width) / 100.0);
        Size h = TextRenderer.MeasureText("Mg", LogFont, Size.Empty, Flags);
        lineHeight = h.Height + Math.Max(1, h.Height / 6);
        gapBefore = Math.Max(4, lineHeight / 2 - 1);
        gapAfter = gapBefore + 1;
    }

    void Relayout()
    {
        if (LogFont == null) return;
        Measure();
        fullColumns = (int)Math.Floor((Width - SystemInformation.VerticalScrollBarWidth) / charWidth);
        columns = Math.Max(12, fullColumns - Reserve);
        fullColumns = Math.Max(fullColumns, columns + Reserve);
        int total = 0;
        bool first = true;
        foreach (Entry e in entries)
        {
            if (e.Columns != columns) Build(e);
            if (!first) total += gapBefore + 1 + gapAfter;
            e.Top = total;
            total += e.Lines.Count * lineHeight;
            first = false;
        }
        AutoScrollMinSize = new Size(0, total);
    }

    protected override void OnResize(EventArgs e)
    {
        base.OnResize(e);
        Relayout();
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        g.Clear(BackColor);
        if (LogFont == null) return;
        if (entries.Count == 0)
        {
            TextRenderer.DrawText(g, EmptyText, LogFont, new Point(0, 0), Muted, BackColor, Flags);
            return;
        }
        int ruleWidth = Math.Min(ClientSize.Width, (int)Math.Round(fullColumns * charWidth));
        bool first = true;
        foreach (Entry en in entries)
        {
            int y = AutoScrollPosition.Y + en.Top;
            if (!first)
            {
                int ruleY = y - gapAfter - 1;
                if (ruleY >= -1 && ruleY <= ClientSize.Height)
                {
                    using (Pen pen = new Pen(Rule, 1f)) g.DrawLine(pen, 0, ruleY, ruleWidth, ruleY);
                }
            }
            first = false;
            int h = en.Lines.Count * lineHeight;
            if (y + h < 0 || y > ClientSize.Height) continue;
            int ly = y;
            foreach (List<Run> line in en.Lines)
            {
                int col = 0;
                foreach (Run r in line)
                {
                    TextRenderer.DrawText(g, r.Text, LogFont, new Point((int)Math.Round(col * charWidth), ly), r.Tone, Flags);
                    col += r.Text.Length;
                }
                ly += lineHeight;
            }
            if (copyIdle != null)
            {
                Bitmap icon = flashing == en ? (flashOk ? copyDone : copyFail) : (hot == en ? copyLit : copyIdle);
                g.DrawImage(icon, IconLeftPx, y + (lineHeight - iconSize) / 2, icon.Width, icon.Height);
            }
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            DisposeGlyphs();
            flashTimer.Dispose();
        }
        base.Dispose(disposing);
    }
}

public class DrawerForm : Form
{
    public DrawerForm()
    {
        SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint, true);
    }

    protected override bool ShowWithoutActivation
    {
        get { return true; }
    }

    protected override CreateParams CreateParams
    {
        get
        {
            CreateParams p = base.CreateParams;
            p.ExStyle |= 0x80 | 0x02000000;
            return p;
        }
    }
}

public static class WindowTools
{
    [StructLayout(LayoutKind.Sequential)]
    struct Box
    {
        public int Left, Top, Right, Bottom;
    }

    [DllImport("dwmapi.dll")]
    static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);

    [DllImport("dwmapi.dll")]
    static extern int DwmGetWindowAttribute(IntPtr hwnd, int attr, out Box value, int size);

    [DllImport("uxtheme.dll", CharSet = CharSet.Unicode)]
    static extern int SetWindowTheme(IntPtr hwnd, string app, string idList);

    public static Rectangle VisibleBounds(Form form)
    {
        Box b;
        if (form.IsHandleCreated && DwmGetWindowAttribute(form.Handle, 9, out b, Marshal.SizeOf(typeof(Box))) == 0 && b.Right > b.Left && b.Bottom > b.Top)
            return Rectangle.FromLTRB(b.Left, b.Top, b.Right, b.Bottom);
        return form.Bounds;
    }

    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();

    static int ColorRef(Color c)
    {
        return c.R | (c.G << 8) | (c.B << 16);
    }

    public static void Frame(IntPtr hwnd, Color caption, Color text, Color border)
    {
        int on = 1;
        DwmSetWindowAttribute(hwnd, 20, ref on, 4);
        int c = ColorRef(caption);
        DwmSetWindowAttribute(hwnd, 35, ref c, 4);
        int t = ColorRef(text);
        DwmSetWindowAttribute(hwnd, 36, ref t, 4);
        int b = ColorRef(border);
        DwmSetWindowAttribute(hwnd, 34, ref b, 4);
    }

    public static void Panel(IntPtr hwnd, Color border)
    {
        int round = 2;
        DwmSetWindowAttribute(hwnd, 33, ref round, 4);
        int b = ColorRef(border);
        DwmSetWindowAttribute(hwnd, 34, ref b, 4);
        int still = 1;
        DwmSetWindowAttribute(hwnd, 3, ref still, 4);
    }

    public static void DarkScrollBars(IntPtr hwnd)
    {
        SetWindowTheme(hwnd, "DarkMode_Explorer", null);
    }
}
'@
}

[void][WindowTools]::SetProcessDPIAware()
[System.Windows.Forms.Application]::EnableVisualStyles()

$root = $PSScriptRoot
$buttonDir = Join-Path $root 'Turn on'
$iconDir = Join-Path $root 'Development\iconen'
$deviceIconDir = Join-Path $iconDir 'apparaten'
$namesFile = Join-Path $root 'Development\namen.json'
$logFile = Join-Path $root 'Development\logboek.txt'
$archiveDir = Join-Path $root 'Development\archief'
$archiveBytes = 512KB
$logPage = 10
$logCap = 2000
$helpDir = Join-Path $root 'Development\help'
$powerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$taskKill = Join-Path $env:SystemRoot 'System32\taskkill.exe'
$utf8 = New-Object Text.UTF8Encoding $false
$timeoutSeconds = 60
$idleAfterSeconds = 5
$alreadyOnCode = 10
$notFoundCode = 11
$testCode = 12
$maxVisibleRows = 6
$slideMilliseconds = 180

$screen = [Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
$scale = $screen.DpiX / 96
$screen.Dispose()
function Px([double]$value) { [int][Math]::Round($value * $scale) }

$colorCard = [Drawing.Color]::FromArgb(28, 29, 35)
$colorWell = [Drawing.Color]::FromArgb(43, 47, 53)
$colorInk = [Drawing.Color]::FromArgb(255, 255, 255)
$colorIcon = [Drawing.Color]::FromArgb(201, 204, 209)
$colorMuted = [Drawing.Color]::FromArgb(151, 154, 160)
$colorMint = [Drawing.Color]::FromArgb(140, 250, 215)
$colorCoral = [Drawing.Color]::FromArgb(255, 155, 145)
$colorTerminal = [Drawing.Color]::FromArgb(12, 14, 18)

$fonts = @((New-Object Drawing.Text.InstalledFontCollection).Families | ForEach-Object Name)
function New-UiFont([string]$family, [string]$fallback, [float]$size) {
  $name = if ($fonts -contains $family) { $family } else { $fallback }
  New-Object Drawing.Font($name, $size)
}
$fontTitle = New-UiFont 'Segoe UI Variable Display Semib' 'Segoe UI Semibold' 16
$fontName = New-UiFont 'Segoe UI Variable Text Semibold' 'Segoe UI Semibold' 11
$fontStatus = New-UiFont 'Segoe UI Variable Small' 'Segoe UI' 9
$fontCaption = New-UiFont 'Segoe UI Variable Small' 'Segoe UI' 9
$fontLog = New-UiFont 'Cascadia Mono' 'Consolas' 8.1
$fontHelp = New-UiFont 'Segoe UI Variable Text' 'Segoe UI' 9.5
$fontColumns = New-UiFont 'Segoe UI Variable Small Semibol' 'Segoe UI Semibold' 8
$fontHouse = New-UiFont 'Segoe UI Variable Small Semibol' 'Segoe UI Semibold' 8.5
$fontTile = New-UiFont 'Segoe UI Variable Text Semibold' 'Segoe UI Semibold' 10

$textIdle = 'Idle'
$textBusy = 'Running' + [char]0x2026
$textDone = 'Script ran'
$textFailed = "Script didn't run"
$textTest = 'Test ran'
$titleFlags = [Windows.Forms.TextFormatFlags]'Left, VerticalCenter, NoPadding, SingleLine, NoPrefix, EndEllipsis'

$pad = Px 24
$width = Px 360
$headerTop = Px 14
$headerHeight = Px 36
$columnsTop = $headerTop + $headerHeight + (Px 8)
$columnsHeight = Px 26
$listTop = $columnsTop + $columnsHeight + (Px 10)
$houseColumn = Px 48
$houseGap = Px 12
$wellSize = Px 44
$nameGap = Px 14
$addHeight = Px 52
$emptyHeight = Px 48
$rowHeight = Px 60
$rowGap = Px 10
$bottom = Px 20
$drawerWidth = Px 440
$drawerGap = Px 8
$helpMax = Px 500
$tileHeight = Px 44
$tileGap = Px 8

function Get-Source([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  try { return [Drawing.Image]::FromFile($path) } catch { return $null }
}

$namesState = @{ Broken = $false }

function Read-Names {
  $found = @{}
  $namesState.Broken = $false
  if (Test-Path -LiteralPath $namesFile) {
    try {
      $json = Get-Content -LiteralPath $namesFile -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($json -isnot [Management.Automation.PSCustomObject]) { throw 'not an object' }
      foreach ($entry in $json.PSObject.Properties) { $found[$entry.Name] = [string]$entry.Value }
    } catch {
      $namesState.Broken = $true
      $found = @{}
    }
  }
  return $found
}

function Confirm-Folder([string]$file) {
  $folder = Split-Path -Path $file -Parent
  if (-not (Test-Path -LiteralPath $folder)) { [void](New-Item -ItemType Directory -Path $folder -Force) }
  return $folder
}

function Save-Name([string]$key, [string]$value) {
  $current = Read-Names
  if ($value) { $current[$key] = $value } else { $current.Remove($key) }
  try {
    $folder = Confirm-Folder $namesFile
    if ($namesState.Broken) { Copy-Item -LiteralPath $namesFile -Destination (Join-Path $folder 'namen.kapot.json') -Force }
    $data = [ordered]@{}
    foreach ($item in ($current.Keys | Sort-Object)) { $data[$item] = $current[$item] }
    $temp = $namesFile + '.tmp'
    [IO.File]::WriteAllText($temp, (ConvertTo-Json $data), $utf8)
    if (Test-Path -LiteralPath $namesFile) { [IO.File]::Replace($temp, $namesFile, [NullString]::Value) } else { [IO.File]::Move($temp, $namesFile) }
  } catch { }
}

$names = Read-Names

$form = New-Object Windows.Forms.Form
$form.Text = 'Creative Connection'
$form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::None
$form.FormBorderStyle = [Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.StartPosition = [Windows.Forms.FormStartPosition]::CenterScreen
$form.BackColor = $colorCard
$form.ForeColor = $colorInk
$form.Font = $fontStatus
$iconFile = Join-Path $iconDir 'logo.ico'
if (Test-Path -LiteralPath $iconFile) { $form.Icon = New-Object Drawing.Icon($iconFile) }
$form.Add_HandleCreated({ [WindowTools]::Frame($this.Handle, $colorCard, $colorMuted, $colorWell) })
$form.Add_Shown({ $this.ActiveControl = $null })

$body = New-Object Windows.Forms.Panel
$body.BackColor = $colorCard
$form.Controls.Add($body)

$title = 'Connected Devices'
$columns = @(
  @{ Text = 'HOUSE #'; Left = $pad },
  @{ Text = 'LOGO'; Left = $pad + $houseColumn + $houseGap },
  @{ Text = 'NAME'; Left = $pad + $houseColumn + $houseGap + $wellSize + $nameGap },
  @{ Text = 'POWER'; Left = -1 }
)
$columnFlags = [Windows.Forms.TextFormatFlags]'Left, VerticalCenter, NoPadding, SingleLine, NoPrefix'
$body.Add_Paint({
  $g = $_.Graphics
  $area = New-Object Drawing.Rectangle($pad, $headerTop, ($width - 2 * $pad - (Px 84)), $headerHeight)
  [Windows.Forms.TextRenderer]::DrawText($g, $title, $fontTitle, $area, $colorInk, $colorCard, $titleFlags)
  $line = New-Object Drawing.Pen($colorWell, 1)
  $g.DrawLine($line, $pad, $columnsTop, $width - $pad - 1, $columnsTop)
  $g.DrawLine($line, $pad, $columnsTop + $columnsHeight, $width - $pad - 1, $columnsTop + $columnsHeight)
  $line.Dispose()
  foreach ($column in $columns) {
    if ($column.Left -lt 0) {
      $cell = New-Object Drawing.Rectangle($pad, $columnsTop, ($width - 2 * $pad), $columnsHeight)
      $flags = [Windows.Forms.TextFormatFlags]'Right, VerticalCenter, NoPadding, SingleLine, NoPrefix'
    } else {
      $cell = New-Object Drawing.Rectangle($column.Left, $columnsTop, ($width - $pad - $column.Left), $columnsHeight)
      $flags = $columnFlags
    }
    [Windows.Forms.TextRenderer]::DrawText($g, $column.Text, $fontColumns, $cell, $colorMuted, $colorCard, $flags)
  }
})

$book = New-Object IconButton
$book.Size = New-Object Drawing.Size((Px 32), (Px 32))
$book.Location = New-Object Drawing.Point(($width - $pad - (Px 24) - (Px 16)), ($headerTop + [int](($headerHeight - (Px 32)) / 2)))
$book.Idle = $colorMuted
$book.Lit = $colorInk
$book.HoverFill = $colorWell
$book.AccessibleName = 'Show log'
$body.Controls.Add($book)

$info = New-Object IconButton
$info.Size = New-Object Drawing.Size((Px 32), (Px 32))
$info.Location = New-Object Drawing.Point(($book.Left - (Px 36)), $book.Top)
$info.Idle = $colorMuted
$info.Lit = $colorInk
$info.HoverFill = $colorWell
$info.AccessibleName = 'Show help'
$body.Controls.Add($info)

$list = New-Object Windows.Forms.Panel
$list.AutoScroll = $true
$list.Add_HandleCreated({ [WindowTools]::DarkScrollBars($this.Handle) })
$body.Controls.Add($list)

$drawer = New-Object DrawerForm
$drawer.FormBorderStyle = [Windows.Forms.FormBorderStyle]::None
$drawer.ShowInTaskbar = $false
$drawer.StartPosition = [Windows.Forms.FormStartPosition]::Manual
$drawer.AutoScaleMode = [Windows.Forms.AutoScaleMode]::None
$drawer.BackColor = $colorTerminal
$drawer.Add_HandleCreated({ [WindowTools]::Panel($this.Handle, $colorWell) })
$drawer.Add_FormClosing({
  if ($_.CloseReason -eq [Windows.Forms.CloseReason]::UserClosing) {
    $_.Cancel = $true
    Close-Log
  }
})

$drawerBody = New-Object Windows.Forms.Panel
$drawerBody.BackColor = $colorTerminal
$drawer.Controls.Add($drawerBody)

$closeLog = New-Object IconButton
$closeLog.Size = New-Object Drawing.Size((Px 32), (Px 32))
$closeLog.Idle = $colorMuted
$closeLog.Lit = $colorInk
$closeLog.HoverFill = $colorCard
$closeLog.AccessibleName = 'Close log'
$drawerBody.Controls.Add($closeLog)

$log = New-Object LogView
$log.BackColor = $colorTerminal
$log.LogFont = $fontLog
$log.Text1 = $colorIcon
$log.Muted = $colorMuted
$log.Ink = $colorInk
$log.Good = $colorMint
$log.Bad = $colorCoral
$log.Neutral = $colorIcon
$log.Rule = $colorWell
$log.EmptyText = 'No runs yet.'
$log.Limit = $logCap
$log.Add_HandleCreated({ [WindowTools]::DarkScrollBars($this.Handle) })
$drawerBody.Controls.Add($log)

$chipHeight = Px 24
$chips = @()
foreach ($spec in @(@('All', 'Show all runs'), @('On', 'Show only turn-ons'), @('Problems', 'Show only problems'))) {
  $chip = New-Object ChipButton
  $chip.Label = $spec[0]
  $chip.Font = $fontCaption
  $chip.Ink = $colorInk
  $chip.Idle = $colorMuted
  $chip.Fill = $colorWell
  $chip.HoverFill = $colorCard
  $chip.Alert = $colorCoral
  $chip.BackColor = $colorTerminal
  $chip.AccessibleName = $spec[1]
  $chip.Height = $chipHeight
  $drawerBody.Controls.Add($chip)
  $chips += $chip
}
$chipAll = $chips[0]
$chipOn = $chips[1]
$chipProblems = $chips[2]
$chipProblems.AlertWhenCounted = $true
$chipAll.Active = $true

$copyLog = New-Object IconButton
$copyLog.Size = New-Object Drawing.Size((Px 32), (Px 32))
$copyLog.Idle = $colorMuted
$copyLog.Lit = $colorInk
$copyLog.HoverFill = $colorCard
$copyLog.AccessibleName = 'Copy log'
$drawerBody.Controls.Add($copyLog)

$copiedNote = New-Object Windows.Forms.Label
$copiedNote.AutoSize = $false
$copiedNote.Font = $fontCaption
$copiedNote.ForeColor = $colorMint
$copiedNote.BackColor = $colorTerminal
$copiedNote.TextAlign = [Drawing.ContentAlignment]::MiddleRight
$copiedNote.UseMnemonic = $false
$copiedNote.Visible = $false
$copiedNote.Size = New-Object Drawing.Size((Px 110), (Px 24))
$drawerBody.Controls.Add($copiedNote)

$copyTimer = New-Object Windows.Forms.Timer
$copyTimer.Interval = 1600
$copyTimer.Add_Tick({ $copyTimer.Stop(); $copiedNote.Visible = $false })

$moreButton = New-Object ChipButton
$moreButton.Label = 'Show more'
$moreButton.Font = $fontCaption
$moreButton.Ink = $colorInk
$moreButton.Idle = $colorMuted
$moreButton.Fill = $colorWell
$moreButton.HoverFill = $colorCard
$moreButton.BackColor = $colorTerminal
$moreButton.AccessibleName = 'Show older runs'
$moreButton.Height = $chipHeight
$moreButton.Visible = $false
$drawerBody.Controls.Add($moreButton)

$logState = @{ Loaded = $false; Filter = 0; Shown = $logPage; More = $false; Counts = @{ All = 0; On = 0; Problems = 0; Test = 0 } }
$drawerState = @{ Open = $false; Side = 'right'; From = 1; To = 1; Started = [DateTime]::UtcNow }

$dot = [string][char]0x00B7
$filterTexts = @('No runs yet.', 'No turn-ons yet.', 'No problems.')
$filterNames = @('all runs', 'only turn-ons', 'only problems')
$clipboardWriter = { param([string]$text) [Windows.Forms.Clipboard]::SetDataObject($text, $true, 5, 100) }

function Get-ResultText([string]$result) {
  switch -Regex ($result) {
    '^(sent|ran)$' { return 'Sent' }
    '^already-on$' { return 'Already on' }
    '^not-found$' { return 'Not found' }
    '^test$' { return 'Test' }
    '^timeout$' { return 'Failed (timeout)' }
  }
  return 'Failed'
}

function Test-Problem([string]$result) {
  return -not ($result -match '^(sent|ran|already-on|test)$')
}

function Get-LogKind([string]$result) {
  if ($result -eq 'test') { return 2 }
  if (Test-Problem $result) { return 1 }
  return 0
}

function Get-ExitFromResult([string]$result) {
  switch -Regex ($result) {
    '^(sent|ran)$' { return '0' }
    '^already-on$' { return '10' }
    '^not-found$' { return '11' }
    '^test$' { return '12' }
    '^exit (-?\d+)$' { return $Matches[1] }
  }
  return ''
}

function Get-OutcomeWord([string]$result) {
  switch -Regex ($result) {
    '^(sent|ran)$' { return 'sent' }
    '^(already-on|not-found|test|timeout)$' { return $result }
  }
  return 'failed'
}
function Find-Row([string]$path) {
  return @($rows | Where-Object { $_.Tag.Path -eq $path }) | Select-Object -First 1
}
function Get-LogEntry([string[]]$parts) {
  $name = $parts[2]
  $path = $parts[3]
  $row = Find-Row $path
  $text = Get-ResultText $parts[1]
  if ($parts[1] -eq 'not-found' -and $row -and $row.HouseNumber) { $text += " at number $($row.HouseNumber)" }
  $source = if ($parts.Count -ge 5) { $parts[4] } else { '' }
  if ($source -eq 'direct' -and $row) { $name = $row.Text }
  $exit = if ($parts.Count -ge 6 -and $parts[5] -ne '') { $parts[5] } else { Get-ExitFromResult $parts[1] }
  $seconds = if ($parts.Count -ge 7) { $parts[6] } else { '' }
  $version = if ($parts.Count -ge 8) { $parts[7] } else { '' }
  $utc = if ($parts.Count -ge 9) { $parts[8] } else { '' }
  $notes = New-Object System.Collections.ArrayList
  if ($exit -ne '') { [void]$notes.Add("exit $exit") }
  if ($seconds -ne '') { [void]$notes.Add("$seconds s") }
  if ($source -eq 'app') { [void]$notes.Add('app') } elseif ($source -eq 'direct') { [void]$notes.Add('outside app') }
  $tags = if ($notes.Count -gt 0) { " $dot " + ($notes -join " $dot ") } else { '' }
  $leaf = Split-Path -Path $path -Leaf
  $fields = @($parts[0], (Get-OutcomeWord $parts[1]), ($name -replace '\|', '/'), $(if ($exit -ne '') { "exit $exit" } else { '-' }), $(if ($seconds -ne '') { "$seconds s" } else { '-' }), $(if ($source) { $source } else { '-' }), ($leaf -replace '\|', '/'), $(if ($version) { $version } else { '-' }), $(if ($utc) { $utc } else { '-' }))
  return @{
    Dir = (Split-Path -Path $path -Parent) + '>'
    Script = $leaf
    Time = $parts[0]
    Name = $name
    Text = $text
    Tags = $tags
    Ok = -not (Test-Problem $parts[1])
    Kind = Get-LogKind $parts[1]
    Exit = $exit
    Seconds = $seconds
    Source = $source
    Version = $version
    Utc = $utc
    Copy = ($fields -join ' | ')
  }
}

function Add-LogEntry([string[]]$parts) {
  $entry = Get-LogEntry $parts
  $log.Add($entry.Dir, $entry.Script, $entry.Time, $entry.Name, $entry.Text, $entry.Tags, [int]$entry.Kind, $entry.Copy)
}
function Get-LogFiles {
  $files = New-Object System.Collections.ArrayList
  if (Test-Path -LiteralPath $logFile) { [void]$files.Add($logFile) }
  if (Test-Path -LiteralPath $archiveDir) {
    foreach ($item in @(Get-ChildItem -LiteralPath $archiveDir -Filter 'logboek-*.txt' -File | Sort-Object Name -Descending)) { [void]$files.Add($item.FullName) }
  }
  return ,([string[]]$files.ToArray())
}

function Get-LogTail([int]$count = 300, [int]$kind = 0) {
  try { return ,([string[]][LogFiles]::Tail((Get-LogFiles), $kind, $count)) } catch { return ,([string[]]@()) }
}

function Move-OldLog {
  try {
    if (-not (Test-Path -LiteralPath $logFile)) { return }
    if ((Get-Item -LiteralPath $logFile).Length -le $archiveBytes) { return }
    [void](New-Item -ItemType Directory -Force -Path $archiveDir)
    $stamp = (Get-Date).ToString('yyyy-MM-dd-HHmmss-fff', [Globalization.CultureInfo]::InvariantCulture)
    $copy = 1
    $target = Join-Path $archiveDir ('logboek-{0}-{1:D3}.txt' -f $stamp, $copy)
    while (Test-Path -LiteralPath $target) { $copy++; $target = Join-Path $archiveDir ('logboek-{0}-{1:D3}.txt' -f $stamp, $copy) }
    for ($try = 0; $try -lt 10; $try++) {
      try { [IO.File]::Move($logFile, $target); return } catch { Start-Sleep -Milliseconds 100 }
    }
  } catch { }
}

$archiveCounts = @{}

function Update-LogCounts {
  $total = @(0, 0, 0, 0)
  foreach ($file in (Get-LogFiles)) {
    $counts = $null
    if ($file -eq $logFile) {
      $counts = [LogFiles]::Count($file)
    } else {
      $info = Get-Item -LiteralPath $file
      $key = '{0}|{1}|{2}' -f $file, $info.Length, $info.LastWriteTimeUtc.Ticks
      if (-not $archiveCounts.ContainsKey($key)) { $archiveCounts[$key] = [LogFiles]::Count($file) }
      $counts = $archiveCounts[$key]
    }
    for ($i = 0; $i -lt 4; $i++) { $total[$i] += $counts[$i] }
  }
  $logState.Counts = @{ All = $total[0]; On = $total[1]; Problems = $total[2]; Test = $total[3] }
}

function Update-Alerts([string[]]$lines) {
  $last = @{}
  foreach ($line in $lines) {
    $parts = $line -split "`t"
    if ($parts.Count -ge 4) { $last[$parts[3]] = $parts[1] }
  }
  foreach ($item in $rows) {
    if ($last.ContainsKey($item.Tag.Path)) { $item.HouseAlert = Test-Problem $last[$item.Tag.Path] }
  }
}
function Set-ChipLayout {
  $captionHeight = $form.PointToScreen([Drawing.Point]::Empty).Y - (Get-Visible).Top
  $left = (Px 18) + [Windows.Forms.TextRenderer]::MeasureText('Log', $fontCaption).Width + (Px 14)
  $top = [int](($captionHeight - $chipHeight) / 2)
  foreach ($chip in $chips) {
    $chip.Width = $chip.FitWidth((Px 10), (Px 5))
    $chip.Location = New-Object Drawing.Point($left, $top)
    $left += $chip.Width + (Px 6)
  }
}

function Update-Chips {
  $chipAll.Count = $logState.Counts.All
  $chipOn.Count = $logState.Counts.On
  $chipProblems.Count = $logState.Counts.Problems
  Set-ChipLayout
}

function Get-FilterTotal {
  switch ($logState.Filter) {
    1 { return $logState.Counts.On }
    2 { return $logState.Counts.Problems }
  }
  return $logState.Counts.All
}

function Update-MoreButton {
  $left = [Math]::Max(0, (Get-FilterTotal) - $log.Count)
  $show = ($left -gt 0) -and ($log.Count -lt $logCap)
  $moreButton.Count = $left
  $moreButton.Width = $moreButton.FitWidth((Px 12), (Px 6))
  $logState.More = $show
  $moreButton.Visible = $show
  Set-DrawerLayout
}

function Set-LogFilter([int]$value) {
  $logState.Filter = $value
  $logState.Shown = $logPage
  for ($i = 0; $i -lt $chips.Count; $i++) { $chips[$i].Active = ($i -eq $value) }
  $log.EmptyText = $filterTexts[$value]
  Read-Log
}

function Show-MoreLog {
  $logState.Shown = [Math]::Min($logCap, $logState.Shown + $logPage)
  Read-Log $false
  $log.ScrollToTop()
}

function Get-LogLegend {
  return @(
    'Each line: local time | outcome | device | exit code | seconds | source | script | version | UTC time',
    "Outcome: sent (exit 0), already-on (10), not-found (11), test (12), failed (any other exit code), timeout (no answer within $timeoutSeconds seconds).",
    'Source: app = the button in the app, direct = the script was run outside the app.',
    "Version: the first 8 characters of the script's SHA-256 fingerprint. A dash means unknown."
  )
}

function Get-LogCopyText {
  $showing = if ($logState.Filter -eq 0) { "Showing all runs: $($log.Count) of $($logState.Counts.All) lines." } else { "Showing $($filterNames[$logState.Filter]): $($log.Count) of $(Get-FilterTotal) (the log has $($logState.Counts.All) lines)." }
  $header = @('Creative Connection log, newest line last.', $showing) + (Get-LogLegend) + @('')
  return (($header -join "`r`n") + "`r`n" + $log.CopyText())
}

function Get-LogLineCopyText([string]$line) {
  $header = @('Creative Connection log, one line.') + (Get-LogLegend) + @('')
  return (($header -join "`r`n") + "`r`n" + $line + "`r`n")
}

function Send-ToClipboard([string]$text) {
  $ok = $true
  try { & $clipboardWriter $text } catch { $ok = $false }
  $copiedNote.Text = if ($ok) { 'Copied' } else { "Couldn't copy" }
  $copiedNote.ForeColor = if ($ok) { $colorMint } else { $colorCoral }
  $copiedNote.Visible = $true
  $copyTimer.Stop()
  $copyTimer.Start()
  return $ok
}

function Copy-Log {
  [void](Send-ToClipboard (Get-LogCopyText))
}

function Copy-LogEntry([string]$line) {
  $log.MarkCopied([bool](Send-ToClipboard (Get-LogLineCopyText $line)))
}
function Read-Log([bool]$toLatest = $true) {
  $log.Clear()
  $lines = Get-LogTail $logState.Shown $logState.Filter
  foreach ($line in $lines) {
    $parts = [string[]]($line -split "`t")
    if ($parts.Count -ge 4) { Add-LogEntry $parts }
  }
  Update-Alerts (Get-LogTail 300 0)
  $logState.Loaded = $true
  Update-LogCounts
  Update-Chips
  Update-MoreButton
  if ($toLatest) { $log.ShowLatest() }
}

function Add-LogLine([string]$text) {
  $bytes = $utf8.GetBytes($text)
  try { [void](Confirm-Folder $logFile) } catch { }
  for ($try = 0; $try -lt 5; $try++) {
    try {
      $stream = New-Object IO.FileStream($logFile, [IO.FileMode]::Append, [Security.AccessControl.FileSystemRights]::AppendData, [IO.FileShare]::ReadWrite, 4096, [IO.FileOptions]::None)
      try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
      return
    } catch { Start-Sleep -Milliseconds 30 }
  }
}

function Write-Log($row, [string]$result, $info = $null) {
  $time = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  $utcTime = [DateTime]::UtcNow.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", [Globalization.CultureInfo]::InvariantCulture)
  $name = $row.Text -replace '[\t\r\n]', ' '
  $exit = ''
  $seconds = ''
  $version = ''
  if ($info) {
    if ($null -ne $info.Exit) { $exit = [string]$info.Exit }
    if ($null -ne $info.Seconds) { $seconds = ([double]$info.Seconds).ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) }
    if ($info.Version) { $version = [string]$info.Version }
  }
  $parts = [string[]]@($time, $result, $name, $row.Tag.Path, 'app', $exit, $seconds, $version, $utcTime)
  Add-LogLine (($parts -join "`t") + "`r`n")
  if ($logState.Loaded) {
    $kind = Get-LogKind $result
    $logState.Counts.All++
    if ($kind -eq 0) { $logState.Counts.On++ } elseif ($kind -eq 1) { $logState.Counts.Problems++ } else { $logState.Counts.Test++ }
    if ($logState.Filter -eq 0 -or ($logState.Filter -eq 1 -and $kind -eq 0) -or ($logState.Filter -eq 2 -and $kind -eq 1)) { Add-LogEntry $parts }
    Update-Chips
    Update-MoreButton
    $log.ShowLatest()
  }
}
function Get-Visible {
  return [WindowTools]::VisibleBounds($form)
}

function Set-DrawerLayout {
  $vis = Get-Visible
  $captionHeight = $form.PointToScreen([Drawing.Point]::Empty).Y - $vis.Top
  $drawerBody.Size = New-Object Drawing.Size($drawerWidth, $vis.Height)
  $closeLog.Location = New-Object Drawing.Point(($drawerWidth - (Px 8) - $closeLog.Width), [int](($captionHeight - $closeLog.Height) / 2))
  $copyLog.Location = New-Object Drawing.Point(($closeLog.Left - (Px 4) - $copyLog.Width), $closeLog.Top)
  $copiedNote.Location = New-Object Drawing.Point(($copyLog.Left - $copiedNote.Width), [int](($captionHeight - $copiedNote.Height) / 2))
  Set-ChipLayout
  $logTop = $captionHeight + $headerTop
  $moreRoom = if ($logState.More) { $chipHeight + (Px 12) } else { 0 }
  $log.Bounds = New-Object Drawing.Rectangle((Px 18), $logTop, ($drawerWidth - (Px 18) - (Px 6)), ($vis.Height - $logTop - (Px 14) - $moreRoom))
  $moreButton.Location = New-Object Drawing.Point([int](($drawerWidth - $moreButton.Width) / 2), ($vis.Height - (Px 14) - $chipHeight))
}

$drawerBody.Add_Paint({
  $captionHeight = $form.PointToScreen([Drawing.Point]::Empty).Y - (Get-Visible).Top
  $area = New-Object Drawing.Rectangle((Px 18), 0, ($drawerWidth - (Px 60)), $captionHeight)
  [Windows.Forms.TextRenderer]::DrawText($_.Graphics, 'Log', $fontCaption, $area, $colorMuted, $colorTerminal, $titleFlags)
})

function Set-DrawerWidth([int]$value) {
  $value = [Math]::Max(1, $value)
  $vis = Get-Visible
  if ($drawerState.Side -eq 'right') {
    $left = $vis.Right + $drawerGap
    $drawerBody.Left = $value - $drawerWidth
  } else {
    $left = $vis.Left - $drawerGap - $value
    $drawerBody.Left = 0
  }
  $drawer.SetBounds($left, $vis.Top, $value, $vis.Height)
}

$slide = New-Object Windows.Forms.Timer
$slide.Interval = 15
$slide.Add_Tick({
  $progress = [Math]::Min(1.0, ([DateTime]::UtcNow - $drawerState.Started).TotalMilliseconds / $slideMilliseconds)
  $ease = 1 - [Math]::Pow(1 - $progress, 3)
  Set-DrawerWidth ([int]($drawerState.From + ($drawerState.To - $drawerState.From) * $ease))
  if ($progress -ge 1) {
    $slide.Stop()
    if (-not $drawerState.Open) { $drawer.Hide() }
  }
})

function Start-Slide {
  if (-not [Motion]::Enabled) {
    Set-DrawerWidth $drawerState.To
    if (-not $drawerState.Open) { $drawer.Hide() }
    return
  }
  $drawerState.Started = [DateTime]::UtcNow
  $slide.Start()
}

function Get-DrawerSide {
  $area = [Windows.Forms.Screen]::FromControl($form).WorkingArea
  $vis = Get-Visible
  $fitsRight = $vis.Right + $drawerGap + $drawerWidth -le $area.Right
  $fitsLeft = $vis.Left - $drawerGap - $drawerWidth -ge $area.Left
  if ($fitsRight -or -not $fitsLeft) { return 'right' }
  return 'left'
}

function Open-Log {
  Set-DrawerLayout
  $logState.Shown = $logPage
  Read-Log
  $drawerState.Side = Get-DrawerSide
  $drawerState.From = if ($drawer.Visible) { $drawer.Width } else { 1 }
  $drawerState.To = $drawerWidth
  $drawerState.Open = $true
  if (-not $drawer.Visible) {
    Set-DrawerWidth 1
    $drawer.Show($form)
  }
  $log.ShowLatest()
  $book.AccessibleName = 'Hide log'
  Start-Slide
}

function Close-Log {
  if (-not $drawer.Visible) { return }
  $drawerState.From = $drawer.Width
  $drawerState.To = 1
  $drawerState.Open = $false
  $book.AccessibleName = 'Show log'
  Start-Slide
}

$book.Add_Click({ if ($drawerState.Open) { Close-Log } else { Open-Log } })
$closeLog.Add_Click({ Close-Log })
$chipAll.Add_Click({ Set-LogFilter 0 })
$chipOn.Add_Click({ Set-LogFilter 1 })
$chipProblems.Add_Click({ Set-LogFilter 2 })
$copyLog.Add_Click({ Copy-Log })
$moreButton.Add_Click({ Show-MoreLog })
$log.add_CopyRequested({ param($sender, $e) Copy-LogEntry $e.Text })
$form.Add_Move({
  if ($drawer.Visible) {
    $drawerState.Side = Get-DrawerSide
    Set-DrawerWidth $drawer.Width
  }
})
$form.Add_Resize({
  if ($drawer.Visible) {
    Set-DrawerLayout
    Set-DrawerWidth $drawer.Width
  }
})

$rows = New-Object System.Collections.ArrayList
$running = New-Object System.Collections.ArrayList

function Get-ScriptVersion([string]$path) {
  $sha = $null
  try {
    $sha = [Security.Cryptography.SHA256]::Create()
    $hash = $sha.ComputeHash([IO.File]::ReadAllBytes($path))
    return (($hash[0..3] | ForEach-Object { $_.ToString('x2') }) -join '')
  } catch { return '' } finally { if ($sha) { $sha.Dispose() } }
}

function Test-Downloaded([string]$path) {
  try { $zone = @(Get-Content -LiteralPath $path -Stream 'Zone.Identifier' -ErrorAction Stop) } catch { return $false }
  return (@($zone | Where-Object { $_ -match '^\s*ZoneId\s*=\s*[34]\s*$' }).Count -gt 0)
}

$confirmDownload = {
  param([string]$name)
  $text = "This script was downloaded from the internet.`nRead it first. Start it anyway?"
  $answer = [Windows.Forms.MessageBox]::Show($form, $text, $name, [Windows.Forms.MessageBoxButtons]::YesNo, [Windows.Forms.MessageBoxIcon]::Warning, [Windows.Forms.MessageBoxDefaultButton]::Button2)
  return ($answer -eq [Windows.Forms.DialogResult]::Yes)
}

function Start-Device($button) {
  $row = $button.Tag
  if ((Test-Downloaded $row.Tag.Path) -and -not (& $confirmDownload $row.Text)) { return }
  $version = Get-ScriptVersion $row.Tag.Path
  $start = New-Object Diagnostics.ProcessStartInfo $powerShell
  $start.Arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}"' -f $row.Tag.Path
  $start.WorkingDirectory = $buttonDir
  $start.UseShellExecute = $false
  $start.CreateNoWindow = $true
  $start.EnvironmentVariables['CREATIVE_CONNECTION'] = 'app'
  $row.Tag.ResetAt = $null
  try { $process = [Diagnostics.Process]::Start($start) } catch { Complete-Run $row 'exit -1' @{ Exit = -1; Seconds = 0; Version = $version }; return }
  $button.Busy = $true
  $row.SetStatus($textBusy, $colorMuted)
  [void]$running.Add(@{ Row = $row; Process = $process; Started = [DateTime]::UtcNow; Version = $version })
  $timer.Start()
}

function Complete-Run($row, [string]$result, $info = $null) {
  $row.Button.Busy = $false
  $row.HouseAlert = Test-Problem $result
  if ($result -eq 'test') {
    $row.SetStatus($textTest, $colorMuted)
    $row.Tag.ResetAt = [DateTime]::UtcNow.AddSeconds($idleAfterSeconds)
  } elseif ($result -eq 'sent' -or $result -eq 'already-on' -or $result -eq 'not-found') {
    $row.SetStatus($textDone, $colorMint)
    $row.Tag.ResetAt = [DateTime]::UtcNow.AddSeconds($idleAfterSeconds)
  } else {
    $row.SetStatus($textFailed, $colorCoral)
    $row.Tag.ResetAt = $null
  }
  Write-Log $row $result $info
  $timer.Start()
}

function Complete-Device($job, [bool]$timedOut) {
  [void]$running.Remove($job)
  $result = 'timeout'
  $code = $null
  if ($timedOut) {
    try {
      $stop = New-Object Diagnostics.ProcessStartInfo $taskKill
      $stop.Arguments = '/PID {0} /T /F' -f $job.Process.Id
      $stop.UseShellExecute = $false
      $stop.CreateNoWindow = $true
      $killer = [Diagnostics.Process]::Start($stop)
      [void]$killer.WaitForExit(3000)
      $killer.Dispose()
    } catch { }
    try { if (-not $job.Process.HasExited) { $job.Process.Kill() } } catch { }
  } else {
    $code = $job.Process.ExitCode
    $result = if ($code -eq 0) { 'sent' } elseif ($code -eq $alreadyOnCode) { 'already-on' } elseif ($code -eq $notFoundCode) { 'not-found' } elseif ($code -eq $testCode) { 'test' } else { "exit $code" }
  }
  $seconds = [Math]::Round(([DateTime]::UtcNow - $job.Started).TotalSeconds, 1)
  $job.Process.Dispose()
  Complete-Run $job.Row $result @{ Exit = $code; Seconds = $seconds; Version = $job.Version }
}

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 200
$timer.Add_Tick({
  foreach ($job in @($running)) {
    if ($job.Process.HasExited) { Complete-Device $job $false }
    elseif (([DateTime]::UtcNow - $job.Started).TotalSeconds -gt $timeoutSeconds) { Complete-Device $job $true }
  }
  $now = [DateTime]::UtcNow
  $waiting = $false
  foreach ($item in $rows) {
    if ($null -eq $item.Tag.ResetAt) { continue }
    if ($now -ge $item.Tag.ResetAt) {
      $item.Tag.ResetAt = $null
      $item.SetStatus($textIdle, $colorMuted)
    } else { $waiting = $true }
  }
  if ($running.Count -eq 0 -and -not $waiting) { $timer.Stop() }
})

$scripts = @()
if (Test-Path -LiteralPath $buttonDir) {
  $scripts = @(Get-ChildItem -LiteralPath $buttonDir -Filter '*.ps1' -File | Where-Object { $_.Extension -eq '.ps1' } | Sort-Object Name)
}

function Get-HouseNumber([string]$path) {
  try { $text = [IO.File]::ReadAllText($path) } catch { return '' }
  foreach ($match in [regex]::Matches($text, '(?<![\d.])(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(?![\d.])')) {
    $octets = @(1..4 | ForEach-Object { [int]$match.Groups[$_].Value })
    if (@($octets | Where-Object { $_ -gt 255 }).Count -gt 0) { continue }
    if ($octets[0] -in 0, 127, 255 -or $octets[3] -in 0, 255) { continue }
    return [string]$octets[3]
  }
  return ''
}

$powerSource = Get-Source (Join-Path $iconDir 'power.png')
$pencilSource = Get-Source (Join-Path $iconDir 'pencil.png')
$fallbackSource = Get-Source (Join-Path $iconDir 'apparaat.png')
$bookSource = Get-Source (Join-Path $iconDir 'book-open.png')
$closeSource = Get-Source (Join-Path $iconDir 'x.png')
$copySource = Get-Source (Join-Path $iconDir 'copy.png')
if ($bookSource) { $book.SetGlyph($bookSource, (Px 18)) }
if ($closeSource) { $closeLog.SetGlyph($closeSource, (Px 16)) }
if ($copySource) { $copyLog.SetGlyph($copySource, (Px 16)); $log.SetCopyGlyph($copySource, (Px 14), $colorMuted, $colorInk, $colorMint, $colorCoral) }

foreach ($script in $scripts) {
  $key = $script.BaseName
  $defaultName = $key
  $row = New-Object DeviceRow
  $row.Tag = @{ Key = $key; Path = $script.FullName; ResetAt = $null }
  $row.DefaultName = $defaultName
  $row.BackColor = $colorCard
  $row.Well = $colorWell
  $row.Ink = $colorInk
  $row.NameFont = $fontName
  $row.StatusFont = $fontStatus
  $row.WellSize = $wellSize
  $row.Gap = $nameGap
  $row.HouseColumn = $houseColumn
  $row.EditGap = Px 4
  $row.HouseFont = $fontHouse
  $row.HouseBack = $colorWell
  $row.HouseInk = $colorIcon
  $row.AlertInk = $colorCoral
  $row.HouseGap = $houseGap
  $row.HouseNumber = Get-HouseNumber $script.FullName
  $row.Text = if ($names.ContainsKey($key)) { $names[$key] } else { $defaultName }
  $row.AccessibleName = $row.Text
  $row.SetStatus($textIdle, $colorMuted)

  $iconPath = Join-Path $deviceIconDir ((($defaultName -split ' ')[0]).ToLower() + '.png')
  $source = Get-Source $iconPath
  if ($source) { $row.SetIcon($source, $colorIcon, (Px 22)); $source.Dispose() }
  elseif ($fallbackSource) { $row.SetIcon($fallbackSource, $colorIcon, (Px 20)) }

  $edit = $row.Edit
  $edit.Size = New-Object Drawing.Size((Px 24), (Px 24))
  $edit.Idle = $colorMuted
  $edit.Lit = $colorInk
  $edit.HoverFill = $colorWell
  $edit.AccessibleName = 'Rename'
  if ($pencilSource) { $edit.SetGlyph($pencilSource, (Px 14)) }

  $button = $row.Button
  $button.Size = New-Object Drawing.Size((Px 48), (Px 48))
  $button.Well = $colorWell
  $button.Accent = $colorMint
  $button.AccessibleName = "Turn on $($row.Text)"
  if ($powerSource) { $button.SetGlyph($powerSource, $colorInk, (Px 20)) }
  $button.Tag = $row
  $button.Add_Click({ Start-Device $this })

  $row.add_NameCommitted({
    param($changed)
    $value = if ($changed.Text -eq $changed.DefaultName) { $null } else { $changed.Text }
    Save-Name $changed.Tag.Key $value
    $changed.AccessibleName = $changed.Text
    $changed.Button.AccessibleName = "Turn on $($changed.Text)"
  })

  $list.Controls.Add($row)
  [void]$rows.Add($row)
}
foreach ($source in @($powerSource, $pencilSource, $fallbackSource, $bookSource, $closeSource, $copySource)) { if ($source) { $source.Dispose() } }

$addRow = New-Object AddRow
$addRow.Text = 'Add device'
$addRow.Font = $fontName
$addRow.Ink = $colorInk
$addRow.Idle = $colorMuted
$addRow.Border = [Drawing.Color]::FromArgb(74, 78, 87)
$addRow.HoverFill = [Drawing.Color]::FromArgb(35, 37, 43)
$addRow.Radius = Px 10
$addRow.GlyphLeft = Px 16
$addRow.TextGap = Px 12
$addRow.AccessibleName = 'Add device'
$plusSource = Get-Source (Join-Path $iconDir 'circle-plus.png')
if ($plusSource) { $addRow.SetGlyph($plusSource, (Px 22)); $plusSource.Dispose() }
$list.Controls.Add($addRow)

$empty = $null
if ($rows.Count -eq 0) {
  $empty = New-Object Windows.Forms.Label
  $empty.Text = 'No devices yet'
  $empty.Font = $fontHelp
  $empty.ForeColor = $colorMuted
  $empty.UseMnemonic = $false
  $empty.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
  $list.Controls.Add($empty)
}

$scrolls = $rows.Count -gt $maxVisibleRows
$rowWidth = $width - 2 * $pad
if ($scrolls) { $rowWidth -= [Windows.Forms.SystemInformation]::VerticalScrollBarWidth + (Px 8) }
$y = 0
for ($i = 0; $i -lt $rows.Count; $i++) {
  $rows[$i].Bounds = New-Object Drawing.Rectangle(0, $y, $rowWidth, $rowHeight)
  $rows[$i].Arrange()
  $y += $rowHeight + $rowGap
}
if ($empty) {
  $empty.Bounds = New-Object Drawing.Rectangle(0, $y, $rowWidth, $emptyHeight)
  $y += $emptyHeight + $rowGap
}
$addRow.Bounds = New-Object Drawing.Rectangle(0, $y, $rowWidth, $addHeight)
$y += $addHeight
$listHeight = if ($scrolls) { $maxVisibleRows * ($rowHeight + $rowGap) + $addHeight } else { $y }
$list.Bounds = New-Object Drawing.Rectangle($pad, $listTop, ($width - 2 * $pad), $listHeight)

function Get-HouseFor([string]$name) {
  $match = @($rows | Where-Object { $_.DefaultName -eq $name }) | Select-Object -First 1
  if ($match -and $match.HouseNumber) { return $match.HouseNumber }
  return '?'
}

function Read-HelpSections {
  $found = New-Object System.Collections.ArrayList
  $helpRoot = [IO.Path]::GetFullPath($helpDir).TrimEnd('\') + '\'
  if (Test-Path -LiteralPath $helpDir) {
    foreach ($file in @(Get-ChildItem -LiteralPath $helpDir -Filter '*.md' -File | Where-Object { $_.Extension -eq '.md' } | Sort-Object Name)) {
      $heading = $null
      $items = New-Object System.Collections.ArrayList
      $block = New-Object System.Collections.ArrayList
      $lines = @()
      try { $lines = @(Get-Content -LiteralPath $file.FullName -Encoding UTF8) } catch { }
      foreach ($raw in $lines) {
        $line = $raw.Trim()
        if (-not $heading -and $line.StartsWith('# ')) { $heading = $line.Substring(2).Trim(); continue }
        if ($line -eq '') {
          if ($block.Count -gt 0) { [void]$items.Add(($block -join "`n")); $block.Clear() }
          continue
        }
        $line = [regex]::Replace($line, '\{house:([^}]+)\}', { param($m) Get-HouseFor $m.Groups[1].Value })
        if ($line -match '^!\[[^\]]*\]\(([^)]+)\)$') {
          if ($block.Count -gt 0) { [void]$items.Add(($block -join "`n")); $block.Clear() }
          $picture = $null
          try { if (-not $Matches[1].Contains(':')) { $picture = [IO.Path]::GetFullPath((Join-Path $helpDir $Matches[1])) } } catch { }
          if ($picture -and $picture.StartsWith($helpRoot, [StringComparison]::OrdinalIgnoreCase)) { [void]$items.Add('![picture](' + $picture + ')') }
          continue
        }
        if ($line -match '^\d+\.\s' -or $line.StartsWith('Tip: ')) {
          if ($block.Count -gt 0) { [void]$items.Add(($block -join "`n")); $block.Clear() }
          [void]$items.Add($line)
          continue
        }
        [void]$block.Add($line)
      }
      if ($block.Count -gt 0) { [void]$items.Add(($block -join "`n")) }
      if ($heading) { [void]$found.Add(@{ Title = $heading; Items = [string[]]$items.ToArray() }) }
    }
  }
  if ($found.Count -eq 0) { [void]$found.Add(@{ Title = 'Help'; Items = [string[]]@('No help texts found in Development\help.') }) }
  return ,$found.ToArray()
}

$helpSections = Read-HelpSections

$helpDrawer = New-Object DrawerForm
$helpDrawer.FormBorderStyle = [Windows.Forms.FormBorderStyle]::None
$helpDrawer.ShowInTaskbar = $false
$helpDrawer.StartPosition = [Windows.Forms.FormStartPosition]::Manual
$helpDrawer.AutoScaleMode = [Windows.Forms.AutoScaleMode]::None
$helpDrawer.BackColor = $colorCard
$helpDrawer.Add_HandleCreated({ [WindowTools]::Panel($this.Handle, $colorWell) })
$helpDrawer.Add_FormClosing({
  if ($_.CloseReason -eq [Windows.Forms.CloseReason]::UserClosing) {
    $_.Cancel = $true
    Close-Help
  }
})

$helpState = @{ Open = $false; Side = 'above'; From = 1; To = 1; Full = 1; Caption = 0; Started = [DateTime]::UtcNow; Page = $null }

$helpBody = New-Object Windows.Forms.Panel
$helpBody.BackColor = $colorCard
$helpDrawer.Controls.Add($helpBody)
$helpBody.Add_Paint({
  $left = if ($helpState.Page) { (Px 8) + $helpBack.Width + (Px 2) } else { Px 18 }
  $area = New-Object Drawing.Rectangle($left, 0, ($helpBody.Width - $left - (Px 44)), $helpState.Caption)
  [Windows.Forms.TextRenderer]::DrawText($_.Graphics, 'Help / FAQ', $fontCaption, $area, $colorMuted, $colorCard, $titleFlags)
})

$closeHelp = New-Object IconButton
$closeHelp.Size = New-Object Drawing.Size((Px 32), (Px 32))
$closeHelp.Idle = $colorMuted
$closeHelp.Lit = $colorInk
$closeHelp.HoverFill = $colorWell
$closeHelp.AccessibleName = 'Close help'
$helpBody.Controls.Add($closeHelp)

$helpBack = New-Object IconButton
$helpBack.Size = New-Object Drawing.Size((Px 32), (Px 32))
$helpBack.Idle = $colorIcon
$helpBack.Lit = $colorInk
$helpBack.HoverFill = $colorWell
$helpBack.AccessibleName = 'Back to Help / FAQ'
$helpBack.Visible = $false
$helpBody.Controls.Add($helpBack)

$tileScroll = New-Object Windows.Forms.Panel
$tileScroll.BackColor = $colorCard
$tileScroll.AutoScroll = $true
$tileScroll.Add_HandleCreated({ [WindowTools]::DarkScrollBars($this.Handle) })
$helpBody.Controls.Add($tileScroll)

$pageScroll = New-Object Windows.Forms.Panel
$pageScroll.BackColor = $colorCard
$pageScroll.AutoScroll = $true
$pageScroll.Visible = $false
$pageScroll.Add_HandleCreated({ [WindowTools]::DarkScrollBars($this.Handle) })
$helpBody.Controls.Add($pageScroll)

$pageTitle = New-Object HelpText
$pageTitle.Font = $fontName
$pageTitle.BackColor = $colorCard
$pageTitle.Ink = $colorInk
$pageTitle.Muted = $colorMuted
$pageScroll.Controls.Add($pageTitle)

$pageText = New-Object HelpText
$pageText.Font = $fontHelp
$pageText.BackColor = $colorCard
$pageText.Ink = $colorIcon
$pageText.Muted = $colorMuted
$pageText.ParagraphGap = Px 8
$pageText.EmptyText = 'No text yet'
$pageScroll.Controls.Add($pageText)

$infoSource = Get-Source (Join-Path $iconDir 'info.png')
$crossSource = Get-Source (Join-Path $iconDir 'x.png')
$backSource = Get-Source (Join-Path $iconDir 'arrow-left.png')
if ($infoSource) { $info.SetGlyph($infoSource, (Px 18)) }
if ($crossSource) { $closeHelp.SetGlyph($crossSource, (Px 16)) }
if ($backSource) { $helpBack.SetGlyph($backSource, (Px 18)) }
foreach ($source in @($infoSource, $crossSource, $backSource)) { if ($source) { $source.Dispose() } }

foreach ($section in $helpSections) {
  $tile = New-Object HelpTile
  $tile.Text = $section.Title
  $tile.Font = $fontTile
  $tile.Ink = $colorInk
  $tile.Radius = Px 10
  $tile.Inset = Px 10
  $tile.BackColor = $colorCard
  $tile.AccessibleName = $section.Title
  $tile.Tag = $section
  $tile.Add_Click({ Show-HelpPage $this.Tag })
  $tileScroll.Controls.Add($tile)
  $section.Tile = $tile
}

function Measure-Tiles {
  $rows = [int][Math]::Ceiling($helpSections.Count / 2)
  return (Px 4) + $rows * $tileHeight + [Math]::Max(0, $rows - 1) * $tileGap + (Px 12)
}

function Get-HelpRoom {
  $area = [Windows.Forms.Screen]::FromControl($form).WorkingArea
  $vis = Get-Visible
  if (-not $area.IntersectsWith($vis)) { return @{ Above = [int]::MaxValue; Below = [int]::MaxValue } }
  return @{ Above = $vis.Top - $drawerGap - $area.Top; Below = $area.Bottom - $vis.Bottom - $drawerGap }
}

function Set-PageLayout {
  if (-not $helpState.Page) { return }
  $vis = Get-Visible
  $client = $form.PointToScreen([Drawing.Point]::Empty)
  $left = ($client.X - $vis.Left) + $pad
  $inner = $width - 2 * $pad
  $total = 0
  $titleHeight = 0
  $textHeight = 0
  for ($pass = 0; $pass -lt 2; $pass++) {
    $titleHeight = $pageTitle.MeasureHeight($inner)
    $textHeight = $pageText.MeasureHeight($inner)
    $total = (Px 6) + $titleHeight + (Px 4) + $textHeight + (Px 10)
    if ($pass -eq 0 -and $total -gt $pageScroll.Height) { $inner -= [Windows.Forms.SystemInformation]::VerticalScrollBarWidth } else { break }
  }
  $offset = $pageScroll.AutoScrollPosition.Y
  $pageTitle.Bounds = New-Object Drawing.Rectangle($left, ((Px 6) + $offset), $inner, $titleHeight)
  $pageText.Bounds = New-Object Drawing.Rectangle($left, ((Px 6) + $titleHeight + (Px 4) + $offset), $inner, $textHeight)
  $pageScroll.AutoScrollMinSize = New-Object Drawing.Size(0, $total)
}

function Set-HelpLayout {
  $vis = Get-Visible
  $client = $form.PointToScreen([Drawing.Point]::Empty)
  $caption = $client.Y - $vis.Top
  $edge = $client.X - $vis.Left
  $helpState.Caption = $caption
  $inner = $width - 2 * $pad
  $content = Measure-Tiles
  $room = Get-HelpRoom
  $wanted = [Math]::Min($helpMax, $caption + $content + (Px 10))
  $helpState.Side = if ($room.Above -ge $wanted -or $room.Above -ge $room.Below) { 'above' } else { 'below' }
  $space = if ($helpState.Side -eq 'above') { $room.Above } else { $room.Below }
  $limit = [Math]::Max($caption + (Px 80), [Math]::Min($helpMax, $space))
  $scrollHeight = [Math]::Min($content, $limit - $caption - (Px 10))
  if ($content -gt $scrollHeight) { $inner -= [Windows.Forms.SystemInformation]::VerticalScrollBarWidth }
  $helpState.Full = $caption + $scrollHeight + (Px 10)
  $helpBody.Size = New-Object Drawing.Size($vis.Width, $helpState.Full)
  $closeHelp.Location = New-Object Drawing.Point(($vis.Width - (Px 8) - $closeHelp.Width), [int](($caption - $closeHelp.Height) / 2))
  $helpBack.Location = New-Object Drawing.Point((Px 8), [int](($caption - $helpBack.Height) / 2))
  $area = New-Object Drawing.Rectangle(0, $caption, $vis.Width, $scrollHeight)
  $tileScroll.Bounds = $area
  $pageScroll.Bounds = $area
  $left = $edge + $pad
  $tileWidth = [int][Math]::Floor(($inner - $tileGap) / 2)
  $offset = $tileScroll.AutoScrollPosition.Y
  for ($i = 0; $i -lt $helpSections.Count; $i++) {
    $column = $i % 2
    $row = [int][Math]::Floor($i / 2)
    $helpSections[$i].Tile.Bounds = New-Object Drawing.Rectangle(($left + $column * ($tileWidth + $tileGap)), ((Px 4) + $row * ($tileHeight + $tileGap) + $offset), $tileWidth, $tileHeight)
  }
  $tileScroll.AutoScrollMinSize = New-Object Drawing.Size(0, $content)
  Set-PageLayout
  $helpBody.Invalidate()
}

function Show-HelpPage($section) {
  $helpState.Page = $section
  $pageTitle.SetText([string[]]@($section.Title))
  $pageText.SetText([string[]]$section.Items)
  $pageScroll.AutoScrollPosition = New-Object Drawing.Point(0, 0)
  $pageScroll.Visible = $true
  $helpBack.Visible = $true
  [void]$helpBack.Focus()
  $tileScroll.Visible = $false
  Set-PageLayout
  $helpBody.Invalidate()
}

function Show-HelpTiles {
  $was = $helpState.Page
  $helpState.Page = $null
  $tileScroll.Visible = $true
  if ($was) { [void]$was.Tile.Focus() }
  $pageScroll.Visible = $false
  $helpBack.Visible = $false
  $helpBody.Invalidate()
}

function Set-HelpHeight([int]$value) {
  $value = [Math]::Max([Math]::Max(1, $helpState.Caption), $value)
  $vis = Get-Visible
  if ($helpState.Side -eq 'above') {
    $top = $vis.Top - $drawerGap - $value
    $helpBody.Top = 0
  } else {
    $top = $vis.Bottom + $drawerGap
    $helpBody.Top = $value - $helpState.Full
  }
  $helpDrawer.SetBounds($vis.Left, $top, $vis.Width, $value)
}

$helpSlide = New-Object Windows.Forms.Timer
$helpSlide.Interval = 15
$helpSlide.Add_Tick({
  $progress = [Math]::Min(1.0, ([DateTime]::UtcNow - $helpState.Started).TotalMilliseconds / $slideMilliseconds)
  $ease = 1 - [Math]::Pow(1 - $progress, 3)
  Set-HelpHeight ([int]($helpState.From + ($helpState.To - $helpState.From) * $ease))
  if ($progress -ge 1) {
    $helpSlide.Stop()
    if (-not $helpState.Open) { Hide-HelpDrawer }
  }
})

function Hide-HelpDrawer {
  $helpDrawer.Hide()
  $far = [Windows.Forms.SystemInformation]::VirtualScreen
  $helpDrawer.SetBounds(($far.Right + 4000), ($far.Bottom + 4000), $helpDrawer.Width, $helpState.Caption)
}

function Start-HelpSlide {
  if (-not [Motion]::Enabled) {
    Set-HelpHeight $helpState.To
    if (-not $helpState.Open) { Hide-HelpDrawer }
    return
  }
  $helpState.Started = [DateTime]::UtcNow
  $helpSlide.Start()
}

function Open-Help {
  Show-HelpTiles
  Set-HelpLayout
  $helpState.From = if ($helpDrawer.Visible) { $helpDrawer.Height } else { $helpState.Caption }
  $helpState.To = $helpState.Full
  $helpState.Open = $true
  if (-not $helpDrawer.Visible) {
    Set-HelpHeight $helpState.Caption
    $helpDrawer.Show($form)
    $helpDrawer.Refresh()
  }
  $info.AccessibleName = 'Hide help'
  Start-HelpSlide
}

function Close-Help {
  if (-not $helpDrawer.Visible) { return }
  $helpState.From = $helpDrawer.Height
  $helpState.To = $helpState.Caption
  $helpState.Open = $false
  $info.AccessibleName = 'Show help'
  Start-HelpSlide
}

$info.Add_Click({ if ($helpState.Open) { Close-Help } else { Open-Help } })
$addRow.Add_Click({ if (-not $helpState.Open) { Open-Help } })
$closeHelp.Add_Click({ Close-Help })
$helpBack.Add_Click({ Show-HelpTiles })
$form.Add_Move({ if ($helpDrawer.Visible) { Set-HelpHeight $helpDrawer.Height } })

$baseHeight = $listTop + $listHeight + $bottom
$body.Bounds = New-Object Drawing.Rectangle(0, 0, $width, $baseHeight)
$form.ClientSize = New-Object Drawing.Size($width, $baseHeight)
Move-OldLog
Update-Alerts (Get-LogTail 300 0)

if ($MyInvocation.InvocationName -ne '.') { [Windows.Forms.Application]::Run($form) }
