// Pomo for Windows: a small always-on-top overlay pomodoro with a checklist.
// Build:  powershell -ExecutionPolicy Bypass -File build.ps1   (uses the C# compiler that ships with Windows)
// Run:    Pomo.exe  (top-right, above other windows)
//   right-click / tray icon: menu (themes, stats, show/hide, quit)   Esc: quit   drag the clock area: move
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Text;
using System.Windows.Forms;

struct Palette {
    public string Name;
    public Color Bg;      // top tone
    public Color Bg2;     // second tone for dual-tone themes (unused when equal to Bg)
    public Color Card;
    public Color Accent;  // running clock, strip, active letter
    public Color BreakC;  // the break countdown
    public Color Text;
    public Color Dim;
    public Color Faint;
    public bool Dual { get { return Bg2.ToArgb() != Bg.ToArgb(); } }
}

static class Pomo {
    const int Width = 248, RowH = 22, Rows = 3;
    const int Pad = 14, StripY = 10, ClockY = 22, MarkY = 84, StateY = 110, EntryY = 134;
    static readonly int[] Lengths = { 60, 25, 15, 5 };   // P O M O
    static readonly string[] Letters = { "P", "O", "M", "O" };
    const int BreakMin = 5;

    // ---------- themes: the same palettes as the macOS app ----------
    static readonly List<Palette> Themes = new List<Palette> {
        P("Ember", "#111113", "#111113", "#F28C47", "#6BC785"),
        P("Slate", "#1A1A1C", "#8AB8FA", "#72CCB7"),
        P("Forest", "#121A17", "#73D19E", "#9EDA80"),
        P("Sakura", "#171217", "#F28CB7", "#99D9B8"),
        P("Paper", "#F2F2F2", "#D93433", "#40946A"),
        P("Dusk", "#1A142E", "#42201F", "#FF9E6B", "#8CD9CC"),
        P("Moss", "#0D1F1A", "#29210F", "#D9C766", "#8CE699"),
        P("Lagoon", "#0A1A29", "#0F383D", "#59D9E6", "#80F2B3"),
    };
    static Palette Current = Themes[0];
    static string ThemeName = "ember";   // a preset slug, or "custom"
    static Palette Custom;               // the user's own combination

    // builds a palette: bg, accent, break; card/dim/faint/text are derived so any combination stays readable
    static Palette P(string name, string bg, string accent, string brk) { return P(name, bg, bg, accent, brk, null, null); }
    static Palette P(string name, string bg, string bg2, string accent, string brk, string text, string card) {
        Color b = Hex(bg), a = Hex(accent), g = Hex(brk);
        bool light = Luma(b) > 0.6;
        Color t = text != null ? Hex(text) : (light ? Color.FromArgb(31, 31, 31) : Color.FromArgb(239, 239, 239));
        return new Palette {
            Name = name, Bg = b, Bg2 = Hex(bg2), Accent = a, BreakC = g, Text = t,
            Card = card != null ? Hex(card) : Mix(b, light ? Color.Black : Color.White, 0.14),
            Dim = Mix(t, b, light ? 0.45 : 0.36),
            Faint = Mix(t, b, light ? 0.62 : 0.6),
        };
    }

    // ---------- state (persisted to %APPDATA%\Pomo\settings.txt) ----------
    static int focusMin = 25, breakMin = BreakMin;
    static DateTime end = DateTime.MinValue;
    static TimeSpan pausedLeft = TimeSpan.Zero;
    static bool pausedWasBreak, running, runningBreak, doneBlock, auto, showStats;
    static DateTime focusStarted = DateTime.MinValue;
    static readonly List<string[]> items = new List<string[]>(); // [text, "1"/"0"]
    static readonly Dictionary<string, int> day = new Dictionary<string, int>();

    static Overlay form;
    static NotifyIcon tray;

