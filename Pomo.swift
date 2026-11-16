// Pomo: always-on-top pomodoro + checklist. Build/run: ./build.sh
import AppKit

// The palette, switchable at runtime: presets or a custom look (see C.apply).
struct Palette {
    var name = "Ember"
    var bg = NSColor(white: 0.065, alpha: 1)
    var bg2: NSColor? // set on dual-tone themes: the card fades from bg (top) to bg2 (bottom)
    var card = NSColor(white: 0.14, alpha: 1)
    var control = NSColor(white: 0.2, alpha: 1)
    var accent = NSColor(red: 0.95, green: 0.55, blue: 0.28, alpha: 1) // runs, strip, the active letter
    var green = NSColor(red: 0.42, green: 0.78, blue: 0.52, alpha: 1) // breaks
    var text = NSColor(white: 0.94, alpha: 1)
    var dim = NSColor(white: 0.62, alpha: 1)
    var faint = NSColor(white: 0.38, alpha: 1)
}

enum C {
    static var theme = Palette()
    static var bg: NSColor { theme.bg }
    static var card: NSColor { theme.card }
    static var control: NSColor { theme.control }
    static var accent: NSColor { theme.accent }
    static var green: NSColor { theme.green }
    static var text: NSColor { theme.text }
    static var dim: NSColor { theme.dim }
    static var faint: NSColor { theme.faint }
    static let hairline = NSColor(white: 1, alpha: 0.08)
    static let row = 24.0 // to-do row height
    static let width = 236.0

    static let presets: [Palette] = [
        Palette(), // Ember: the original warm orange on near-black
        Palette(name: "Slate", bg: NSColor(white: 0.10, alpha: 1), card: NSColor(white: 0.17, alpha: 1), control: NSColor(white: 0.23, alpha: 1),
                accent: NSColor(srgbRed: 0.55, green: 0.72, blue: 0.98, alpha: 1), green: NSColor(srgbRed: 0.45, green: 0.8, blue: 0.72, alpha: 1)),
        Palette(name: "Forest", bg: NSColor(srgbRed: 0.07, green: 0.10, blue: 0.09, alpha: 1), card: NSColor(srgbRed: 0.12, green: 0.16, blue: 0.14, alpha: 1),
                control: NSColor(srgbRed: 0.17, green: 0.22, blue: 0.19, alpha: 1),
                accent: NSColor(srgbRed: 0.45, green: 0.82, blue: 0.62, alpha: 1), green: NSColor(srgbRed: 0.62, green: 0.85, blue: 0.5, alpha: 1)),
        Palette(name: "Sakura", bg: NSColor(srgbRed: 0.09, green: 0.07, blue: 0.09, alpha: 1), card: NSColor(srgbRed: 0.15, green: 0.12, blue: 0.15, alpha: 1),
                control: NSColor(srgbRed: 0.22, green: 0.17, blue: 0.22, alpha: 1),
                accent: NSColor(srgbRed: 0.95, green: 0.55, blue: 0.72, alpha: 1), green: NSColor(srgbRed: 0.6, green: 0.85, blue: 0.72, alpha: 1)),
        Palette(name: "Paper", bg: NSColor(white: 0.95, alpha: 1), card: NSColor(white: 0.88, alpha: 1), control: NSColor(white: 0.8, alpha: 1),
                accent: NSColor(srgbRed: 0.85, green: 0.36, blue: 0.2, alpha: 1), green: NSColor(srgbRed: 0.25, green: 0.58, blue: 0.4, alpha: 1)),
        // dual-tone: the card fades from `bg` at the top to `bg2` at the bottom
        Palette(name: "Dusk", bg: NSColor(srgbRed: 0.10, green: 0.08, blue: 0.18, alpha: 1), bg2: NSColor(srgbRed: 0.26, green: 0.12, blue: 0.16, alpha: 1),
                accent: NSColor(srgbRed: 1.0, green: 0.62, blue: 0.42, alpha: 1), green: NSColor(srgbRed: 0.55, green: 0.85, blue: 0.8, alpha: 1)),
        Palette(name: "Moss", bg: NSColor(srgbRed: 0.05, green: 0.12, blue: 0.10, alpha: 1), bg2: NSColor(srgbRed: 0.16, green: 0.13, blue: 0.06, alpha: 1),
                accent: NSColor(srgbRed: 0.85, green: 0.78, blue: 0.4, alpha: 1), green: NSColor(srgbRed: 0.55, green: 0.9, blue: 0.6, alpha: 1)),
        Palette(name: "Lagoon", bg: NSColor(srgbRed: 0.04, green: 0.10, blue: 0.16, alpha: 1), bg2: NSColor(srgbRed: 0.06, green: 0.22, blue: 0.24, alpha: 1),
                accent: NSColor(srgbRed: 0.35, green: 0.85, blue: 0.9, alpha: 1), green: NSColor(srgbRed: 0.5, green: 0.95, blue: 0.7, alpha: 1)),
    ]

    // "#RRGGBB" out, NSColor in (nil for anything malformed).
    static func hex(_ c: NSColor) -> String {
        let c = c.usingColorSpace(.sRGB) ?? c
        return String(format: "#%02X%02X%02X", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
    }
    static func colour(_ hex: String) -> NSColor? {
        var h = hex.trimmingCharacters(in: .whitespaces).uppercased()
        if h.hasPrefix("#") { h.removeFirst() }
        if h.count == 3 { h = h.map { String($0) + String($0) }.joined() }
        guard h.count == 6, let n = Int(h, radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat((n >> 16) & 0xFF) / 255, green: CGFloat((n >> 8) & 0xFF) / 255, blue: CGFloat(n & 0xFF) / 255, alpha: 1)
    }

    // "theme" = ember|slate|forest|sakura|paper|custom; any theme also accepts an "accent" override.
    // A custom theme is stored as one customTheme=bg,card,accent,break,text line (any part may be left out).
    static func apply(_ store: UserDefaults) {
        let wanted = (store.string(forKey: "theme") ?? "ember").lowercased()
        theme = presets.first { $0.name.lowercased() == wanted } ?? presets[0]
        if wanted == "custom" {
            theme.name = "Custom"
            if let bg = colour(store.string(forKey: "bg") ?? "") {
                theme.bg = bg
                theme.card = bg.blended(withFraction: 0.12, of: .white) ?? bg
                theme.control = bg.blended(withFraction: 0.22, of: .white) ?? bg
            }
        }
        if wanted == "custom", let line = store.string(forKey: "customTheme") {
            let parts = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            if parts.count >= 5 {
                if let c = colour(parts[0]) { theme.bg = c; theme.card = c.blended(withFraction: 0.12, of: .white) ?? c; theme.control = c.blended(withFraction: 0.22, of: .white) ?? c }
                if let c = colour(parts[1]) { theme.card = c; theme.control = c.blended(withFraction: 0.06, of: .white) ?? c }
                if let c = colour(parts[2]) { theme.accent = c }
                if let c = colour(parts[3]) { theme.green = c }
                theme.text = colour(parts[4]) ?? (theme.bg.isLight ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.94, alpha: 1))
                if parts.count > 5, let second = colour(parts[5]), hex(second) != hex(theme.bg) { theme.bg2 = second } else { theme.bg2 = nil }
            }
        }
        if let accent = colour(store.string(forKey: "accent") ?? "") { theme.accent = accent }
        if wanted != "custom" { theme.text = theme.bg.isLight ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.94, alpha: 1) }
        theme.dim = theme.text.withAlphaComponent(theme.bg.isLight ? 0.5 : 0.62)
        theme.faint = theme.text.withAlphaComponent(theme.bg.isLight ? 0.35 : 0.36)
    }
}

extension NSColor {
    var isLight: Bool {
        let c = usingColorSpace(.sRGB) ?? self
        return 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent > 0.6
    }
}

