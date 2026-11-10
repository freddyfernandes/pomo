# Pomo

A minimal always-on-top pomodoro and checklist for macOS. One Swift file, AppKit only, no dependencies.

## Use

- Click the clock to start, pause or resume. ⌥-click restarts.
- **POMO** under the clock picks a length: **P** 1 hr · **O** 25 min · **M** 15 min · **O** 5 min.
  The same word sits in the menu bar; ⌄ opens the menu (start/pause, reset stats, quit).
- Focus ends → 5 min break → next focus, when *Automatic rhythm* is on. The orange strip drains toward
  the centre as time runs out (green on breaks).
- Type a to-do in the field and press ⏎. Click a row to tick it, × to delete, *Clear completed* to tidy up.
- Click the footer line (`1/4 done`) for today's tally: `2 pomos · 50m focus · 3 done`. Reset from the menu bar.
- Pause keeps its place, even after quitting.

## Run it

Needs macOS 12+ and Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/freddyfernandes/pomo && cd pomo
./build.sh           # builds build/Pomo.app and opens it
./build.sh --pin     # optional: start at login, countdown in the menu bar
./build.sh --unpin   # undo
```

Settings live in `defaults` domain `local.pomo`.

## Develop

```sh
swift selftest.swift   # headless checks: to-dos, timer, time-left strip, daily tally
```

## License

© 2026 Freddy Fernandes. All rights reserved. Not open source; see [LICENSE](LICENSE).
