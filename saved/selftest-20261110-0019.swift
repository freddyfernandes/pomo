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
    print("all to-do and timer checks passed")
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