final class Field: NSTextField {
    var focused = false
    var onClick: (() -> Void)? // click the clock: start / pause / resume
    init(_ text: String, size: CGFloat, weight: NSFont.Weight = .light) {
        super.init(frame: .zero)
        stringValue = text
        font = .monospacedDigitSystemFont(ofSize: size, weight: weight)
        textColor = C.text
        alignment = .center
        isBordered = false
        drawsBackground = false
        isEditable = false
        focusRingType = .none
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool { true } // first click in an inactive panel still works
    override func mouseDown(with e: NSEvent) {
        window?.makeFirstResponder(self) // lets typed digits land
        onClick?()
    }
    override func becomeFirstResponder() -> Bool { focused = true; return super.becomeFirstResponder() }
    override func resignFirstResponder() -> Bool { focused = false; return super.resignFirstResponder() }
    // No tinted background: the clock is plain digits on the panel, focused or not (the cursor is the only cue).
}

final class Pill: NSButton {
    var fill: NSColor? { didSet { needsDisplay = true } }
    var onClick: (() -> Void)?
    var onDouble: (() -> Void)?
    var showsOnHover = false { didSet { alphaValue = showsOnHover ? 0 : 1 } }
    private var tracking: NSTrackingArea?

    override init(frame: NSRect) {
        super.init(frame: frame)
        isBordered = false
        bezelStyle = .regularSquare
        focusRingType = .none
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    override func draw(_ dirtyRect: NSRect) {
        if let fill {
            fill.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: bounds.height / 2, yRadius: bounds.height / 2).fill()
        }
        super.draw(dirtyRect)
    }
    override func mouseDown(with e: NSEvent) {
        if let onClick { onClick(); return }
        let double = e.clickCount == 2
        super.mouseDown(with: e) // single click fires the action
        if double { onDouble?() }
    }
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool { true }

    // An invisible hover target can't be entered, so the area is padded a little around the button.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        tracking.map(removeTrackingArea)
        guard showsOnHover else { return }
        let t = NSTrackingArea(rect: bounds.insetBy(dx: -8, dy: -8), options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(t)
        tracking = t
    }
    override func mouseEntered(with _: NSEvent) { if showsOnHover { alphaValue = 1 } }
    override func mouseExited(with _: NSEvent) { if showsOnHover { alphaValue = 0 } }
}

// One to-do row. The × is a real subview button, so deleting never depends on the row's own hit testing.
final class TodoRow: NSControl {
    let hover = Pill()
    let text: String
    let isDone: Bool
    var onToggle: () -> Void = {}
    var onDelete: () -> Void = {}
    private var tracking: NSTrackingArea?

    override var isFlipped: Bool { true }
    init(text: String, done: Bool) {
        self.text = text
        self.isDone = done
        super.init(frame: .zero)
        setContentHuggingPriority(.defaultLow, for: .horizontal) // fill the list width
        toolTip = "Click to tick or untick · × deletes"
        hover.widthAnchor.constraint(equalToConstant: 22).isActive = true
        hover.heightAnchor.constraint(equalToConstant: 22).isActive = true
        hover.translatesAutoresizingMaskIntoConstraints = false
        hover.onClick = { [weak self] in self?.onDelete() }
        addSubview(hover)
        NSLayoutConstraint.activate([hover.trailingAnchor.constraint(equalTo: trailingAnchor), hover.centerYAnchor.constraint(equalTo: centerYAnchor)])
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool { true }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        tracking.map(removeTrackingArea)
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(t)
        tracking = t
    }
    override func mouseEntered(with _: NSEvent) { hover.isHidden = false }
    override func mouseExited(with _: NSEvent) { hover.isHidden = true }
    override func mouseDown(with e: NSEvent) {
        if convert(e.locationInWindow, from: nil).x < bounds.width - 26 { onToggle() } // left of the ×: tick
    }

    override func draw(_ dirtyRect: NSRect) {
        let box = NSRect(x: 3, y: (bounds.height - 15) / 2, width: 15, height: 15)
        if isDone {
            C.accent.setFill()
            NSBezierPath(roundedRect: box, xRadius: 4.5, yRadius: 4.5).fill()
            let tick = NSBezierPath()
            tick.move(to: NSPoint(x: box.minX + 3.8, y: box.minY + 7.6))
            tick.line(to: NSPoint(x: box.minX + 6.3, y: box.minY + 10.4))
            tick.line(to: NSPoint(x: box.minX + 11, y: box.minY + 4.8))
            tick.lineWidth = 1.7
            tick.lineCapStyle = .round
            tick.lineJoinStyle = .round
            NSColor.white.setStroke()
            tick.stroke()
        } else {
            let ring = NSBezierPath(roundedRect: box.insetBy(dx: 0.5, dy: 0.5), xRadius: 4.5, yRadius: 4.5)
            ring.lineWidth = 1.2
            C.faint.setStroke()
            ring.stroke()
        }
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: isDone ? C.dim : C.text,
            .strikethroughStyle: isDone ? NSUnderlineStyle.single.rawValue : 0,
            .strikethroughColor: C.dim,
            .paragraphStyle: style,
        ]).draw(in: NSRect(x: 26, y: (bounds.height - 16) / 2, width: bounds.width - 56, height: 16))
    }
}

final class Flipped: NSView { override var isFlipped: Bool { true } }

// The card background, under everything: one colour, or a soft vertical fade for dual-tone themes.
final class Backdrop: NSView {
    override func draw(_ rect: NSRect) {
        C.bg.setFill()
        NSBezierPath(rect: bounds).fill()
        guard let second = C.theme.bg2 else { return }
        // The lower half fades from the base colour into the second tone.
        NSGradient(starting: C.bg, ending: second)?.draw(in: rect, angle: -90) // -90: top colour at the top
    }
}



// Horizontal row that acts as one click target, except clicks that land on a button inside it (Clear completed).
final class TagRow: NSStackView {
    var onTagClick: (() -> Void)?
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool { true }
    override func mouseDown(with e: NSEvent) {
        var v = hitTest(convert(e.locationInWindow, from: nil))
        while let x = v {
            if x is NSButton { return } // the button handles its own click
            v = x.superview
        }
        onTagClick?()
    }
}

// Footer row: the whole strip is clickable (toggles today's stats); the Clear button on top still gets its clicks.
// Time-left strip: full width when idle, then shrinks symmetrically toward the centre as the block runs out.
// Width changes are eased with a short implicit animation so the ticks look like a gentle drain, not steps.
final class DrainBar: NSView {
    var trackWidth: CGFloat = 236
    var colour = C.accent { didSet { needsDisplay = true } }
    private(set) var fractionValue: CGFloat = 1 // 1 = full time left
    var shownValue: CGFloat { shown }
    private var shown: CGFloat = 1 // what is drawn now
    private var from: CGFloat = 1 // where the current ease began
    private var start = Date()
    private var anim: Timer?
    private let ease: TimeInterval = 0.5

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool { false }
    // Fixed full-panel track; the strip is drawn inside it, so the stack never resizes it.
    override var intrinsicContentSize: NSSize { NSSize(width: trackWidth, height: 3) }

    // Each target starts a short ease from whatever is on screen, so once a second the orange slides inward.
    // If an ease is already running it simply continues toward the newest target.
    func setFraction(_ f: CGFloat, running: Bool) {
        fractionValue = f
        guard running else { anim?.invalidate(); anim = nil; shown = f; needsDisplay = true; return }
        if anim == nil {
            from = shown
            start = Date()
            anim = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.step() }
            }
        }
    }

    private func step() {
        let t = min(1, Date().timeIntervalSince(start) / ease)
        let e = t * t * (3 - 2 * t) // smoothstep
        shown = from + (fractionValue - from) * e
        needsDisplay = true
        if t >= 1 { anim?.invalidate(); anim = nil }
    }

    // Test hooks: drive the ease without depending on runloop timing.
    var animating: Bool { anim != nil }
    var animStart: CGFloat? { from }
    @discardableResult func onTick(_ advance: TimeInterval) -> CGFloat {
        start = start.addingTimeInterval(-advance)
        step()
        return shown
    }

    override func draw(_ rect: NSRect) {
        C.hairline.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 1.5, yRadius: 1.5).fill()
        let w = max(0.5, bounds.width * shown) // a hair of colour remains at 00:00
        colour.setFill()
        NSBezierPath(roundedRect: NSRect(x: (bounds.width - w) / 2, y: 0, width: w, height: bounds.height), xRadius: 1.5, yRadius: 1.5).fill()
    }
}

