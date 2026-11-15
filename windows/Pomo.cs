// Pomo for Windows: a small always-on-top overlay pomodoro with a checklist.
// Build:  powershell -ExecutionPolicy Bypass -File build.ps1   (uses the C# compiler that ships with Windows)
// Run:    Pomo.exe  (top-right, above other windows; Esc quits, drag the top area to move the card)
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Text;
using System.Windows.Forms;

static class Pomo {
    // palette, the same as the macOS app
    static readonly Color Bg = Color.FromArgb(17, 17, 19);
    static readonly Color CardColor = Color.FromArgb(34, 34, 38);
    static readonly Color TextColor = Color.FromArgb(239, 239, 239);
    static readonly Color Dim = Color.FromArgb(158, 158, 163);
    static readonly Color Faint = Color.FromArgb(92, 92, 99);
    static readonly Color Orange = Color.FromArgb(238, 140, 71);
    static readonly Color Green = Color.FromArgb(107, 199, 133);

    const int Width = 248, Pad = 14, Rows = 3, RowH = 22, StripY = 10, ClockY = 26, MarkY = 84, StateY = 110, EntryY = 132;
    static readonly int[] Lengths = { 60, 25, 15, 5 };   // P O M O
    static readonly string[] Letters = { "P", "O", "M", "O" };
    const int BreakMin = 5;

    // state (persisted to %APPDATA%\Pomo\settings.txt)
    static int focusMin = 25;
    static DateTime end = DateTime.MinValue;
    static TimeSpan pausedLeft = TimeSpan.Zero;
    static bool pausedWasBreak, running, runningBreak, doneBlock, auto, showStats;
    static DateTime focusStarted = DateTime.MinValue;
    static readonly List<string[]> items = new List<string[]>();   // [text, "1"/"0"]
    static readonly Dictionary<string, int> day = new Dictionary<string, int>(); // pomos, minutes, done

    static Overlay form;

