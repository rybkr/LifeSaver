# UnixLife

A Swift macOS screensaver that builds a Unix timestamp from white cells, ticks for 20 seconds, and evolves it with Conway’s Game of Life. Targets macOS 26.4 or later (the installed Xcode SDK).

## Build and try

```sh
make install
```

`make install` builds, backs up the installed bundle, installs the new version, and stops only your UnixLife screensaver hosts so macOS loads the new code. This avoids stale previews after replacing a bundle. You can also open the built `.saver` manually, but restart the screensaver host if a preview still shows old behavior. Select UnixLife in System Settings and use its options to configure the clock duration, generations per second, evolution timeout, and cell size. `make build` signs locally with an ad-hoc identity; distribution would need Developer ID signing and notarization.

The Makefile uses `/Applications/Xcode.app/Contents/Developer` without changing your system’s selected developer directory. Override `DEVELOPER_DIR` if Xcode lives elsewhere.

## Behavior

- A 0.9-second assembly draws rows of cells inward from alternating sides, locking them into solid block numerals, followed by a 20-second live clock by default (configurable from 0–60 seconds).
- The Unix timestamp rolls only the digits that change, using a clipped 0.32-second counter motion. Unchanged digits stay stationary; the complete clock is solid and still between ticks. No Life generations run during this phase. The last tick completes before the transition to Life. Durations of one second or less display the initial timestamp without ticking.
- After the full clock phase, a 0.7-second transition opens narrow gutters between the cells, then Life begins. Cell births and deaths fade briefly between generations; at the next cycle, the remaining cells dissolve as the new clock appears. The composition stays centered on pure black, without labels or decoration.
- The macOS Reduce Motion preference skips assembly, digit rolls, cell separation, and generation fade effects; Life continues at the configured rate.
- This version starts existing installations at the new 20-second clock default while preserving Life speed, timeout, and cell size.
- B3/S23 evolution at 12 generations per second, with a 30-second evolution timeout.
- Six-point cells by default; timestamp glyphs scale to roughly half the display width, quantized to whole cells. Preview rendering scales down the same composition.
- A 16-cell simulation margin on every side. Cells there evolve normally; everything outside the finite world is dead.
- Immediately start the next reveal when no visible cells remain, a repeated world state is detected, or the evolution timeout expires.
- Repeat detection stores a compact snapshot of every world state, including the offscreen margin, in a hash table. Exact equality guards against hash collisions. A still life or oscillator ends on its first repeated state. Moving spaceships are not considered repeats. Snapshot storage has a 32 MiB budget (including an allowance for entries); reaching it starts a new cycle instead of forgetting earlier states.

## Design and validation

`UnixLife/Core` contains the platform-independent finite Life world, deterministic bitmap digits, validated settings, and cycle state machine. The cycle accepts monotonic animation time and wall-clock Unix time separately, so clock changes cannot stall the simulation. Callback catch-up work is bounded.

`UnixLifeView` adapts the core to Apple’s [ScreenSaverView](https://developer.apple.com/documentation/screensaver/screensaverview) lifecycle and AppKit drawing. Settings persistence and the native configuration sheet are separate from simulation and rendering. No third-party dependencies.

```sh
make test
```

The Swift package tests cover still lifes, oscillators, gliders, finite edges, timestamp placement, timing, long holds, invalid preferences, the 20-second clock phase, a motionless clock phase, and reduced-motion presentation. The Xcode project builds the actual `.saver` bundle.

`make smoke` loads the built bundle through its declared principal class and renders `build/preview.png` without installation. This checks bundle loading and drawing; installation, configuration-sheet interaction, and playback in the macOS screensaver host still need a manual check.

`make verify` exercises the actual bundle for 23 seconds and asserts a full 20-second clock phase before Life. It expects the default 20-second clock duration. The settings now round clock duration to whole seconds.

`make motion` renders a deterministic four-second animation study to `build/clock-motion.gif` using the production renderer.