// The themed POMO wordmark: display-weight rounded letters, each one its own click target.
final class Wordmark: NSView {
    struct State { var running = false; var isBreak = false; var minutes = 25 }
    static let letters: [(String, Int)] = [("P", 60), ("O", 25), ("M", 15), ("O", 5)]
    var state = State() { didSet { needsDisplay = true } }
    var onLetter: ((Int) -> Void)?
    private var hovered = -1 { didSet { needsDisplay = true } }
    private var tracking: NSTrackingArea?

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool { true }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        tracking.map(removeTrackingArea)
        let t = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(t)
        tracking = t
    }
    func index(at p: NSPoint) -> Int { min(3, max(0, Int(p.x / (bounds.width / 4)))) }

    override func mouseMoved(with e: NSEvent) { hovered = index(at: convert(e.locationInWindow, from: nil)) }
    override func mouseExited(with e: NSEvent) { hovered = -1 }
    override func mouseDown(with e: NSEvent) { onLetter?(Wordmark.letters[index(at: convert(e.locationInWindow, from: nil))].1) }

    override func draw(_ rect: NSRect) {
        let cell = bounds.width / 4
        let letterFont = NSFont.systemFont(ofSize: 15, weight: .black).rounded
        for (i, (ch, minutes)) in Wordmark.letters.enumerated() {
            let selected = minutes == state.minutes
            let color: NSColor = selected ? C.accent : hovered == i ? C.text : state.running ? C.dim : C.dim
            // One text box per letter, centred in its cell. The underline is measured from the same box that
            // draws the letter, so the rule always sits exactly under the stroke and shares its centre.
            let attrs: [NSAttributedString.Key: Any] = [.font: letterFont, .foregroundColor: color]
            let glyph = NSAttributedString(string: ch, attributes: attrs)
            let size = glyph.size()
            let x = CGFloat(i) * cell + (cell - size.width) / 2
            let y = (bounds.height - size.height) / 2
            glyph.draw(at: NSPoint(x: x, y: y))
            if selected { // the letter's own underline style: tracked by the text system, never by hand
                NSAttributedString(string: ch, attributes: attrs.merging([.underlineStyle: NSUnderlineStyle.single.rawValue, .underlineColor: C.accent]) { $1 })
                    .draw(at: NSPoint(x: x, y: y))
            }
        }
    }
}

private extension NSFont {
    // SF Rounded if the system has it; otherwise the normal system face. No bundled font files.
    var rounded: NSFont {
        let desc = fontDescriptor.withDesign(.rounded) ?? fontDescriptor
        return NSFont(descriptor: desc, size: pointSize) ?? self
    }
}

