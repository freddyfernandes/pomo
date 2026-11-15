# Pomo

A minimal always-on-top pomodoro and checklist for macOS. One Swift file, no dependencies.

<p align="center"><img width="325" height="450" alt="Pomo" src="https://github.com/user-attachments/assets/e826ab18-9bb5-4302-9d29-4213ad141b05" /></p>

## Use

- Click the clock to start, pause or resume. ⌥-click restarts.
- **POMO** under the clock picks a length: **P** 1 hr · **O** 25 min · **M** 15 min · **O** 5 min.
  The same word sits in the menu bar; ⌄ opens the menu (start/pause, automatic rhythm, reset stats, quit).
- Focus ends → 5 min break → next focus, when *Automatic rhythm* is on.
  The orange strip drains toward the centre as time runs out (green on breaks).
- Type a to-do in the field and press ⏎. Click a row to tick it, × to delete, *Clear completed* to tidy up.
- Click the footer line (`1/4 done`) for today's tally: `2 pomos · 50m focus · 3 done`.
- Pause keeps its place, even after quitting.

## Run it

Needs macOS 12+ and Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/freddyfernandes/pomo && cd pomo
./build.sh           # builds build/Pomo.app and opens it
./build.sh --pin     # optional: start at login, countdown in the menu bar
./build.sh --unpin   # undo
```

Settings live in `defaults` domain `local.pomo`; `defaults delete local.pomo` resets everything.

### Looks

Menu bar → **Theme**: `Ember` (default, warm orange on near-black), `Slate` (cool blue-grey),
`Forest` (green), `Sakura` (pink), `Paper` (light), or **Custom…** to pick an accent and background colour.
The choice is saved. From a shell: `defaults write local.pomo theme slate` (or `accent "#33CC99"` for any theme).

### Windows (overlay)

A native Windows overlay lives in [`windows/`](windows): one C# file, drawn with the Windows Forms that
ships with Windows 10/11 — no SDK, no installs.

```powershell
git clone https://github.com/freddyfernandes/pomo && cd pomo\windows
powershell -ExecutionPolicy Bypass -File build.ps1   # builds Pomo.exe and starts it
```

Same card in the top-right, above other windows: click the clock to start/pause, click **P O M O** for
1 hr / 25 / 15 / 5 min, type a to-do and press Enter, click a row to tick it or its right edge to delete,
click the footer line for today's tally. Drag the top area to move it, Esc quits.

## Develop

```sh
swift selftest.swift   # headless checks: to-dos, timer, strip, tally, robustness
```

## License

© 2026 Freddy Fernandes. All rights reserved. Not open source; see [LICENSE](LICENSE).