    [STAThread]
    static void Main() {
        bool fresh;
        using (var one = new System.Threading.Mutex(true, "PomoOverlay", out fresh)) {
            if (!fresh) return; // already running: no duplicate overlay
        }
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Load();
        form = new Overlay();
        tray = new NotifyIcon { Icon = MakeIcon(), Visible = true, Text = "Pomo" };
        tray.ContextMenuStrip = BuildMenu();
        tray.MouseClick += (s, e) => { if (e.Button == MouseButtons.Left) ToggleWindow(); };
        form.Show();
        var tick = new Timer { Interval = 500 };
        tick.Tick += (s, e) => {
            EndOfBlock();
            form.Invalidate();
            string title = running ? "Pomo · " + (runningBreak ? "break " : "focus ") + Fmt(Left)
                                   : pausedLeft > TimeSpan.Zero ? "Pomo · paused " + Fmt(pausedLeft)
                                   : "Pomo · " + CurrentMin + " min";
            if (tray.Text != title) tray.Text = title.Length > 63 ? title.Substring(0, 63) : title; // the shell caps tooltips at 63
        };
        tick.Start();
        Application.ThreadException += (s, e) => SaveNow();
        Application.Run(form);
        SaveNow();
    }

    static void ToggleWindow() {
        if (form.Visible) form.Hide(); else { form.Show(); form.Activate(); }
    }

    // ---------- persistence ----------
    static string SettingsPath {
        get {
            string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Pomo");
            Directory.CreateDirectory(dir);
            return Path.Combine(dir, "settings.txt");
        }
    }
    static string DayPrefix { get { return "day." + DateTime.Today.ToString("yyyyMMdd") + "."; } }

    static void Load() {
        try {
            ThemeName = "ember";
            if (!File.Exists(SettingsPath)) { ApplyTheme("ember"); return; }
            foreach (string line in File.ReadAllLines(SettingsPath, Encoding.UTF8)) {
                int eq = line.IndexOf('=');
                if (eq <= 0) continue;
                string k = line.Substring(0, eq), v = line.Substring(eq + 1);
                if (k == "focus") { int n; if (int.TryParse(v, out n) && n >= 1 && n <= 999) focusMin = n; }
                else if (k == "break") { int n; if (int.TryParse(v, out n) && n >= 1 && n <= 60) breakMin = n; }
                else if (k == "auto") auto = v == "1";
                else if (k == "stats") showStats = v == "1";
                else if (k == "paused") { double s; if (double.TryParse(v, out s) && s > 0 && s < 86400) pausedLeft = TimeSpan.FromSeconds(s); }
                else if (k == "pausedBreak") pausedWasBreak = v == "1";
                else if (k == "todo") { string[] p = v.Split('\t'); if (p.Length == 2 && p[0].Trim().Length > 0) items.Add(new[] { p[0], p[1] }); }
                else if (k == "theme") ThemeName = v;
                else if (k == "customTheme") Custom = ParseCustom(v);
                else if (k.StartsWith(DayPrefix)) { int n; if (int.TryParse(v, out n)) day[k.Substring(DayPrefix.Length)] = n; }
            }
            ApplyTheme(ThemeName);
        } catch { } // corrupt saves must never stop the app
    }

    static Palette ParseCustom(string line) {
        string[] parts = line.Split(',');
        if (parts.Length < 6) return Themes[0];
        return P("Custom", parts[0], parts[5], parts[2], parts[3], parts[4], parts[1]);
    }

    static Timer saveTimer;
    static void Save() {
        if (saveTimer == null) {
            saveTimer = new Timer { Interval = 400 };
            saveTimer.Tick += (s, e) => { saveTimer.Stop(); SaveNow(); };
        }
        saveTimer.Stop();
        saveTimer.Start();
    }