struct Todo { var id: String; var text: String; var done: Bool }

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSTextFieldDelegate {
    // Explicit suite: launched from the terminal the binary has no bundle ID and UserDefaults.standard would differ.
    let store = UserDefaults(suiteName: "local.pomo") ?? .standard

    let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: C.width, height: 400), // starts tall; autoHeight sets the size
                        styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
                        backing: .buffered, defer: false)
    let stack = NSStackView()
    let clock = Field("", size: 42)
    lazy var up = self.stepper("chevron.up")
    lazy var down = self.stepper("chevron.down")
    let entry = Field("", size: 12)
    lazy var addBtn = self.pill("circle-plus", nil) // placeholder; real setup in buildUI
    let listHost = NSStackView()
    let foot = TagRow()
    let leftLbl = NSTextField(labelWithString: "")
    lazy var clearBtn = self.pill("Clear completed", nil, wide: true)
    var list: NSScrollView!
    lazy var listHeight = list.heightAnchor.constraint(equalToConstant: CGFloat(rows) * C.row)
    let rows = 3 // min visible rows

    // Progress is one array rather than separate "done:X" keys: clearing can never desync the two.
    // Items are tracked by id, not by text: the same to-do twice is two rows, and no index goes stale on rebuild.
    var items: [Todo] = []
    var focus: TimeInterval = 0 // 0 -> 25 min
    var paused: TimeInterval = 0 // seconds left at the last pause; 0 = nothing to resume
    var focusMinutes: Int { focus == 0 ? 25 : Int((focus / 60).rounded()) }
    var running = false
    var quitting = false // write state synchronously when quitting; atexit handles other exits
    // Favourites: 25 min focus, 5 min break, 1 hour. Change with: defaults write local.pomo presets -array 15 30 90
    var presets: [Int] {
        let saved = (store.array(forKey: "presets") as? [NSNumber])?.map { $0.intValue } ?? []
        return saved.isEmpty ? [25, 5, 60] : saved
    }
    var autoFocus = false // auto breaks + next focus; loaded at launch
    var cycle = 0 // completed focus blocks today (kept for older saved data)
    // Today's tally: finished focus blocks, minutes actually focused in the current block, and to-dos ticked.
    // Stored under a per-day key so midnight starts fresh without any timer.
    var day: [String: Any] = [:]
    var dayKey: String { "day:" + String(Calendar.current.startOfDay(for: Date()).description.prefix(10)) }
    var cycleKey: String { "cycle:" + String(Calendar.current.startOfDay(for: Date()).description.prefix(10)) }
    var focusStarted = Date.distantPast // when the current focus block started (for live minutes)
    var shownDayKey = "" // the day the HUD currently shows
    var runningBreak = false
    var pausedBreak = false // the paused time is a break, not focus
    var history: [Int] = [] // sort order for right-click "Pinned to menu bar": most recently shown first
    var doneBlock = false // finished a focus block -> next start is the break
    var end = Date.distantPast
    var breakMinutes = 5 // the next break's length (typed, preset or default 5)
    // workingBreak (below) is the length captured for the running cycle.
    var typing = false
    var typed = ""

    // Launch (from Finder, Dock, Launchpad or a login item): show the panel in its corner.
    // Determine which screen has the pointer, so it lands where you're looking.
    func showPanel() {
        if panel.isVisible { panel.orderFrontRegardless(); return }
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        panel.orderFrontRegardless()
        if let s = screen?.visibleFrame {
            panel.setFrameTopLeftPoint(NSPoint(x: s.maxX - panel.frame.width - 12, y: s.maxY - 12))
        }
    }

    func pinToMenuBar() { // app icon click, or menu item: open / close
        if panel.isVisible { panel.orderOut(nil) } else { showPanel() }
    }

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panel.title = "Pomo"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.appearance = NSAppearance(named: C.bg.isLight ? .aqua : .darkAqua)
        panel.contentView!.wantsLayer = true
        panel.contentView!.layer?.cornerRadius = 0
        panel.backgroundColor = C.bg
        panel.level = .floating // above normal windows
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false // stays visible when another app is focused
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.minSize = NSSize(width: C.width, height: 0)

        C.apply(store)
        focus = store.double(forKey: "focus")
        if focus.isNaN || focus < 60 || focus > 999 * 60 { focus = 0 } // corrupt value -> default 25 min
        if let live = store.object(forKey: "handoffEnd") as? Date, live > Date(), !running { // quit while running: keep it
            end = live
            running = true
            runningBreak = store.bool(forKey: "handoffBreak")
            store.removeObject(forKey: "handoffEnd")
        }
        let todos = store.stringArray(forKey: "todos") ?? [] // older saves: names + "done:<name>" flags
        items = (store.array(forKey: "tasks") as? [[Any]] ?? []).compactMap { row in
            guard let t = (row.first as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
            let id = (row.count > 2 ? row[2] as? String : nil) ?? UUID().uuidString // older saves had no id
            return Todo(id: id, text: String(t.prefix(200)), done: (row.count > 1 ? row[1] as? Bool : nil) ?? store.bool(forKey: "done:" + t))
        }
        if items.isEmpty { items = todos.map { Todo(id: UUID().uuidString, text: $0, done: store.bool(forKey: "done:" + $0)) } }
        for t in todos { store.removeObject(forKey: "done:" + t) } // migrate once, then the old keys are gone
        store.removeObject(forKey: "todos")

        buildUI()
        styleChrome()
        listHeight.constant = CGFloat(max(rows, items.count, showStats ? 1 : 0)) * C.row // fit the real list at once
        autoHeight()
        placeTopRight()
        pinnedTop = panel.frame.maxY
        panel.orderFrontRegardless()
        if pinnedCountdown { handOver() } // replace the old copy, keep its countdown
        autoFocus = store.bool(forKey: "auto")
        cycle = store.integer(forKey: cycleKey)
        day = (store.dictionary(forKey: dayKey) ?? [:])
        day["done"] = day["done"] as? Int ?? 0
        let savedBreak = store.double(forKey: "break")
        breakMinutes = (1...60).contains(savedBreak) && !savedBreak.isNaN ? Int(savedBreak) : 5
        let savedPause = store.double(forKey: "paused")
        paused = savedPause.isFinite && savedPause > 0 && savedPause < 24 * 3600 ? savedPause : 0
        pausedBreak = store.bool(forKey: "pausedBreak")
        history = store.array(forKey: "history") as? [Int] ?? []
        dragRows = Int(store.double(forKey: "listRows").rounded())
        if dragRows < rows { dragRows = 0 }
        history.insert(Int(ProcessInfo.processInfo.processIdentifier), at: 0) // this launch = most recently used
        history = Array(history.prefix(6))
        store.set(history, forKey: "history")
        if listHeight.constant != CGFloat(max(rows, items.count, dragRows)) * C.row { autoHeight() }
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            MainActor.assumeIsolated { self?.key(e) ?? e }
        }
    }

    // Corner placement must survive a menu bar on a second display or a notch: use the screen under the pointer.
    func placeTopRight() {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let vf = screen?.visibleFrame else { return }
        panel.setFrameTopLeftPoint(NSPoint(x: vf.maxX - panel.frame.width - 12, y: vf.maxY - 12))
        pinnedTop = panel.frame.maxY
    }

    func windowShouldClose(_: NSWindow) -> Bool { panel.orderOut(nil); return false } // reopen from the menu bar

    // Click the menu bar icon: show the panel in its usual corner, or hide it. Either way nothing resets.
    func togglePanel() { pinToMenuBar() }

    var menuBar: MenuBar?
    var pinnedCountdown: Bool { store.bool(forKey: "pinMenuBar") } // see build.sh --pin / --unpin

    // Pinned mode keeps exactly one running copy. A newly launched instance asks the existing one to hand over:
    // it saves its live countdown on the way out, and this one adopts it before building its UI.
    // Shortcut: a hung old copy is force-quit after 1s, and the persisted pause state is used instead.

    // Switch look at runtime: persist the choice, repaint the panel and its subviews.
    // name = a preset, or "custom" with the full set of colours (nil channels fall back to the current ones).
    func applyTheme(_ name: String, accent: NSColor?, bg: NSColor?, bg2: NSColor? = nil, card: NSColor? = nil, breakc: NSColor? = nil, textc: NSColor? = nil) {
        store.set(name, forKey: "theme")
        if name == "custom" {
            let b = bg ?? C.bg, c = card ?? C.card, a = accent ?? C.accent, g = breakc ?? C.green, t = textc ?? C.text
            let second = bg2 ?? b
            store.set([C.hex(b), C.hex(c), C.hex(a), C.hex(g), C.hex(t), C.hex(second)].joined(separator: ","), forKey: "customTheme")
        } else {
            store.removeObject(forKey: "customTheme")
            if let a = accent { store.set(C.hex(a), forKey: "accent") } else { store.removeObject(forKey: "accent") }
            if let b = bg { store.set(C.hex(b), forKey: "bg") } else { store.removeObject(forKey: "bg") }
        }
        C.apply(store)
        styleChrome()
        refresh()
        rebuildList() // custom-drawn rows read the palette at draw time; rebuild so text fields re-take theirs too
        panel.invalidateShadow()
    }

    // Everything the window itself owns. Called at launch and after any theme change, so there is one code path.
    func styleChrome() {
        panel.appearance = NSAppearance(named: C.bg.isLight ? .aqua : .darkAqua)
        panel.backgroundColor = C.bg // the solid base; a dual-tone theme fades on top in Backdrop
        clock.textColor = C.text
        stateLabel.textColor = C.faint
        leftLbl.textColor = C.faint
        entry.textColor = C.text
        entry.placeholderAttributedString = NSAttributedString(string: "  New to-do", attributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: C.faint])
        clearBtn.contentTintColor = C.dim
        for b in [up, down] { b.fill = C.card }
        updateStats()
        panel.contentView?.needsDisplay = true
        backdrop.needsDisplay = true
        stack.needsDisplay = true
        mark.needsDisplay = true
        bar.needsDisplay = true
    }


    func setPinned(_ on: Bool) {
        store.set(on, forKey: "pinMenuBar")
        refresh()
    }

    func handOver() {
        guard pinnedCountdown else { return }
        let pids = store.array(forKey: "history") as? [Int] ?? []
        let me = Int(ProcessInfo.processInfo.processIdentifier)
        guard let oldPid = pids.first(where: { $0 != me }),
              let old = NSRunningApplication(processIdentifier: pid_t(oldPid)), !old.isTerminated else { return }
        old.terminate()
        for _ in 0..<20 where !old.isTerminated { usleep(50_000) }
        if !old.isTerminated { old.forceTerminate() }
        if let live = store.object(forKey: "handoffEnd") as? Date, live > Date() {
            end = live
            running = true
            runningBreak = store.bool(forKey: "handoffBreak")
            store.removeObject(forKey: "handoffEnd")
        }
    }

    // Quitting while running in pinned mode: keep the live countdown for the next launch.
    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        quitting = true
        store.set(cycle, forKey: cycleKey)
        store.set(day, forKey: dayKey)
        store.set(autoFocus, forKey: "auto")
        if pinnedCountdown && running {
            store.set(Date(timeIntervalSinceNow: end.timeIntervalSinceNow), forKey: "handoffEnd")
            store.set(runningBreak, forKey: "handoffBreak")
        }
        return .terminateNow
    }

    // MARK: construction
    func stepper(_ symbol: String) -> Pill {
        let b = Pill()
        b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: symbol)
        b.contentTintColor = C.dim
        b.fill = C.card
        b.target = self
        b.action = #selector(step)
        b.widthAnchor.constraint(equalToConstant: 20).isActive = true // small: the clock keeps the sides tight
        b.heightAnchor.constraint(equalToConstant: 28).isActive = true
        b.showsOnHover = true
        DispatchQueue.main.async { b.alphaValue = 0 } // updateTrackingAreas runs after this
        return b
    }

    func pill(_ title: String, _ fill: NSColor?, wide: Bool = false) -> Pill {
        let b = Pill()
        b.title = title
        b.fill = fill
        b.font = .systemFont(ofSize: wide ? 10 : 12, weight: .medium)
        b.contentTintColor = wide ? C.dim : .white
        b.target = self
        if fill != nil {
            b.action = #selector(toggle) // start / pause
            b.onDouble = { [weak self] in self?.stopTimer() }
        }
        b.widthAnchor.constraint(equalToConstant: wide ? 100 : 88).isActive = true
        b.heightAnchor.constraint(equalToConstant: wide ? 18 : 26).isActive = true
        return b
    }

    func buildUI() {
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        // 1. time-left strip across the top: it drains from both ends toward the centre as the block runs out
        bar.trackWidth = C.width
        bar.translatesAutoresizingMaskIntoConstraints = false
        stack.insertArrangedSubview(bar, at: 0) // first row, always
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: stack.topAnchor),
            bar.heightAnchor.constraint(equalToConstant: 3),
            bar.widthAnchor.constraint(equalToConstant: C.width),
        ])

        // 2. the timer: big plain digits (no tint, no box), the POMO wordmark under them, and the state word.
        //    Click the clock to start/pause. ▲▼ appear only when the pointer comes near.
        clock.widthAnchor.constraint(equalToConstant: 176).isActive = true // digits get the room; chevrons tuck in
        clock.heightAnchor.constraint(equalToConstant: 64).isActive = true // reserve cap height so layout never guesses
        clock.font = .monospacedDigitSystemFont(ofSize: 56, weight: .ultraLight)
        clock.textColor = C.text
        clock.onClick = { [weak self] in self?.clockClicked() }
        mark.onLetter = { [weak self] minutes in self?.setLength(minutes) }
        mark.toolTip = "P · 1 hr    O · 25 min    M · 15 min    O · 5 min"
        mark.translatesAutoresizingMaskIntoConstraints = false
        mark.heightAnchor.constraint(equalToConstant: 24).isActive = true
        mark.widthAnchor.constraint(equalToConstant: 148).isActive = true
        stateLabel.font = .systemFont(ofSize: 9, weight: .medium)
        stateLabel.alignment = .center
        stateLabel.isSelectable = false
        stateLabel.toolTip = "Click the clock to start / pause · ⌥-click to restart"

        let under = NSStackView()
        under.orientation = .vertical
        under.alignment = .centerX
        under.spacing = 3
        under.addArrangedSubview(mark)
        under.addArrangedSubview(stateLabel)

        // chevrons sit tight to the digits and stay invisible until hovered.
        let timerRow = NSStackView()
        timerRow.alignment = .centerY
        timerRow.spacing = 0
        timerRow.addArrangedSubview(up)
        timerRow.addArrangedSubview(clock)
        timerRow.addArrangedSubview(down)
        let timerBlock = NSStackView()
        timerBlock.orientation = .vertical
        timerBlock.alignment = .centerX
        timerBlock.spacing = 2
        timerBlock.addArrangedSubview(timerRow)
        timerBlock.addArrangedSubview(under)
        stack.addArrangedSubview(timerBlock)
        stack.setCustomSpacing(10, after: timerBlock)

        // 3. input bar: borderless, centred like the list; ⏎ adds
        entry.alignment = .left
        entry.font = .systemFont(ofSize: 12)
        if let cell = entry.cell as? NSTextFieldCell { cell.placeholderString = "New to-do" }
        entry.isEditable = true
        entry.delegate = self
        entry.target = self
        entry.action = #selector(self.addTodo)
        entry.placeholderAttributedString = NSAttributedString(string: "  New to-do", attributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: C.faint])
        entry.widthAnchor.constraint(equalToConstant: C.width - 24).isActive = true
        entry.drawsBackground = false // the card behind it (solid or dual-tone) shows through
        stack.addArrangedSubview(entry)

        // 4. to-do list
        list = NSScrollView()
        list.widthAnchor.constraint(equalToConstant: C.width - 24).isActive = true
        list.hasVerticalScroller = true
        list.autohidesScrollers = true
        list.drawsBackground = false
        list.borderType = .noBorder
        let doc = Flipped()
        doc.autoresizingMask = [.width]
        doc.addSubview(listHost)
        listHost.orientation = .vertical
        listHost.alignment = .leading
        listHost.spacing = 0
        listHost.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            listHost.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
            listHost.topAnchor.constraint(equalTo: doc.topAnchor),
            listHost.widthAnchor.constraint(equalTo: doc.widthAnchor),
        ])
        list.documentView = doc
        stack.addArrangedSubview(list)
        listHeight.isActive = true // after the list is in the stack, matching layout order
        stack.setCustomSpacing(6, after: list)

        // 5. footer: "2/4 done" (click = show/hide today's numbers) and Clear completed in one row.
        //    One row = one view, so click routing stays inside it: buttons act, the rest toggles stats.
        foot.orientation = .horizontal
        foot.alignment = .centerY
        foot.widthAnchor.constraint(equalToConstant: C.width - 24).isActive = true
        leftLbl.font = .systemFont(ofSize: 10)
        leftLbl.textColor = C.faint
        leftLbl.isSelectable = false
        foot.addArrangedSubview(leftLbl)
        foot.addArrangedSubview(NSView()) // spring: pushes the button right
        clearBtn.action = #selector(clearDone)
        clearBtn.target = self
        foot.addArrangedSubview(clearBtn)
        foot.translatesAutoresizingMaskIntoConstraints = false
        clearBtn.translatesAutoresizingMaskIntoConstraints = false
        foot.onTagClick = { [weak self] in self?.toggleStats() } // clicking the label / gap toggles today's stats; the button keeps its own click
        stack.addArrangedSubview(foot)


        // today's numbers: hidden until the footer is clicked, remembered
        statsWrap.orientation = .horizontal
        statsWrap.alignment = .centerX
        statsWrap.widthAnchor.constraint(equalToConstant: C.width - 24).isActive = true
        statsWrap.addArrangedSubview(statsLine)
        statsWrap.isHidden = !showStats
        stack.addArrangedSubview(statsWrap)


        let content = panel.contentView!
        content.addSubview(backdrop)
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: content.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            backdrop.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: content.trailingAnchor),
        ])
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 4), // nothing may sit above the strip
            stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -10),
            stack.heightAnchor.constraint(greaterThanOrEqualToConstant: 200), // never let the window shrink past the clock
        ])
        rebuildList()
    }
    let backdrop = Backdrop() // the card itself: solid, or a two-tone fade for dual-tone themes
    let bar = DrainBar() // animated time-left strip
    let stateLabel = NSTextField(labelWithString: "")
    let mark = Wordmark() // POMO under the clock, each letter a length toggle

    // MARK: layout
    // Only the list drives its own height; the timer never resizes anything. The window follows the list,
    // pinned by its top edge, keeping a user-dragged height as a floor.
    func autoHeight() {
        let content = panel.contentView!
        content.layoutSubtreeIfNeeded()
        let height = max(stack.frame.height, 200) + 14 // stack's top inset + a small bottom margin
        let top = panel.frame.maxY
        guard abs(panel.contentLayoutRect.height - height) > 0.5 else { return }
        panel.setContentSize(NSSize(width: content.frame.width, height: height))
        if !panel.isVisible { return } // first sizing before show: placement happens in placeTopRight()
        panel.setFrameTopLeftPoint(NSPoint(x: panel.frame.minX, y: top)) // corner stays put
        pinnedTop = top
    }

    var dragRows = 0 // extra rows the user dragged in; remembered, never reduced when the list shrinks
    func windowDidEndLiveResize(_: Notification) { // a drag ends: snap to fit the list (remembered rows are a floor)
        let room = panel.contentLayoutRect.height - (stack.frame.height - list.frame.height) - stack.frame.minY - 10
        let wanted = max(CGFloat(max(rows, items.count)) * C.row, min(room.rounded(), CGFloat(60) * C.row))
        listHeight.constant = wanted
        dragRows = Int((wanted / C.row).rounded())
        store.set(Double(dragRows), forKey: "listRows")
        autoHeight()
        sizeListContent()
    }

    // Resizing must never drift the window's top edge (AppKit can anchor the bottom), so re-pin it each time.
    var pinnedTop: CGFloat?
    func windowDidResize(_: Notification) {
        sizeListContent()
        if let top = pinnedTop, abs(panel.frame.maxY - top) > 0.5, panel.isVisible { panel.setFrameTopLeftPoint(NSPoint(x: panel.frame.minX, y: top)) }
    }

    func sizeListContent() { // scroll view documents get no layout pass of their own
        guard let doc = list.documentView else { return }
        doc.setFrameSize(NSSize(width: list.contentSize.width, height: listHost.fittingSize.height))
        listHost.layoutSubtreeIfNeeded() // now: rows get frames (deferred if called during layout)
        list.reflectScrolledClipView(list.contentView)
    }

    // MARK: to-dos
    func saveItems() {
        store.set(items.map { [$0.text, $0.done, $0.id] }, forKey: "tasks")
    }

    func rebuildList() {
        guard list != nil else { return }
        listHost.subviews.forEach { $0.removeFromSuperview() }
        for item in items {
            let row = TodoRow(text: item.text, done: item.done)
            row.widthAnchor.constraint(equalToConstant: C.width - 24 - 16).isActive = true
            row.heightAnchor.constraint(equalToConstant: C.row).isActive = true
            let id = item.id
            row.onToggle = { [weak self] in self?.toggleItem(id) }
            row.onDelete = { [weak self] in self?.remove(id) }
            row.hover.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Delete")
            row.hover.contentTintColor = C.faint
            row.hover.isHidden = true
            listHost.addArrangedSubview(row)
        }
        updateFooter()
        updateStats()
        sizeListContent()
        autoHeight()
    }

    var doneCount: Int { items.filter(\.done).count }

    func updateFooter() {
        let doneCount = doneCount
        leftLbl.stringValue = items.isEmpty ? "Nothing yet" : "\(doneCount)/\(items.count) done"
        clearBtn.isHidden = doneCount == 0
    }

    // MARK: today's hidden stats
    let statsWrap = NSStackView() // today's numbers, hidden until the footer line is clicked
    let statsLine = NSTextField(labelWithString: "")

    var showStats = UserDefaults.standard.bool(forKey: "showStats") // remembered, hidden by default

    @objc func toggleStats() {
        showStats.toggle()
        UserDefaults.standard.set(showStats, forKey: "showStats")
        updateStats()
        statsWrap.isHidden = !showStats
        autoHeight()
    }

    // Clears only today's tally; the running block keeps its minutes from now on.
    func resetDay() {
        day = [:]
        focusStarted = running && !runningBreak ? Date() : .distantPast
        store.removeObject(forKey: dayKey)
        updateStats()
    }

    func bump(_ key: String, _ by: Int) {
        day[key] = (day[key] as? Int ?? 0) + by
        store.set(day, forKey: dayKey)
    }

    // "2 pomos · 52 min focus · 3 done today" — minutes include the block running right now.
    func updateStats() {
        guard showStats else { return }
        if shownDayKey != dayKey { // midnight passed since the line was last drawn
            shownDayKey = dayKey
            day = store.dictionary(forKey: dayKey) ?? [:]
        }
        let pomos = day["pomos"] as? Int ?? 0
        var minutes = day["minutes"] as? Int ?? 0
        if running && !runningBreak && focusStarted != .distantPast { minutes += Int(Date().timeIntervalSince(focusStarted) / 60) }
        let ticked = day["done"] as? Int ?? 0
        let time = minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
        statsLine.attributedStringValue = NSAttributedString(string: "\(pomos) pomo\(pomos == 1 ? "" : "s") · \(time) focus · \(ticked) done", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .medium),
            .foregroundColor: C.faint,
        ])
    }

    func toggleItem(_ id: String) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].done = !items[i].done
        if items[i].done { bump("done", 1) } // today's tally: each tick counts once
        saveItems()
        rebuildList()
    }

    func remove(_ id: String) {
        items.removeAll { $0.id == id }
        saveItems()
        rebuildList()
    }

    @objc func clearDone() {
        items.removeAll(where: \.done)
        saveItems()
        rebuildList()
    }

    @objc func addTodo() {
        let text = entry.stringValue.trimmingCharacters(in: .whitespaces)
        entry.stringValue = ""
        guard !text.isEmpty else { return }
        items.append(Todo(id: UUID().uuidString, text: text, done: false))
        saveItems()
        rebuildList()
    }

    func controlTextDidEndEditing(_ n: Notification) { // Enter in the to-do field
        guard n.object as? NSTextField === entry else { return }
        addTodo()
    }

    // During a focus block only the timer stays bright: the to-do list and footer fade but stay visible.
    func setDimmed(_ dim: Bool) {
        for v in [entry, list, foot] as [NSView] { v.alphaValue = dim ? 0.3 : 1 }
    }

    // MARK: timer
    // POMO under the clock: same meaning as the menu bar wordmark. 60 min keeps a 10 min break; others pair with 5.
    func setLength(_ minutes: Int) {
        if minutes == 5 && (doneBlock || runningBreak) { if !running { setBreak(5) } }
        else { setRhythm(focus: minutes, break: minutes == 60 ? 10 : 5) }
        refresh()
    }

    // Set the timer length: focus minutes, or the break length while the break is next / running.
    func preset(_ minutes: Int) {
        guard !running else { return } // pause first
        paused = 0 // a new length, not a resume
        store.removeObject(forKey: "paused")
        if doneBlock { setBreak(min(minutes, 60)); workingBreak = 0 } // pick the break length for this next break
        else { focus = TimeInterval(minutes * 60); store.set(focus, forKey: "focus"); workingBreak = breakMinutes } // this cycle's break
        refresh()
    }

    @objc func step(_ b: Pill) {
        guard !running else { return } // pause first
        paused = 0 // a new length, not a resume
        store.removeObject(forKey: "paused")
        let by = b === up ? 1 : -1
        if doneBlock {
            setBreak(max(1, min(60, breakMinutes + by)))
        } else {
            focus = TimeInterval(max(1, min(999, focusMinutes + by)) * 60)
            store.set(focus, forKey: "focus")
        }
        refresh()
    }

    func setBreak(_ minutes: Int) {
        breakMinutes = max(1, minutes) // never 0: a zero-length block would end the moment it starts
        store.set(Double(minutes), forKey: "break")
    }

    func startBreak() {
        running = true
        runningBreak = true
        end = Date().addingTimeInterval(TimeInterval((workingBreak > 0 ? workingBreak : breakMinutes)) * 60)
    }

    // Start: fresh block, or carry on from where you paused. A frozen break resumes as the same break.
    @objc func toggle() {
        if running { pause(); return }
        runningBreak = paused > 0 ? pausedBreak : doneBlock
        running = true
        let seconds = paused > 0 ? paused : (runningBreak ? Double(workingBreak > 0 ? workingBreak : breakMinutes) * 60 : TimeInterval(focusMinutes * 60))
        if !runningBreak && paused == 0 { workingBreak = breakMinutes } // freeze this cycle's break length at start
        if !runningBreak { focusStarted = Date() } // used for the live "min focus" in the stats line
        end = Date().addingTimeInterval(seconds)
        paused = 0
        store.removeObject(forKey: "paused")
        refresh()
    }

    var keepPause = false

    func pause() {
        guard running else { return }
        bankFocus() // minutes run so far count toward today even while paused
        keepPause = true // stopTimer() would otherwise clear what we are about to save
        paused = max(1, end.timeIntervalSinceNow)
        pausedBreak = runningBreak
        store.set(paused, forKey: "paused")
        store.set(pausedBreak, forKey: "pausedBreak")
        stopTimer()
    }

    func bankFocus() { // add the minutes actually spent in the current focus block to today's tally
        guard !runningBreak, focusStarted != .distantPast else { return }
        let minutes = Int(Date().timeIntervalSince(focusStarted) / 60)
        if minutes > 0 { bump("minutes", minutes) }
        focusStarted = .distantPast
    }

    // Throw the current time away and go back to a full block (or the ready break).
    func stopTimer() {
        bankFocus()
        running = false
        end = .distantPast
        if keepPause { keepPause = false } // called from pause(): keep the saved time
        else { paused = 0; store.removeObject(forKey: "paused") } // stop / restart: forget the paused time
        refresh()
    }

    func refresh() {
        let left = max(0, Int(end.timeIntervalSinceNow.rounded(.up)))
        let total = runningBreak ? Double(workingBreak > 0 ? workingBreak : breakMinutes) * 60 : Double(focusMinutes) * 60
        let minutes = doneBlock ? breakMinutes : focusMinutes
        let idle = paused > 0 ? Int(paused) : minutes * 60 // paused: show what will resume
        let text = typing ? typed : end == .distantPast ? String(format: "%02d:%02d", idle / 60, idle % 60) : String(format: "%02d:%02d", left / 60, left % 60)
        // Update the colour only: rewriting the whole attributed string throws away the text field's editing state.
        let active = clock.currentEditor()
        let textOwnedByEditor = active != nil && panel.firstResponder === clock
        if !textOwnedByEditor { clock.stringValue = text }
        clock.textColor = runningBreak ? C.green : C.text
        stateLabel.stringValue = (running ? (runningBreak ? "break" : "pomo") : paused > 0 ? "paused" : doneBlock ? "break ready" : "start")
            + (autoFocus ? " · auto" : "")
        stateLabel.textColor = runningBreak ? C.green : running || paused > 0 ? C.accent : C.faint
        mark.state = Wordmark.State(running: running, isBreak: runningBreak, minutes: doneBlock ? breakMinutes : focusMinutes)
        setDimmed(running && !runningBreak) // focus: the list steps back, the clock is the only bright thing
        // Time-left strip, updated before the end-of-block handoff below starts the next phase in this same pass.
        bar.colour = runningBreak ? C.green : C.accent
        bar.alphaValue = running ? 1 : 0.35
        bar.setFraction(running && total > 0 ? CGFloat(max(0, min(1, Double(left) / total))) : running ? 0 : 1, running: running)
        updateStats() // live "min focus" while the stats are open
        statusMenu() // menu bar item mirrors the same state
        for b in [up, down] { b.fill = running ? C.bg : C.card } // greyed while running
        // A finished countdown: react once, and mark it used up (otherwise every tick re-triggers the auto rhythm).
        if running && end <= Date() {
            running = false
            end = .distantPast
            let wasFocus = !runningBreak
            doneBlock = wasFocus // next start = break; after the break, next start = focus again
            if wasFocus {
                cycle += 1; store.set(cycle, forKey: cycleKey)
                bump("pomos", 1) // one finished focus block today
                if focusStarted != .distantPast {
                    let spent = Int(Date().timeIntervalSince(focusStarted) / 60)
                    if spent > 0 { bump("minutes", spent) }
                }
                focusStarted = .distantPast
            }
            if !runningBreak { workingBreak = breakMinutes } // a block that didn't come from a Start still uses the chosen break
            if wasFocus && autoFocus { startBreak(); chime("Time's up — \(workingBreak) min break") }
            else if !wasFocus && autoFocus { toggle(); chime("Break over — \(focusMinutes) min focus") }
            else { chime(wasFocus ? "Time's up — take a break" : "Break over") }
            refresh()
        }
    }

    func chime(_ message: String) {
        NSSound(named: runningBreak ? "Glass" : "Morse")?.play()
        let n = NSUserNotification()
        n.title = "Pomo"
        n.informativeText = message
        NSUserNotificationCenter.default.deliver(n)
    }

    func statusMenu() {
        (NSApp.delegate as? AppDelegate)?.menuBar?.update(running: running, isBreak: runningBreak, left: max(0, Int(end.timeIntervalSinceNow.rounded(.up))), title: menuTitle)
    }

    var menuTitle: String {
        if running { let l = max(0, Int(end.timeIntervalSinceNow.rounded(.up))); return "\(runningBreak ? "break" : "focus") \(l / 60):\(String(format: "%02d", l % 60))" }
        if paused > 0 { let p = Int(paused.rounded(.up)); return "paused \(p / 60):\(String(format: "%02d", p % 60))" }
        return doneBlock ? "break ready" : "\(focusMinutes) min"
    }

    // Menu bar: one-click rhythm. Focus 60 + break 10, automatic breaks on; pause first if running.
    func setRhythm(focus minutes: Int, break breakMin: Int) {
        if running { pause() }
        doneBlock = false
        workingBreak = 0
        preset(minutes)
        setBreak(breakMin)
        autoFocus = true
        store.set(true, forKey: "auto")
        refresh()
    }

    var workingBreak = 0 // break length captured when a focus block started (the cycle's own 5 min, not whatever preset comes next)

    // Click the clock: start / pause / resume. Hold ⌥ and click: throw the time away and restart.
    func clockClicked() {
        if NSEvent.modifierFlags.contains(.option) { stopTimer(); return }
        toggle()
    }

    // MARK: keyboard
    // The timer only reads keys while it is the selected control (click the clock once). Everything else —
    // typing to-dos, Space, arrows — goes to the to-do field or is ignored, so the two never override each other.
    func key(_ e: NSEvent) -> NSEvent? {
        guard panel.isKeyWindow, panel.firstResponder === clock || typing else { return e }
        if !e.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty, e.modifierFlags != .numericPad { return e }
        let ch = e.charactersIgnoringModifiers ?? ""
        if typing { // a number is being entered on the clock
            switch e.keyCode {
            case 36, 76: commitClock(); return nil
            case 53, 51: typing = false; refresh(); return nil
            case 126, 125: if let n = Int(typed) { typed = String(max(1, n + (e.keyCode == 126 ? 1 : -1))) }; refresh(); return nil
            case 123, 124: return nil
            default: break
            }
            if ch.count == 1, ch.first!.isNumber, typed.count < 4 { typed += ch; refresh(); return nil }
            return nil
        }
        // ↑ / ↓ on the clock: one minute up or down, exactly like the chevrons (a running block pauses first)
        if e.keyCode == 126 || e.keyCode == 125 {
            if running { pause() }
            step(e.keyCode == 126 ? up : down)
            return nil
        }
        if ch.count == 1, ch.first!.isNumber { typing = true; typed = ch; refresh(); return nil }
        return e
    }

    // "30" = 30 min focus (remembered); while the break is next, it sets the break length in minutes.
    func commitClock() {
        typing = false
        let input = typed
        typed = ""
        guard let m = Int(input), m > 0 else { refresh(); return }
        if doneBlock || runningBreak {
            setBreak(min(m, 60))
        } else {
            focus = TimeInterval(min(m, 999) * 60)
            store.set(focus, forKey: "focus")
        }
        refresh()
    }
}