    [STAThread]
    static void Main() {
        bool fresh;
        using (var one = new System.Threading.Mutex(true, "PomoOverlay", out fresh)) {
            if (!fresh) return; // already running: no duplicate overlay
        }
        Application.EnableVisualStyles();
        Load();
        form = new Overlay();
        form.Show();
        var tick = new Timer { Interval = 500 };
        tick.Tick += (s, e) => { EndOfBlock(); form.Invalidate(); };
        tick.Start();
        Application.ThreadException += (s, e) => SaveNow(); // keep running rather than vanish
        Application.Run(form);
        SaveNow(); // final flush on quit, never leaves a half-written state
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
            if (!File.Exists(SettingsPath)) return;
            foreach (string line in File.ReadAllLines(SettingsPath, Encoding.UTF8)) {
                int eq = line.IndexOf('=');
                if (eq <= 0) continue;
                string k = line.Substring(0, eq), v = line.Substring(eq + 1);
                if (k == "focus") { int n; if (int.TryParse(v, out n) && n >= 1 && n <= 999) focusMin = n; }
                else if (k == "auto") auto = v == "1";
                else if (k == "stats") showStats = v == "1";
                else if (k == "paused") { double s; if (double.TryParse(v, out s) && s > 0 && s < 86400) pausedLeft = TimeSpan.FromSeconds(s); }
                else if (k == "pausedBreak") pausedWasBreak = v == "1";
                else if (k == "todo") { string[] p = v.Split('\t'); if (p.Length == 2 && p[0].Trim().Length > 0) items.Add(new[] { p[0], p[1] }); }
                else if (k.StartsWith(DayPrefix)) { int n; if (int.TryParse(v, out n)) day[k.Substring(DayPrefix.Length)] = n; }
            }
        } catch { } // a corrupt save must never stop the app
    }

    static Timer saveTimer; // one pending save at a time: bursts (ticks, clicks) never pile up

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
            sb.AppendLine("auto=" + (auto ? "1" : "0"));
            sb.AppendLine("stats=" + (showStats ? "1" : "0"));
            sb.AppendLine("paused=" + (int)pausedLeft.TotalSeconds);
            sb.AppendLine("pausedBreak=" + (pausedWasBreak ? "1" : "0"));
            foreach (string[] t in items) sb.AppendLine("todo=" + t[0] + "\t" + t[1]);
            foreach (KeyValuePair<string, int> kv in day) sb.AppendLine(DayPrefix + kv.Key + "=" + kv.Value);
            File.WriteAllText(SettingsPath, sb.ToString(), Encoding.UTF8);
        } catch { } // locked or read-only disk: the session keeps working
    }

    static void Bump(string key, int by) {
        int n; day.TryGetValue(key, out n);
        day[key] = n + by;
    }

    // ---------- timer ----------
    static TimeSpan Left { get { return running ? end - DateTime.Now : TimeSpan.Zero; } }

    static void Toggle() {
        if (running) { Pause(); return; }
        runningBreak = pausedLeft > TimeSpan.Zero ? pausedWasBreak : doneBlock;
        running = true;
        end = DateTime.Now + (pausedLeft > TimeSpan.Zero ? pausedLeft : TimeSpan.FromMinutes(runningBreak ? BreakMin : focusMin));
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

    static void Pause() {
        if (!running) return;
        BankFocus();
        pausedLeft = Left > TimeSpan.Zero ? Left : TimeSpan.Zero;
        pausedWasBreak = runningBreak;
        running = false;
        end = DateTime.MinValue;
        Save();
    }

    static void Restart() {
        BankFocus();
        running = false; end = DateTime.MinValue; pausedLeft = TimeSpan.Zero;
        Save();
    }

    static void SetLength(int minutes) {
        if (running) Pause();
        pausedLeft = TimeSpan.Zero;
        if (!doneBlock) focusMin = minutes;
        Save();
    }

    // Runs half a second at a time; fires once when a block reaches zero.
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
            end = DateTime.Now.AddMinutes(wasFocus ? BreakMin : focusMin);
            if (!runningBreak) focusStarted = DateTime.Now;
        }
        Save();
    }

    // ---------- geometry (drawing and clicks share these) ----------
    static int ListTop { get { return EntryY + 22; } }
    static int ListRows { get { return Math.Max(Rows, items.Count); } }
    static int FooterY { get { return ListTop + ListRows * RowH + 6; } }
    static int StatsY { get { return FooterY + 16; } }
    static int WindowHeight { get { return FooterY + (showStats ? 30 : 18); } }

    // ---------- drawing ----------
    static void Paint(Graphics g) {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;
        g.Clear(Bg);

        // 1. time-left strip: fills at the centre, drains toward it as time runs out
        using (var groove = new SolidBrush(Color.FromArgb(38, 255, 255, 255))) g.FillRectangle(groove, Pad, StripY, Width - Pad * 2, 3);
        double total = (runningBreak ? BreakMin : focusMin) * 60.0;
        double frac = running ? Math.Max(0, Math.Min(1, Left.TotalSeconds / total)) : pausedLeft > TimeSpan.Zero ? 0.4 : 1;
        int barW = (int)Math.Round((Width - Pad * 2) * frac);
        if (barW < 1) barW = 1;
        using (var brush = new SolidBrush(runningBreak ? Green : Orange)) g.FillRectangle(brush, Pad + (Width - Pad * 2 - barW) / 2, StripY, barW, 3);

        // 2. clock
        string clock = Fmt(running ? Left : pausedLeft > TimeSpan.Zero ? pausedLeft : TimeSpan.FromMinutes(focusMin));
        using (var font = new Font("Segoe UI Light", 38, GraphicsUnit.Point))
        using (var brush = new SolidBrush(runningBreak ? Green : TextColor)) {
            SizeF sz = g.MeasureString(clock, font);
            g.DrawString(clock, font, brush, (Width - sz.Width) / 2, ClockY);
        }

        // 3. P O M O, each a length; the current one in orange with a tick under it
        int cell = 28, startX = (Width - cell * Letters.Length) / 2;
        int current = doneBlock ? BreakMin : focusMin;
        using (var font = new Font("Segoe UI Semibold", 11, GraphicsUnit.Point)) {
            for (int i = 0; i < Letters.Length; i++) {
                bool on = Lengths[i] == current;
                SizeF sz = g.MeasureString(Letters[i], font);
                float glyphX = startX + i * cell + (cell - sz.Width) / 2; // centre each letter in its cell
                using (var brush = new SolidBrush(on ? Orange : Dim)) g.DrawString(Letters[i], font, brush, glyphX, MarkY);
                if (on) using (var brush = new SolidBrush(Orange)) g.FillRectangle(brush, glyphX + sz.Width / 2 - 5, MarkY + 19, 10, 2); // centred under the letter
            }
        }

        // 4. what it is doing
        string state = running ? (runningBreak ? "break" : "pomo") : pausedLeft > TimeSpan.Zero ? "paused" : doneBlock ? "break ready" : "start";
        if (auto) state += " · auto";
        using (var font = new Font("Segoe UI", 8f, GraphicsUnit.Point))
        using (var brush = new SolidBrush(runningBreak ? Green : running || pausedLeft > TimeSpan.Zero ? Orange : Faint)) {
            SizeF sz = g.MeasureString(state, font);
            g.DrawString(state, font, brush, (Width - sz.Width) / 2, StateY);
        }

        // 5. to-dos; an empty list shows the hint where the first row would be
        using (var font = new Font("Segoe UI", 9f, GraphicsUnit.Point)) {
            if (items.Count == 0) using (var brush = new SolidBrush(Faint)) g.DrawString("Nothing yet", font, brush, Pad + 20, ListTop + 3);
            for (int i = 0; i < items.Count; i++) {
                bool done = items[i][1] == "1";
                int y = ListTop + i * RowH;
                using (var pen = new Pen(done ? Orange : Faint)) g.DrawRectangle(pen, Pad + 2, y + 4, 12, 12);
                using (var brush = new SolidBrush(done ? Dim : TextColor))
                using (var text = new Font("Segoe UI", 9f, done ? FontStyle.Strikeout : FontStyle.Regular, GraphicsUnit.Point))
                    g.DrawString(Fit(items[i][0], g, text, Width - Pad * 2 - 44), text, brush, Pad + 22, y + 3);
            }
        }

        // 6. footer: done count (click = today's numbers) and Clear completed
        using (var font = new Font("Segoe UI", 8f, GraphicsUnit.Point)) {
            int done = 0;
            foreach (string[] t in items) if (t[1] == "1") done++;
            using (var brush = new SolidBrush(Faint)) g.DrawString(done + "/" + items.Count + " done", font, brush, Pad + 2, FooterY);
            if (done > 0) {
                string clear = "Clear completed";
                SizeF sz = g.MeasureString(clear, font);
                using (var brush = new SolidBrush(Dim)) g.DrawString(clear, font, brush, Width - Pad - sz.Width, FooterY);
            }
            if (showStats) {
                int p, m, d;
                day.TryGetValue("pomos", out p); day.TryGetValue("minutes", out m); day.TryGetValue("done", out d);
                if (running && !runningBreak && focusStarted != DateTime.MinValue) m += (int)(DateTime.Now - focusStarted).TotalMinutes;
                string line = p + " pomos · " + (m >= 60 ? m / 60 + "h " + m % 60 + "m" : m + "m") + " focus · " + d + " done";
                SizeF sz = g.MeasureString(line, font);
                using (var brush = new SolidBrush(Faint)) g.DrawString(line, font, brush, (Width - sz.Width) / 2, StatsY);
            }
        }
    }

    static string Fmt(TimeSpan t) {
        int s = Math.Max(0, (int)Math.Ceiling(t.TotalSeconds));
        return (s / 60).ToString("00") + ":" + (s % 60).ToString("00");
    }

    // Truncate with "…" so a long to-do never spills out of the card.
    static string Fit(string s, Graphics g, Font f, int maxWidth) {
        if (g.MeasureString(s, f).Width <= maxWidth) return s;
        while (s.Length > 1 && g.MeasureString(s + "…", f).Width > maxWidth) s = s.Substring(0, s.Length - 1);
        return s + "…";
    }

    // ---------- window ----------
    sealed class Overlay : Form {
        readonly TextBox entry;
        Point dragFrom = Point.Empty; // where the drag started on the card

        public Overlay() {
            FormBorderStyle = FormBorderStyle.None;
            StartPosition = FormStartPosition.Manual;
            TopMost = true;           // the overlay: above normal windows
            ShowInTaskbar = true;     // so it can be found and closed
            BackColor = Bg;
            AutoScaleMode = AutoScaleMode.None;
            MinimumSize = new Size(Width, 200);
            ClientSize = new Size(Width, WindowHeight);
            DoubleBuffered = true;
            ResizeRedraw = true;
            KeyPreview = true;

            entry = new TextBox {
                BorderStyle = BorderStyle.None, BackColor = Bg, ForeColor = TextColor,
                Font = new Font("Segoe UI", 9f), Location = new Point(Pad, EntryY - 2), Width = Width - Pad * 2,
            };
            entry.KeyDown += (s, e) => { if (e.KeyCode == Keys.Enter) { AddTodo(entry.Text); e.SuppressKeyPress = true; } };
            entry.GotFocus += (s, e) => entry.BackColor = CardColor;
            entry.LostFocus += (s, e) => entry.BackColor = Bg;
            Controls.Add(entry);

            // drag by the clock area; auto-scroll off so the window can't shrink past the timer
            MouseDown += (s, e) => { dragFrom = e.Y < MarkY - 4 ? e.Location : Point.Empty; }; // only the clock area drags
            MouseMove += (s, e) => { if (dragFrom != Point.Empty) { Left += e.X - dragFrom.X; Top += e.Y - dragFrom.Y; } };
            MouseUp += (s, e) => dragFrom = Point.Empty; // a click (no movement) still reaches ClickAt
            Click += (s, e) => ClickAt(e.Location);
            KeyDown += (s, e) => { if (e.KeyCode == Keys.Escape) Application.Exit(); };
            FormClosing += (s, e) => SaveNow(); // the last click is always on disk

            PlaceTopRight();
        }

        void PlaceTopRight() {
            Screen s = Screen.FromPoint(Cursor.Position);
            Left = s.WorkingArea.Right - Width - 12;
            Top = s.WorkingArea.Top + 12;
        }

        public void Relayout() {
            int h = WindowHeight;
            if (Height != h) Height = h;   // grows downwards from a fixed top edge
            entry.Top = EntryY - 2;
        }

        protected override void OnPaint(PaintEventArgs e) {
            Relayout();
            Pomo.Paint(e.Graphics);
        }

        void ClickAt(Point p) {
            int startX = (Width - 4 * 28) / 2;
            if (p.Y >= MarkY - 2 && p.Y <= MarkY + 22 && p.X >= startX && p.X < startX + 4 * 28) {
                SetLength(Lengths[(p.X - startX) / 28]);
                return;
            }
            if (p.Y < MarkY - 4) { Toggle(); return; }                       // clock: start / pause / resume
            int row = (p.Y - ListTop) / RowH;
            if (row >= 0 && row < items.Count && p.Y >= ListTop) {
                if (p.X > Width - 36) items.RemoveAt(row);                     // right edge: delete
                else { // tick counts toward today; unticking does not
                    if (items[row][1] != "1") { items[row][1] = "1"; Bump("done", 1); }
                    else items[row][1] = "0";
                }
                Save();
                Invalidate();
                return;
            }
            if (p.Y >= FooterY - 4) {
                int done = 0;
                foreach (string[] t in items) if (t[1] == "1") done++;
                if (p.X > Width - 120 && done > 0) { ClearDone(); return; }
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

    static void ClearDone() {
        items.RemoveAll(t => t[1] == "1");
        Save();
        form.Invalidate();
    }
}