    static void SaveNow() {
        try {
            var sb = new StringBuilder();
            sb.AppendLine("focus=" + focusMin);
            sb.AppendLine("break=" + breakMin);
            sb.AppendLine("auto=" + (auto ? "1" : "0"));
            sb.AppendLine("stats=" + (showStats ? "1" : "0"));
            sb.AppendLine("paused=" + (int)pausedLeft.TotalSeconds);
            sb.AppendLine("pausedBreak=" + (pausedWasBreak ? "1" : "0"));
            sb.AppendLine("theme=" + ThemeName);
            if (ThemeName == "custom" && Custom.Name != null) {
                sb.AppendLine("customTheme=" + Hx(Custom.Bg) + "," + Hx(Custom.Card) + "," + Hx(Custom.Accent) + ","
                              + Hx(Custom.BreakC) + "," + Hx(Custom.Text) + "," + Hx(Custom.Bg2));
            }
            foreach (string[] t in items) sb.AppendLine("todo=" + t[0].Replace('\t', ' ').Replace('\r', ' ').Replace('\n', ' ') + "\t" + t[1]);
            foreach (KeyValuePair<string, int> kv in day) sb.AppendLine(DayPrefix + kv.Key + "=" + kv.Value);
            File.WriteAllText(SettingsPath, sb.ToString(), Encoding.UTF8);
        } catch { } // locked disk: the session keeps working
    }

    static void Bump(string key, int by) {
        int n; day.TryGetValue(key, out n);
        day[key] = n + by;
    }

    // ---------- themes ----------
    static void ApplyTheme(string name) {
        ThemeName = (name ?? "ember").ToLowerInvariant();
        if (ThemeName == "custom" && Custom.Name != null) Current = Custom;
        else {
            ThemeName = ThemeName == "custom" ? "ember" : ThemeName;
            Current = Themes.Find(t => t.Name.ToLowerInvariant() == ThemeName) ?? Themes[0];
            ThemeName = Current.Name.ToLowerInvariant();
        }
        if (form != null) form.Invalidate();
    }