// Menu bar: the word POMO, laid out horizontally. Each letter is a one-click length preset:
//   P 1 hour · O 25 min · M 15 min · O 5 min. The menu (click the · or right-click) has start/pause, pin, show, quit.
@MainActor
final class MenuBar: NSObject, NSApplicationDelegate {
    static let letters: [(String, Int)] = [("P", 60), ("O", 25), ("M", 15), ("O", 5)] // letter, minutes
    let item = NSStatusBar.system.statusItem(withLength: 58) // P O M O
    let menu = NSMenu()
    let clockItem = NSMenuItem(title: "25:00", action: nil, keyEquivalent: "")
    let toggleItem = NSMenuItem(title: "Start", action: #selector(startPause), keyEquivalent: "p")
    let pinItem = NSMenuItem(title: "Show countdown", action: #selector(togglePin), keyEquivalent: "")
    let autoItem = NSMenuItem(title: "Automatic rhythm", action: #selector(toggleAuto), keyEquivalent: "")
    let showItem = NSMenuItem(title: "Show Pomo", action: #selector(show), keyEquivalent: "")
    let resetItem = NSMenuItem(title: "Reset today's stats", action: #selector(resetStats), keyEquivalent: "")
    let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")

    func applicationDidFinishLaunching(_: Notification) {
        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(click)
        button.sendAction(on: [.leftMouseUp])
        watchRightClicks()
        button.image = nil
        button.attributedTitle = wordmark() // the letters themselves are the menu-bar item
        item.length = 58
        clockItem.isEnabled = false
        toggleItem.target = self
        pinItem.target = self
        autoItem.target = self
        resetItem.target = self
        showItem.target = self
        themeItem.submenu = themeMenuList() // presets with swatch icons, then Custom…
        let quitItem = NSMenuItem(title: "Quit Pomo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for m in [clockItem, toggleItem, .separator(), pinItem as NSMenuItem, autoItem, resetItem, themeItem, .separator(), showItem, quitItem] {
            menu.addItem(m)
        }
    }

    // P O M O, with the active length in the theme accent.
    func wordmark() -> NSAttributedString {
        let size = NSFont.systemFontSize(for: .small) + 1
        let font = NSFont.systemFont(ofSize: size + 1, weight: .semibold)
        let current = (NSApp.delegate as? AppDelegate).map { $0.doneBlock ? $0.breakMinutes : $0.focusMinutes } ?? 25
        let s = NSMutableAttributedString()
        for (ch, minutes) in MenuBar.letters {
            s.append(NSAttributedString(string: ch + " ", attributes: [
                .font: font,
                .foregroundColor: minutes == current ? C.accent : NSColor.labelColor,
            ]))
        }
        return s
    }

    // The status button reports right-clicks as .otherMouseUp through a Button action, or as Control subclasses:
    // catch the right-button press locally while the pointer is on the item, and open the menu ourselves.
    func watchRightClicks() {
        let monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .otherMouseDown]) { [weak self] e in
            guard let self, e.window === self.item.button?.window, let button = self.item.button,
                  button.convert(e.locationInWindow, from: nil).x >= 0, button.convert(e.locationInWindow, from: nil).x <= button.bounds.width,
                  button.convert(e.locationInWindow, from: nil).y >= 0, button.convert(e.locationInWindow, from: nil).y <= button.bounds.height else { return e }
            self.menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
            return nil
        }
        monitors.append(monitor as Any)
    }
    var monitors: [Any] = []

    // Left-click: the menu. Option-click: show/hide the panel.
    @objc func click() {
        let e = NSApp.currentEvent
        if e?.modifierFlags.contains(.option) == true {
            (NSApp.delegate as? AppDelegate)?.togglePanel()
            return
        }
        if let button = item.button { menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button) }
    }

    // A letter = a favourite length. When the break is next (or running), a small letter sets the 5 min break instead.
    func setLength(_ minutes: Int) {
        guard let d = NSApp.delegate as? AppDelegate else { return }
        if minutes == 5 && (d.doneBlock || d.runningBreak) { d.setBreak(5) } else { d.setRhythm(focus: minutes, break: minutes == 60 ? 10 : 5) }
        d.refresh()
    }

    func popMenu() { item.menu = menu; item.button?.performClick(nil); item.menu = nil }

    func update(running: Bool, isBreak: Bool, left: Int, title: String) {
        toggleItem.title = running ? (isBreak ? "End break" : "Pause") : title == "break ready" ? "Start break" : "Start timer"
        clockItem.title = title + " · " + C.theme.name
        guard let d = NSApp.delegate as? AppDelegate else { return }
        pinItem.state = d.pinnedCountdown ? .on : .off
        autoItem.state = d.autoFocus ? .on : .off
        themeItem.title = "Theme: " + C.theme.name
        for entry in themeItem.submenu?.items ?? [] where entry.action == #selector(pickTheme(_:)) {
            entry.state = (entry.representedObject as? String) == C.theme.name.lowercased() ? .on : .off
        }
        item.button?.attributedTitle = wordmark()
        item.button?.toolTip = "POMO · " + title
    }

    @objc func startPause() { (NSApp.delegate as? AppDelegate)?.toggle() }
    @objc func toggleAuto() {
        guard let d = NSApp.delegate as? AppDelegate else { return }
        d.autoFocus.toggle()
        d.store.set(d.autoFocus, forKey: "auto")
        d.refresh()
    }
    @objc func togglePin() {
        guard let d = NSApp.delegate as? AppDelegate else { return }
        d.setPinned(!d.pinnedCountdown)
    }
    @objc func show() { (NSApp.delegate as? AppDelegate)?.showPanel() }

    // One menu entry per palette, each with a 16pt swatch; the menu scrolls if the list grows.
    func themeMenuList() -> NSMenu {
        let themes = NSMenu()
        themes.autoenablesItems = false
        for p in C.presets {
            let entry = NSMenuItem(title: p.name + (p.bg2 != nil ? "  · dual" : ""), action: #selector(pickTheme(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = p.name.lowercased()
            entry.image = swatch(p, plus: false)
            themes.addItem(entry)
        }
        themes.addItem(.separator())
        let custom = NSMenuItem(title: "Custom…", action: #selector(customTheme), keyEquivalent: "")
        custom.target = self
        custom.image = swatch(nil, plus: true)
        themes.addItem(custom)
        return themes
    }

    // A tiny palette preview: the base tone (and its dual second half), accent and break dots.
    func swatch(_ p: Palette?, plus: Bool) -> NSImage {
        let img = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            let r = rect.insetBy(dx: 1, dy: 1)
            let circle = NSBezierPath(ovalIn: r)
            guard let p, !plus else {
                C.card.setFill(); circle.fill()
                circle.lineWidth = 1; C.dim.setStroke(); circle.stroke()
                let cross = NSBezierPath()
                cross.move(to: NSPoint(x: r.midX - 3.5, y: r.midY)); cross.line(to: NSPoint(x: r.midX + 3.5, y: r.midY))
                cross.move(to: NSPoint(x: r.midX, y: r.midY - 3.5)); cross.line(to: NSPoint(x: r.midX, y: r.midY + 3.5))
                cross.lineWidth = 1.4; C.dim.setStroke(); cross.stroke()
                return true
            }
            p.bg.setFill(); circle.fill()
            if let second = p.bg2 { // dual-tone: the lower half in the second colour
                NSGraphicsContext.saveGraphicsState()
                NSBezierPath(rect: NSRect(x: r.minX, y: r.minY, width: r.width, height: r.height / 2)).addClip()
                second.setFill(); circle.fill()
                NSGraphicsContext.restoreGraphicsState()
            }
            p.accent.setFill()
            NSBezierPath(ovalIn: NSRect(x: r.minX + 3, y: r.minY + 3, width: 6, height: 6)).fill()
            p.green.setFill()
            NSBezierPath(ovalIn: NSRect(x: r.maxX - 6, y: r.maxY - 6, width: 4.5, height: 4.5)).fill()
            return true
        }
        img.isTemplate = false
        return img
    }

    @objc func pickTheme(_ item: NSMenuItem) {
        (NSApp.delegate as? AppDelegate)?.applyTheme(item.representedObject as? String ?? "ember", accent: nil, bg: nil)
    }

    // Custom look: a colour well for the accent (and one for the background), applied live.
    // Combine your own look: background, card, accent, break and text colours, all live in one dialog.
    @objc func customTheme() {
        guard let d = NSApp.delegate as? AppDelegate else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Custom theme"
        alert.informativeText = "Top and Bottom make a dual-tone card; leave them equal for a flat one.\nAccent = clock, strip, active letter. Then Card, Break, Text."
        let wells: [(String, NSColor)] = [
            ("Top", C.bg), ("Bottom", C.theme.bg2 ?? C.bg), ("Card", C.card), ("Accent", C.accent), ("Break", C.green), ("Text", C.text),
        ]
        let box = NSView(frame: NSRect(x: 0, y: 0, width: 6 * 48, height: 62))
        var colorWells: [NSColorWell] = []
        for (i, (label, colour)) in wells.enumerated() {
            let well = NSColorWell(frame: NSRect(x: CGFloat(i) * 48, y: 26, width: 40, height: 24))
            well.color = colour
            let name = NSTextField(labelWithString: label)
            name.font = .systemFont(ofSize: 9)
            name.frame = NSRect(x: CGFloat(i) * 48, y: 6, width: 46, height: 14)
            box.addSubview(well)
            box.addSubview(name)
            colorWells.append(well)
        }
        alert.accessoryView = box
        alert.addButton(withTitle: "Apply")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        d.applyTheme("custom", accent: colorWells[3].color, bg: colorWells[0].color, bg2: colorWells[1].color,
                     card: colorWells[2].color, breakc: colorWells[4].color, textc: colorWells[5].color)
    }

    // Stats: "Reset today's stats" clears the tally after a one-click confirmation.
    @objc func resetStats() {
        guard let d = NSApp.delegate as? AppDelegate else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Reset today's stats?"
        alert.informativeText = "Clears today's pomos, focus minutes and done count. The to-do list is untouched."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        d.resetDay()
    }
}

// The wordmark, drawn: P O M O each 14pt wide, then a dot that opens the menu. Selected letter is accented;
// red while a focus block runs.

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    let menuBar = MenuBar() // retained for the app's lifetime
    menuBar.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    delegate.menuBar = menuBar
    app.run()
}
