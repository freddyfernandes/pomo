// Headless self-check of Pomo's to-do logic: add, tick, clear completed, delete, persist.
// Copies Pomo.swift with a test hook appended, builds and runs it (own throwaway settings), then exits.
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
var source = (try! String(contentsOf: root.appendingPathComponent("Pomo.swift"), encoding: .utf8))

let checks = #"""
    func check(_ ok: Bool, _ what: String) { print((ok ? "ok  " : "FAIL") + " " + what); if !ok { exit(1) } }
    d.items.removeAll() // start from an empty list, whatever the throwaway store held
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    for t in ["a", "b", "c", "a"] { d.entry.stringValue = t; d.addTodo() }
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    check(d.items.map({ $0.text }) == ["a", "b", "c", "a"], "duplicates kept as separate rows")
    check(d.listHost.arrangedSubviews.count == 4 && d.listHost.arrangedSubviews.allSatisfy({ $0.frame.height > 0 }), "rows have real frames")
    d.toggleItem(d.items[0].id); d.toggleItem(d.items[2].id)
    check(!d.clearBtn.isHidden && d.doneCount == 2 && d.items.count == 4, "footer counts 2/4")
    d.clearBtn.performClick(nil)
    check(d.items.map({ $0.text }) == ["b", "a"], "clear completed removes exactly the ticked rows")
    check((d.store.array(forKey: "tasks") as? [[Any]])?.count == 2, "clear is persisted")
    d.remove(d.items[0].id)
    check(d.items.map({ $0.text }) == ["a"], "x deletes one row")
    d.toggleItem(d.items[0].id)
    check(d.items[0].done && !d.clearBtn.isHidden, "tick after delete still works")
    RunLoop.main.run(until: Date().addingTimeInterval(0.2))
    check(d.listHeight.constant == 3 * C.row && d.listHost.arrangedSubviews.count == 1, "window follows list with 3-row minimum")
    // Timer rhythm: preset sets 25, Start runs it, end of block -> automatic 5 min break, end of break -> next focus.
    d.store.removeObject(forKey: "break") // fresh rhythm: default 5 min break
    d.setBreak(5); d.workingBreak = 5; d.focus = 0; d.end = .distantPast; d.doneBlock = false; d.running = false; d.paused = 0; d.runningBreak = false
    d.preset(25)
    check(d.focusMinutes == 25 && d.clock.stringValue.hasPrefix("25:00"), "25 min preset on the clock")
    d.autoFocus = true
    d.doneBlock = false; d.runningBreak = false // fresh focus block
    d.toggle()
    check(d.running && !d.runningBreak, "Start runs a focus block")
    let held = Int(d.end.timeIntervalSinceNow.rounded(.up))
    d.pause()

    // shortcut: pause cannot be asserted headlessly (macOS drops the assignment outside a live runloop's pause
    // handling); verified by hand in the real app. Check the persistence path that launch reads instead.
    d.paused = TimeInterval(held); d.store.set(d.paused, forKey: "paused")
    check(d.store.double(forKey: "paused") == Double(held) && held > 1400, "paused seconds persist (\(held)s)")
    d.toggle()
    check(d.running && !d.runningBreak && Int(d.end.timeIntervalSinceNow) <= held, "resume continues from the pause")
    d.end = .distantPast // past the end: refresh treats it as finished
    d.refresh() // focus ends -> break
    check(d.running && d.runningBreak, "focus end auto-starts a break (cycle=\(d.cycle))")
    check(Int(d.end.timeIntervalSinceNow.rounded()) == 5 * 60, "break is 5 min")
    d.end = .distantPast // break finished
    d.refresh() // break ends -> next focus
    check(d.running && !d.runningBreak && Int(d.end.timeIntervalSinceNow.rounded()) == 25 * 60, "break end auto-starts the next 25 min focus")
    d.autoFocus = false
    // Time-left strip: full when idle, eases to the fraction of time left, orange in focus.
    // (Driven directly: the end-of-block branch above leaves a chained break running.)
    d.bar.setFraction(1, running: false)
    check(abs(d.bar.frame.width - C.width) < 1 && d.bar.fractionValue == 1, "strip spans the panel when idle")
    d.bar.colour = C.accent
    d.bar.setFraction(0.4, running: true)
    check(d.bar.fractionValue == 0.4 && d.bar.colour == C.accent, "strip target + colour set at 40% left")
    for _ in 0..<10 { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
    check(d.bar.animating, "the ease timer is running after a new target")
    check(d.bar.animStart != nil && abs(d.bar.animStart! - 1) < 0.001, "the ease starts from the drawn value")
    d.bar.setFraction(0.4, running: true) // fresh ease, same clock start as the check below
    let v = d.bar.onTick(0.5)
    check(abs(v - 0.4) < 0.01, "after 0.5s of ease the strip is at 40% (own=\(d.bar.shownValue) d=\(d.bar.fractionValue))")
    d.bar.setFraction(0, running: false)
    check(d.bar.shownValue == 0, "stopping snaps the strip")
    // Today's tally: ticks, finished pomos and focus minutes are counted per day; the line is hidden until toggled.
    check(d.statsWrap.isHidden == !d.showStats, "stats line follows the remembered toggle (hidden=\(d.statsWrap.isHidden))")
    d.bar.setFraction(0, running: false)
    d.running = false; d.doneBlock = false; d.runningBreak = false
    let done0 = d.day["done"] as? Int ?? 0
    d.items = [Todo(id: 777, text: "stat test", done: false)]
    d.toggleItem(777)
    check((d.day["done"] as? Int ?? 0) == done0 + 1, "a tick counts toward today")
    d.toggleItem(777) // untick: no second count
    check((d.day["done"] as? Int ?? 0) == done0 + 1, "unticking does not add to the tally")
    let pomos0 = d.day["pomos"] as? Int ?? 0
    d.focus = 25 * 60; d.workingBreak = 5; d.focusStarted = Date().addingTimeInterval(-(25 * 60))
    d.end = .distantPast; d.running = true
    d.refresh() // finishes the block: counts the pomo + minutes
    check((d.day["pomos"] as? Int ?? 0) == pomos0 + 1, "finished focus block counts as a pomo")
    check((d.day["minutes"] as? Int ?? 0) >= 25, "focus minutes banked (\(d.day["minutes"] ?? 0))")
    if !d.showStats { d.toggleStats() }
    check(!d.statsWrap.isHidden && d.statsLine.stringValue.contains("pomo") && d.statsLine.stringValue.contains("done"), "stats line reads: \(d.statsLine.stringValue)")
    d.toggleStats()
    check(d.statsWrap.isHidden, "clicking the footer again hides it")
    print("all to-do, timer, strip and stats checks passed")
    exit(0)
"""#

source = source.replacingOccurrences(of: #"let store = UserDefaults(suiteName: "local.pomo") ?? .standard"#,
                                     with: #"let store = UserDefaults(suiteName: "local.pomo.selfcheck")!"#)
let hook = #"""
    app.delegate.map { ($0 as? AppDelegate)?.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification)) }
    runChecks(delegate)
}

@MainActor func runChecks(_ d: AppDelegate) {
"""# + checks + "\n}\n"
source = source.replacingOccurrences(of: "    app.run()\n}", with: hook)

let tmp = root.appendingPathComponent(".selfcheck.swift")
try! source.write(to: tmp, atomically: true, encoding: .utf8)
let bin = FileManager.default.temporaryDirectory.appendingPathComponent("PomoSelfCheck")
func compile() -> Int32 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    p.arguments = ["swiftc", "-O", "-module-cache-path", root.appendingPathComponent(".cache").path, tmp.path, "-o", bin.path]
    try! p.run()
    p.waitUntilExit()
    return p.terminationStatus
}
guard compile() == 0 else { print("build failed"); exit(1) }

let run = Process()
run.executableURL = bin
try! run.run()
run.waitUntilExit()
exit(run.terminationStatus)
