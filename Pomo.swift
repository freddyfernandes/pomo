// Pomo: always-on-top pomodoro + checklist. Build/run: ./build.sh
import AppKit

enum C {
    static let bg = NSColor(white: 0.065, alpha: 1)
    static let card = NSColor(white: 0.14, alpha: 1)
    static let control = NSColor(white: 0.2, alpha: 1)
    static let accent = NSColor(red: 0.95, green: 0.55, blue: 0.28, alpha: 1) // warm orange, used at rest and in focus
    static let green = NSColor(red: 0.42, green: 0.78, blue: 0.52, alpha: 1) // breaks only
    static let text = NSColor(white: 0.94, alpha: 1)
    static let dim = NSColor(white: 0.62, alpha: 1)
    static let faint = NSColor(white: 0.38, alpha: 1)
    static let hairline = NSColor(white: 1, alpha: 0.08)
    static let row = 24.0 // to-do row height
    static let width = 236.0
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

// Footer row: the whole strip is clickable (toggles today's stats); the Clear button on top still gets its clicks.
final class FooterRow: NSView {
    var onClick: (() -> Void)?
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool { true }
    override func mouseDown(with e: NSEvent) {
        guard !(hitTest(convert(e.locationInWindow, from: nil)) is NSButton) else { return }
        onClick?()
    }
}

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
        // rounded display face, black-weight: the only "funky" type in the panel
        let font = NSFont.systemFont(ofSize: 15, weight: .black).rounded
        let cell = bounds.width / 4
        for (i, (ch, minutes)) in Wordmark.letters.enumerated() {
            let selected = minutes == state.minutes
            let color: NSColor = selected ? C.accent : hovered == i ? C.text : state.running ? C.dim : NSColor(white: 0.62, alpha: 1)
            let s = NSAttributedString(string: ch, attributes: [.font: font, .foregroundColor: color, .kern: 2.5])
            let size = s.size()
            s.draw(at: NSPoint(x: CGFloat(i) * cell + (cell - size.width) / 2, y: (bounds.height - size.height) / 2))
            if selected { // a small underline under the active length
                C.accent.setFill()
                NSBezierPath(roundedRect: NSRect(x: CGFloat(i) * cell + cell / 2 - 6, y: 1, width: 12, height: 1.5), xRadius: 0.75, yRadius: 0.75).fill()
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

struct Todo { var id: Int; var text: String; var done: Bool }

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
    let foot = NSStackView()
    let leftLbl = NSTextField(labelWithString: "")
    lazy var clearBtn = self.pill("Clear completed", nil, wide: true)
    var list: NSScrollView!
    lazy var listHeight = list.heightAnchor.constraint(equalToConstant: CGFloat(rows) * C.row)
    let rows = 3 // min visible rows

    // Progress is one array rather than separate "done:X" keys: clearing can never desync the two.
    // Items are tracked by id, not by text: the same to-do twice is two rows, and no index goes stale on rebuild.
    var items: [Todo] = []
    var nextId = 1
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
        panel.appearance = NSAppearance(named: .darkAqua) // dark even in light mode
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

        focus = store.double(forKey: "focus")
        if let live = store.object(forKey: "handoffEnd") as? Date, live > Date(), !running { // quit while running: keep it
            end = live
            running = true
            runningBreak = store.bool(forKey: "handoffBreak")
            store.removeObject(forKey: "handoffEnd")
        }
        let todos = store.stringArray(forKey: "todos") ?? [] // older saves: names + "done:<name>" flags
        items = (store.array(forKey: "tasks") as? [[Any]] ?? []).compactMap { row in
            guard let t = row.first as? String else { return nil }
            return Todo(id: 0, text: t, done: (row.count > 1 ? row[1] as? Bool : nil) ?? store.bool(forKey: "done:" + t))
        }
        if items.isEmpty { items = todos.map { Todo(id: 0, text: $0, done: store.bool(forKey: "done:" + $0)) } }
        for i in items.indices { items[i].id = i } // ids must be unique; the old save format only had name + state
        nextId = items.count
        for t in todos { store.removeObject(forKey: "done:" + t) } // migrate once, then the old keys are gone
        store.removeObject(forKey: "todos")

        buildUI()
        autoHeight()
        if let s = NSScreen.main?.visibleFrame {
            panel.setFrameTopLeftPoint(NSPoint(x: s.maxX - panel.frame.width - 12, y: s.maxY - 12)) // top-right corner
        }
        panel.orderFrontRegardless()
        if pinnedCountdown { handOver() } // replace the old copy, keep its countdown
        autoFocus = store.bool(forKey: "auto")
        cycle = store.integer(forKey: cycleKey)
        day = (store.dictionary(forKey: dayKey) ?? [:])
        day["done"] = day["done"] as? Int ?? 0
        let savedBreak = Int(store.double(forKey: "break"))
        breakMinutes = (1...60).contains(savedBreak) ? savedBreak : 5
        paused = store.double(forKey: "paused")
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

    func windowShouldClose(_: NSWindow) -> Bool { panel.orderOut(nil); return false } // reopen from the menu bar

    // Click the menu bar icon: show the panel in its usual corner, or hide it. Either way nothing resets.
    func togglePanel() { pinToMenuBar() }

    var menuBar: MenuBar?
    var pinnedCountdown: Bool { store.bool(forKey: "pinMenuBar") } // see build.sh --pin / --unpin

    // Pinned mode keeps exactly one running copy. A newly launched instance asks the existing one to hand over:
    // it saves its live countdown on the way out, and this one adopts it before building its UI.
    // Shortcut: a hung old copy is force-quit after 1s, and the persisted pause state is used instead.
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
        stack.addArrangedSubview(bar)

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
        entry.isEditable = true
        entry.delegate = self
        entry.target = self
        entry.action = #selector(self.addTodo)
        entry.placeholderAttributedString = NSAttributedString(string: "  New to-do", attributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: C.faint])
        entry.widthAnchor.constraint(equalToConstant: C.width - 24).isActive = true
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

        // 5. footer: the tally line on the left (it is also the toggle for today's numbers), Clear completed right
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
        // Click anywhere on the footer row (except the button itself) to show/hide today's stats.
        let footRow = FooterRow() // plain view: whole row is a click target
        footRow.onClick = { [weak self] in self?.toggleStats() }
        footRow.widthAnchor.constraint(equalToConstant: C.width - 24).isActive = true
        footRow.addSubview(foot)
        NSLayoutConstraint.activate([
            foot.leadingAnchor.constraint(equalTo: footRow.leadingAnchor),
            foot.trailingAnchor.constraint(equalTo: footRow.trailingAnchor),
            foot.centerYAnchor.constraint(equalTo: footRow.centerYAnchor),
        ])
        stack.addArrangedSubview(footRow)

        // today's numbers: hidden until the footer is clicked, remembered
        statsWrap.orientation = .horizontal
        statsWrap.alignment = .centerX
        statsWrap.widthAnchor.constraint(equalToConstant: C.width - 24).isActive = true
        statsWrap.addArrangedSubview(statsLine)
        statsWrap.isHidden = !showStats
        stack.addArrangedSubview(statsWrap)

        let content = panel.contentView!
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 4),
            stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
        ])
        rebuildList()
    }
    let bar = DrainBar() // animated time-left strip
    let stateLabel = NSTextField(labelWithString: "")
    let mark = Wordmark() // POMO under the clock, each letter a length toggle

    // MARK: layout
    // Only the list drives its own height; the timer never resizes anything. The window follows the list,
    // pinned by its top edge, keeping a user-dragged height as a floor.
    func autoHeight() {
        let wanted = max(rows, items.count, dragRows)
        if listHeight.constant != CGFloat(wanted) * C.row { listHeight.constant = CGFloat(wanted) * C.row }
        let content = panel.contentView!
        content.layoutSubtreeIfNeeded()
        let height = stack.frame.height + stack.frame.minY + 10
        let top = panel.frame.maxY
        guard abs(panel.contentLayoutRect.height - height) > 0.5 else { return }
        panel.setContentSize(NSSize(width: content.frame.width, height: height))
        panel.setFrameTopLeftPoint(NSPoint(x: panel.frame.minX, y: top)) // corner stays put
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

    func windowDidResize(_: Notification) { // reaching past the to-dos: spring back (see windowDidEndLiveResize)
        sizeListContent()
    }

    func sizeListContent() { // scroll view documents get no layout pass of their own
        guard let doc = list.documentView else { return }
        doc.setFrameSize(NSSize(width: list.contentSize.width, height: listHost.fittingSize.height))
        listHost.layoutSubtreeIfNeeded() // now: rows get frames (deferred if called during layout)
        list.reflectScrolledClipView(list.contentView)
    }

    // MARK: to-dos
    func saveItems() {
        store.set(items.map { [$0.text, $0.done] }, forKey: "tasks") // id is just the row's position at save time
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

    func toggleItem(_ id: Int) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].done = !items[i].done
        if items[i].done { bump("done", 1) } // today's tally: each tick counts once
        saveItems()
        rebuildList()
    }

    func remove(_ id: Int) {
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
        items.append(Todo(id: nextId, text: text, done: false))
        nextId += 1
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
        if (e.keyCode == 126 || e.keyCode == 125), !typing, !running { step(e.keyCode == 126 ? up : down); return nil }
        if typing {
            switch e.keyCode {
            case 36, 76: commitClock(); return nil
            case 53, 51: typing = false; refresh(); return nil
            case 123...126: return nil
            default: break
            }
            if ch.count == 1, ch.first!.isNumber, typed.count < 4 { typed += ch; refresh(); return nil }
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
    let item = NSStatusBar.system.statusItem(withLength: 70) // the wordmark plus the menu chevron
    let length: CGFloat = 70
    let view = MenuBarView()
    let menu = NSMenu()
    let clockItem = NSMenuItem(title: "25:00", action: nil, keyEquivalent: "")
    let toggleItem = NSMenuItem(title: "Start", action: #selector(startPause), keyEquivalent: "p")
    let pinItem = NSMenuItem(title: "Show countdown", action: #selector(togglePin), keyEquivalent: "")
    let autoItem = NSMenuItem(title: "Automatic rhythm", action: #selector(toggleAuto), keyEquivalent: "")
    let showItem = NSMenuItem(title: "Show Pomo", action: #selector(show), keyEquivalent: "")

    func applicationDidFinishLaunching(_: Notification) {
        guard let button = item.button else { return }
        button.title = "" // subview only: AppKit hides custom subviews behind an image or title
        button.image = nil
        view.onLetter = { [weak self] minutes in self?.setLength(minutes) }
        view.onMenu = { [weak self] in self?.popMenu() }
        button.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: button.leadingAnchor), view.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            view.topAnchor.constraint(equalTo: button.topAnchor), view.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])
        clockItem.isEnabled = false
        toggleItem.target = self
        pinItem.target = self
        autoItem.target = self
        showItem.target = self
        for m in [clockItem, toggleItem, .separator(), pinItem as NSMenuItem, autoItem, .separator(), showItem,
                  NSMenuItem(title: "Quit Pomo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")] {
            menu.addItem(m)
        }
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
        clockItem.title = title
        guard let d = NSApp.delegate as? AppDelegate else { return }
        pinItem.state = d.pinnedCountdown ? .on : .off
        autoItem.state = d.autoFocus ? .on : .off
        view.state = MenuBarView.State(running: running, isBreak: isBreak, focusMinutes: d.doneBlock ? d.breakMinutes : d.focusMinutes, title: title)
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
}

// The wordmark, drawn: P O M O each 14pt wide, then a dot that opens the menu. Selected letter is accented;
// red while a focus block runs.
@MainActor
final class MenuBarView: NSView {
    struct State { var running = false; var isBreak = false; var focusMinutes = 25; var title = "" }
    var state = State() { didSet { needsDisplay = true } }
    var onLetter: ((Int) -> Void)?
    var onMenu: (() -> Void)?
    private var hovering = false { didSet { needsDisplay = true } }
    private var tracking: NSTrackingArea?
    private let letterWidth: CGFloat = 15

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        tracking.map(removeTrackingArea)
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(t)
        tracking = t
    }
    override func mouseEntered(with _: NSEvent) { hovering = true }
    override func mouseExited(with _: NSEvent) { hovering = false }

    // Drawn as text, not an image: on a dark menu bar it stays legible, and the O of the current length is orange.
    override func draw(_ rect: NSRect) {
        let font = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
        let base = hovering ? NSColor.labelColor : NSColor(white: 0.92, alpha: 1)
        var x: CGFloat = 6
        for (ch, minutes) in MenuBar.letters {
            let isCurrent = minutes == state.focusMinutes
            let color = isCurrent ? C.accent : state.running && !state.isBreak ? NSColor(white: 0.55, alpha: 1) : base
            NSAttributedString(string: ch, attributes: [.font: font, .foregroundColor: color]).draw(at: NSPoint(x: x, y: 2))
            x += letterWidth
        }
        NSAttributedString(string: "⌄", attributes: [.font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                                                     .foregroundColor: NSColor(white: 0.6, alpha: 1)])
            .draw(at: NSPoint(x: x + 3, y: 2))
    }
    override func mouseDown(with e: NSEvent) {
        let x = convert(e.locationInWindow, from: nil).x - 6
        if x >= letterWidth * 4 { onMenu?(); return }
        onLetter?(MenuBar.letters[max(0, min(3, Int(x / letterWidth)))].1)
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    let menuBar = MenuBar() // retained for the app's lifetime
    menuBar.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    delegate.menuBar = menuBar
    app.run()
}