    static Color Hex(string hex) {
        string h = hex.TrimStart('#');
        if (h.Length == 3) h = string.Concat(h[0], h[0], h[1], h[1], h[2], h[2]);
        int n = int.Parse(h, System.Globalization.NumberStyles.HexNumber);
        return Color.FromArgb((n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF);
    }
    static string Hx(Color c) { return "#" + c.R.ToString("X2") + c.G.ToString("X2") + c.B.ToString("X2"); }
    static Color Mix(Color a, Color b, double k) {
        return Color.FromArgb((int)(a.R + (b.R - a.R) * k), (int)(a.G + (b.G - a.G) * k), (int)(a.B + (b.B - a.B) * k));
    }
    static double Luma(Color c) { return (0.299 * c.R + 0.587 * c.G + 0.114 * c.B) / 255.0; }

    // small orange clock, drawn so the exe needs no icon file
    static Icon MakeIcon() {
        using (var bmp = new Bitmap(32, 32)) using (var g = Graphics.FromImage(bmp)) {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.Clear(Color.Transparent);
            g.FillEllipse(new SolidBrush(ColorTranslator.FromHtml("#EE8C47")), 1, 1, 30, 30);
            using (var pen = new Pen(Color.FromArgb(20, 20, 22), 3)) {
                g.DrawEllipse(pen, 7, 7, 18, 18);
                g.DrawLine(pen, 16, 16, 16, 10);
                g.DrawLine(pen, 16, 16, 20, 18);
            }
            return Icon.FromHandle(bmp.GetHicon());
        }
    }

    // ---------- timer ----------
    static TimeSpan Left { get { return running ? end - DateTime.Now : TimeSpan.Zero; } }
    static int CurrentMin {
        get { return doneBlock || runningBreak ? Math.Max(1, breakMin) : focusMin; }
    }

    // One start/pause/resume path for the clock, the tray and Space.
    static void StartOrPause() {
        if (running) { BankFocus(); pausedLeft = Left > TimeSpan.Zero ? Left : TimeSpan.Zero; pausedWasBreak = runningBreak; running = false; end = DateTime.MinValue; Save(); return; }
        runningBreak = pausedLeft > TimeSpan.Zero ? pausedWasBreak : doneBlock;
        running = true;
        end = DateTime.Now + (pausedLeft > TimeSpan.Zero ? pausedLeft : TimeSpan.FromMinutes(runningBreak ? Math.Max(1, breakMin) : focusMin));
        pausedLeft = TimeSpan.Zero;
        if (!runningBreak) focusStarted = DateTime.Now;
        Save();
    }

    static void BankFocus() {
        if (runningBreak || focusStarted == DateTime.MinValue) return;
        int mins = (int)(DateTime.Now - focusStarted).TotalMinutes;
        if (mins > 0) Bump("minutes", mins);
        focusStarted = DateTime.MinValue;
    }

    static void Restart() { BankFocus(); running = false; end = DateTime.MinValue; pausedLeft = TimeSpan.Zero; Save(); }

    // Set the length: the focus time, or the break length while a break is next/running.
    static void SetLength(int minutes) {
        if (running) StartOrPause(); // pausing first, like the mac card
        pausedLeft = TimeSpan.Zero;
        if (doneBlock || runningBreak) breakMin = Math.Max(1, Math.Min(60, minutes));
        else focusMin = Math.Max(1, Math.Min(999, minutes));
        Save();
        if (form != null) form.Invalidate();
    }

    // ↑ / ↓ on the clock: one minute at a time, on whichever length is next.
    static void Nudge(int by) { SetLength(CurrentMin + by); if (form != null) form.Invalidate(); }

    static void EndOfBlock() {
        if (!running || end > DateTime.Now) return;
        running = false;
        bool wasFocus = !runningBreak;
        doneBlock = wasFocus;
        if (wasFocus) {
            Bump("pomos", 1);
            if (focusStarted != DateTime.MinValue) {
                int mins = (int)(DateTime.Now - focusStarted).TotalMinutes;
                if (mins > 0) Bump("minutes", mins);
            }
            focusStarted = DateTime.MinValue;
        }
        System.Media.SystemSounds.Asterisk.Play();
        if (auto) {
            running = true;
            runningBreak = wasFocus;
            end = DateTime.Now.AddMinutes(wasFocus ? Math.Max(1, breakMin) : focusMin);
            if (!runningBreak) focusStarted = DateTime.Now;
        }
        Save();
    }

    // ---------- menu ----------
    static ContextMenuStrip BuildMenu() {
        var menu = new ContextMenuStrip();
        menu.Items.Add(new ToolStripMenuItem("Show / hide Pomo", null, (s, e) => ToggleWindow()));
        menu.Items.Add(new ToolStripMenuItem("Start / pause", null, (s, e) => { StartOrPause(); if (form != null) form.Invalidate(); }));
        var themes = new ToolStripMenuItem("Theme");
        foreach (Palette t in Themes) {
            Palette copy = t;
            var mi = new ToolStripMenuItem(t.Name + (t.Dual ? "  · dual" : ""));
            mi.Image = Swatch(copy);
            mi.Click += (s, e) => ApplyTheme(copy.Name);
            themes.DropDownItems.Add(mi);
        }
        themes.DropDownItems.Add(new ToolStripSeparator());
        themes.DropDownItems.Add(new ToolStripMenuItem("Custom…", null, (s, e) => CustomThemeDialog()));
        menu.Items.Add(themes);
        var rhythm = new ToolStripMenuItem("Automatic rhythm") { CheckOnClick = true, Checked = auto };
        rhythm.Click += (s, e) => { auto = rhythm.Checked; Save(); };
        menu.Items.Add(rhythm);
        menu.Items.Add(new ToolStripMenuItem("Reset today's stats…", null, (s, e) => ResetStats()));
        menu.Items.Add(new ToolStripMenuItem("Quit", null, (s, e) => { SaveNow(); Application.Exit(); }));
        menu.ShowImageMargin = true;
        return menu;
    }

    static void ResetStats() {
        if (MessageBox.Show("Reset today's stats?", "Pomo", MessageBoxButtons.YesNo, MessageBoxIcon.Question) == DialogResult.Yes) {
            day.Clear();
            focusStarted = running && !runningBreak ? DateTime.Now : DateTime.MinValue;
            SaveNow();
            if (form != null) form.Invalidate();
        }
    }

    // 16px preview: the two tones as halves, accent and break dots
    static Image Swatch(Palette p) {
        var bmp = new Bitmap(16, 16);
        using (var g = Graphics.FromImage(bmp)) {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.FillEllipse(new SolidBrush(p.Bg2), 1, 1, 14, 14);
            g.FillPie(new SolidBrush(p.Bg), 1, 1, 14, 14, 180, 180);
            g.FillEllipse(new SolidBrush(p.Accent), 4, 8, 6, 6);
            g.FillEllipse(new SolidBrush(p.BreakC), 9, 3, 4, 4);
        }
        return bmp;
    }

    // Custom: top, bottom, card, accent, break, text
    static void CustomThemeDialog() {
        using (var dlg = new Form { Text = "Custom theme", FormBorderStyle = FormBorderStyle.FixedDialog, MinimizeBox = false, MaximizeBox = false, StartPosition = FormStartPosition.CenterScreen, BackColor = Color.FromArgb(28, 28, 30), Width = 340, Height = 190 }) {
            string[] labels = { "Top", "Bottom", "Card", "Accent", "Break", "Text" };
            Color[] start = Current.Dual ? new[] { Current.Bg, Current.Bg2, Current.Card, Current.Accent, Current.BreakC, Current.Text }
                                        : new[] { Current.Bg, Current.Bg, Current.Card, Current.Accent, Current.BreakC, Current.Text };
            var wells = new ColorDialog[6];
            for (int i = 0; i < 6; i++) {
                int col = i % 3, row = i / 3;
                var btn = new Button { Text = labels[i], Left = 14 + col * 106, Top = 14 + row * 64, Width = 96, Height = 34, BackColor = start[i], ForeColor = Luma(start[i]) > 0.55 ? Color.Black : Color.White, FlatStyle = FlatStyle.Flat };
                int idx = i;
                wells[i] = new ColorDialog { Color = start[i], FullOpen = true };
                btn.Click += (s, e) => { wells[idx].Color = start[idx]; if (wells[idx].ShowDialog(dlg) == DialogResult.OK) { start[idx] = wells[idx].Color; btn.BackColor = start[idx]; btn.ForeColor = Luma(start[idx]) > 0.55 ? Color.Black : Color.White; } };
                dlg.Controls.Add(btn);
            }
            var ok = new Button { Text = "Apply", DialogResult = DialogResult.OK, Left = 14, Top = 140, Width = 96, BackColor = Color.FromArgb(238, 140, 71), FlatStyle = FlatStyle.Flat, ForeColor = Color.White };
            var cancel = new Button { Text = "Cancel", DialogResult = DialogResult.Cancel, Left = 118, Top = 140, Width = 96 };
            dlg.Controls.Add(ok);
            dlg.Controls.Add(cancel);
            dlg.AcceptButton = ok;
            dlg.CancelButton = cancel;
            if (dlg.ShowDialog(form) == DialogResult.OK) {
                Custom = P("Custom", Hx(start[0]), Hx(start[1]), Hx(start[3]), Hx(start[4]), Hx(start[5]), Hx(start[2]));
                ApplyTheme("custom");
                SaveNow();
            }
        }
    }

    // ---------- drawing ----------
    static bool showChevrons;

    static void Paint(Graphics g, int w, int h) {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;
        g.Clear(Current.Card);
        PaintBackdrop(g, w, h);

        // 1. time-left strip: drains toward the centre, green on breaks
        using (var groove = new SolidBrush(Mix(Current.Text, Current.Bg, 0.85))) g.FillRectangle(groove, Pad, StripY, w - Pad * 2, 3);
        double total = Math.Max(1, CurrentMin) * 60.0;
        double frac = running ? Math.Max(0, Math.Min(1, Left.TotalSeconds / total)) : pausedLeft > TimeSpan.Zero ? 0.4 : 1;
        int barW = Math.Max(1, (int)Math.Round((w - Pad * 2) * frac));
        using (var bar = new SolidBrush(runningBreak ? Current.BreakC : Current.Accent))
            g.FillRectangle(bar, Pad + (w - Pad * 2 - barW) / 2, StripY, barW, 3);

        // 2. clock, with the minute chevrons beside it while the pointer is over it
        if (showChevrons) {
            using (var font = new Font("Segoe UI Semibold", 9, GraphicsUnit.Point))
            using (var brush = new SolidBrush(Current.Dim)) {
                g.DrawString("▲", font, brush, 8, ClockY + 30);
                g.DrawString("▼", font, brush, w - 22, ClockY + 30);
            }
        }
        string clock = running ? Fmt(Left) : pausedLeft > TimeSpan.Zero ? Fmt(pausedLeft) : Fmt(TimeSpan.FromMinutes(CurrentMin));
        using (var font = new Font("Segoe UI Light", 38, GraphicsUnit.Point))
        using (var brush = new SolidBrush(runningBreak ? Current.BreakC : Current.Text)) {
            SizeF sz = g.MeasureString(clock, font);
            g.DrawString(clock, font, brush, (w - sz.Width) / 2, ClockY);
        }

        // 3. P O M O: the current length in the accent with a rule under it
        int cell = 28, startX = (w - cell * Letters.Length) / 2, current = CurrentMin;
        using (var font = new Font("Segoe UI Semibold", 11, GraphicsUnit.Point)) {
            for (int i = 0; i < Letters.Length; i++) {
                bool on = Lengths[i] == current;
                SizeF sz = g.MeasureString(Letters[i], font);
                float gx = startX + i * cell + (cell - sz.Width) / 2;
                using (var brush = new SolidBrush(on ? Current.Accent : Current.Dim)) g.DrawString(Letters[i], font, brush, gx, MarkY);
                if (on) using (var brush = new SolidBrush(Current.Accent)) g.FillRectangle(brush, gx + sz.Width / 2 - 5, MarkY + 19, 10, 2);
            }
        }

        // 4. state word
        string state = running ? (runningBreak ? "break" : "pomo") : pausedLeft > TimeSpan.Zero ? "paused" : doneBlock ? "break ready" : "start";
        if (auto) state += " · auto";
        using (var font = new Font("Segoe UI", 8f, GraphicsUnit.Point))
        using (var brush = new SolidBrush(runningBreak ? Current.BreakC : running || pausedLeft > TimeSpan.Zero ? Current.Accent : Current.Faint)) {
            SizeF sz = g.MeasureString(state, font);
            g.DrawString(state, font, brush, (w - sz.Width) / 2, StateY);
        }

        // 5. to-dos
        using (var font = new Font("Segoe UI", 9f, GraphicsUnit.Point)) {
            if (items.Count == 0) using (var brush = new SolidBrush(Current.Faint)) g.DrawString("Nothing yet", font, brush, Pad + 20, ListTop + 3);
            for (int i = 0; i < items.Count; i++) {
                bool done = items[i][1] == "1";
                int y = ListTop + i * RowH;
                using (var pen = new Pen(done ? Current.Accent : Current.Faint)) g.DrawRectangle(pen, Pad + 2, y + 4, 12, 12);
                using (var brush = new SolidBrush(done ? Current.Dim : Current.Text))
                using (var text = new Font("Segoe UI", 9f, done ? FontStyle.Strikeout : FontStyle.Regular, GraphicsUnit.Point))
                    g.DrawString(Fit(items[i][0], g, text, w - Pad * 2 - 44), text, brush, Pad + 22, y + 3);
            }
        }

        // 6. footer: done count (click = stats) and Clear completed
        using (var font = new Font("Segoe UI", 8f, GraphicsUnit.Point)) {
            int done = 0;
            foreach (string[] t in items) if (t[1] == "1") done++;
            using (var brush = new SolidBrush(Current.Faint)) g.DrawString(done + "/" + items.Count + " done", font, brush, Pad + 2, FooterY);
            if (done > 0) {
                string clear = "Clear completed";
                SizeF sz = g.MeasureString(clear, font);
                using (var brush = new SolidBrush(Current.Dim)) g.DrawString(clear, font, brush, w - Pad - sz.Width, FooterY);
            }
            if (showStats) {
                int p, m, d;
                day.TryGetValue("pomos", out p); day.TryGetValue("minutes", out m); day.TryGetValue("done", out d);
                if (running && !runningBreak && focusStarted != DateTime.MinValue) m += (int)(DateTime.Now - focusStarted).TotalMinutes;
                string line = p + " pomos · " + (m >= 60 ? m / 60 + "h " + m % 60 + "m" : m + "m") + " focus · " + d + " done";
                SizeF sz = g.MeasureString(line, font);
                using (var brush = new SolidBrush(Current.Faint)) g.DrawString(line, font, brush, (w - sz.Width) / 2, StatsY);
            }
        }
    }

    // Solid card, or the two-tone fade of a dual palette
    static void PaintBackdrop(Graphics g, int w, int h) {
        if (!Current.Dual) return;
        using (var lg = new LinearGradientBrush(new Rectangle(0, 0, w, h), Current.Bg, Current.Bg2, LinearGradientMode.Vertical)) {
            using (var blend = new Blend()) { blend.Factors = new[] { 0f, 0.35f, 1f }; blend.Positions = new[] { 0f, 0.55f, 1f }; lg.Blend = blend; }
            g.FillRectangle(lg, 0, 0, w, h);
        }
    }

    static int ListTop { get { return EntryY + 22; } }
    static int ListRows { get { return Math.Max(Rows, items.Count); } }
    static int FooterY { get { return ListTop + ListRows * RowH + 6; } }
    static int StatsY { get { return FooterY + 16; } }
    static int WindowHeight { get { return FooterY + (showStats ? 30 : 18); } }

    static string Fmt(TimeSpan t) {
        int s = Math.Max(0, (int)Math.Ceiling(t.TotalSeconds));
        return (s / 60).ToString("00") + ":" + (s % 60).ToString("00");
    }
    static string Fit(string s, Graphics g, Font f, int maxWidth) {
        if (g.MeasureString(s, f).Width <= maxWidth) return s;
        while (s.Length > 1 && g.MeasureString(s + "…", f).Width > maxWidth) s = s.Substring(0, s.Length - 1);
        return s + "…";
    }

    // ---------- window ----------
    sealed class Overlay : Form {
        readonly TextBox entry;
        Point dragFrom = Point.Empty;
        bool hovering;

        public Overlay() {
            FormBorderStyle = FormBorderStyle.None;
            StartPosition = FormStartPosition.Manual;
            TopMost = true;
            ShowInTaskbar = true;
            AutoScaleMode = AutoScaleMode.None;
            MinimumSize = new Size(Width, 200);
            ClientSize = new Size(Width, WindowHeight);
            DoubleBuffered = true;
            ResizeRedraw = true;
            KeyPreview = true;

            entry = new TextBox {
                BorderStyle = BorderStyle.None, BackColor = Current.Card, ForeColor = Current.Text,
                Font = new Font("Segoe UI", 9f), Location = new Point(Pad, EntryY - 2), Width = Width - Pad * 2,
            };
            entry.KeyDown += (s, e) => { if (e.KeyCode == Keys.Enter) { AddTodo(entry.Text); e.SuppressKeyPress = true; } };
            Controls.Add(entry);

            // drag by the clock area; the caret lives in the field, so the two don't fight
            MouseMove += (s, e) => { int band = ClockY + 40; if (e.Y > band - 12 && e.Y < band + 20) hovering = true; else if (hovering) { hovering = false; Invalidate(); } };
            MouseLeave += (s, e) => { hovering = false; Invalidate(); };
            MouseDown += (s, e) => { if (e.Y < MarkY - 4) dragFrom = e.Location; };
            MouseMove += (s, e) => { if (dragFrom != Point.Empty) { Left += e.X - dragFrom.X; Top += e.Y - dragFrom.Y; } };
            MouseUp += (s, e) => dragFrom = Point.Empty;
            MouseClick += (s, e) => ClickAt(e.Location);
            KeyDown += (s, e) => OnKey(e);
            FormClosing += (s, e) => SaveNow();
            PlaceTopRight();
        }

        void PlaceTopRight() {
            Screen s = Screen.FromPoint(Cursor.Position);
            Left = s.WorkingArea.Right - Width - 12;
            Top = s.WorkingArea.Top + 12;
        }

        public void Relayout() {
            int h = WindowHeight;
            if (Height != h) Height = h;
            entry.Top = EntryY - 2;
            if (entry.BackColor != Current.Card) entry.BackColor = Current.Card;
            if (entry.ForeColor != Current.Text) entry.ForeColor = Current.Text;
        }

        protected override void OnPaint(PaintEventArgs e) {
            try {
                Relayout();
                showChevrons = hovering;
                Paint(e.Graphics, ClientSize.Width, ClientSize.Height);
            } catch { } // a drawing slip shows a blank card for a frame instead of killing the timer
        }

        // Arrow keys: ←/→ pick a length, ↑/↓ nudge by a minute
        void OnKey(KeyEventArgs e) {
            if (e.KeyCode == Keys.Escape) { if (tray != null) tray.Visible = false; Application.Exit(); return; }
            if (e.KeyCode == Keys.Space) { StartOrPause(); Invalidate(); e.Handled = true; return; }
            if (e.KeyCode == Keys.Up) { Nudge(1); e.Handled = true; }
            else if (e.KeyCode == Keys.Down) { Nudge(-1); e.Handled = true; }
            else if (e.KeyCode == Keys.Left) { SetLength(Lengths[Math.Max(0, Array.IndexOf(Lengths, CurrentMin) - 1)]); e.Handled = true; }
            else if (e.KeyCode == Keys.Right) { SetLength(Lengths[Math.Min(Lengths.Length - 1, Array.IndexOf(Lengths, CurrentMin) + 1)]); e.Handled = true; }
        }

        void ClickAt(Point p) {
            int startX = (Width - 4 * 28) / 2;
            if (p.Y >= MarkY - 2 && p.Y <= MarkY + 22 && p.X >= startX && p.X < startX + 4 * 28) {
                SetLength(Lengths[(p.X - startX) / 28]);
                return;
            }
            if (p.Y > ClockY + 14 && p.Y < ClockY + 62 && (p.X < 30 || p.X > Width - 30)) { Nudge(p.X < 30 ? -1 : 1); return; } // hover chevrons
            if (p.Y < MarkY - 4) { StartOrPause(); return; } // clock: start / pause / resume
            int row = (p.Y - ListTop) / RowH;
            if (row >= 0 && row < items.Count && p.Y >= ListTop) {
                if (p.X > Width - 36) items.RemoveAt(row);
                else { if (items[row][1] != "1") { items[row][1] = "1"; Bump("done", 1); } else items[row][1] = "0"; }
                Save();
                Invalidate();
                return;
            }
            if (p.Y >= FooterY - 4) {
                int done = 0;
                foreach (string[] t in items) if (t[1] == "1") done++;
                if (p.X > Width - 120 && done > 0) { items.RemoveAll(t => t[1] == "1"); Save(); Invalidate(); return; }
                if (p.X < 70) { showStats = !showStats; Save(); Invalidate(); }
            }
        }
    }

    static void AddTodo(string raw) {
        string text = (raw ?? "").Trim();
        form.Controls[0].Text = "";
        if (text.Length == 0) return;
        items.Add(new[] { text.Length > 200 ? text.Substring(0, 200) : text, "0" });
        Save();
        form.Invalidate();
    }
}
