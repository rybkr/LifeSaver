# LifeSaver

A native macOS screensaver where two small neural networks compete in a two-color Game of Life. Players evolve locally while the screensaver runs. No downloaded models, API keys, network requests, or third-party dependencies. Targets macOS 26.4 or later.

## Build and try

```sh
make install
```

Select **LifeSaver** in System Settings. Options control simulation speed and background learning. The system preview shows matches without training. Full-screen windows in the same host share one simulation worker; a file lock permits only one training writer across hosts.

`make build` creates `build/Build/Products/Release/LifeSaver.saver` with ad-hoc signing. Distribution requires Developer ID signing and notarization. The Makefile uses `/Applications/Xcode.app/Contents/Developer`; override `DEVELOPER_DIR` if needed.

The installer backs up an existing LifeSaver bundle before replacement. It also archives an old UnixLife installation after installing LifeSaver, and stops only this user's screensaver hosts that have loaded either bundle. The repository's containing folder is not renamed.

## The game

- A fixed 32×24 finite board. Amber uses rounded glass tiles; Blue uses glass droplets. Nothing wraps.
- Both colonies start with mirrored, equally populated patterns, including a small stable core.
- Standard B3/S23: a live cell survives with two or three neighbors of either color. An empty cell with three neighbors is born with their majority color. Survivors keep their color.
- Every eight generations, each player can place up to three cells in empty locations adjacent to its pre-move population. Each network re-evaluates after its own proposed placements, but the legal region stays fixed for that turn.
- Both players choose independently from the same board. Moves apply simultaneously; overlapping claims cancel. A placement can die in the immediately following Life generation.
- Eliminate the opponent to win immediately. Otherwise, matches end after 1,000 generations and the higher average population wins. Simultaneous extinction is a draw.
- The winner remains visible for three seconds, then a fresh match begins. Newly selected networks join the next match; weights never change mid-match.
- The display contains only amber and blue cells on pure black, with subtle glass shading. There are no labels, grid lines, or borders. Reduce Motion disables birth/death fades.

## Neural networks and evolution

Each policy is a three-layer convolutional network: 3 input channels (own cells, enemy cells, valid board), three 3×3 layers with 16 channels each and ReLU activations, then a 1×1 placement-score head. It has **5,105 Float parameters, about 20 KiB of weights**, and a 7×7 receptive field. Legal-move masking belongs to the game, not the learned policy. Swift SIMD handles inference on the CPU; there is no GPU or ML framework requirement.

Evolution uses 32 candidates. Every candidate plays the same four trials per round: two seeded boards, each with sides swapped, against the incumbent and an archived opponent. Fitness is average `(our cells − enemy cells)` over the match. For early extinction, the final difference is held through the remaining evaluation horizon. The top four survive unchanged; mutated copies fill 27 slots, and one new random network provides diversity. The last four champions are retained as opponents.

Players start random. Selection running successfully is not evidence of strong play. This is a runtime evolution experiment; defensive strategies, stagnation, and weak long-range planning are expected possibilities. Fitness is relative to the round's opponents and is not a globally comparable skill rating.

### Resource use and persistence

One utility-priority worker runs both visible simulation and training. Training works in roughly 8 ms chunks, then rests for four times its training work duration: approximately 20% of one worker's time **plus** visible-match and rendering work. A neural move is not preemptible, so this is a duty-cycle target, not a hard CPU cap. No training occurs when only previews remain, when disabled in settings, or after the screensaver stops.

Selected populations are atomically saved to `~/Library/Application Support/LifeSaver/evolution.plist`; a sibling `training.lock` prevents concurrent writers. Checkpoints include population, champions, archive, random state, and counters. They are saved after selection, periodically, and on orderly shutdown. Incomplete evaluation rounds restart when reloaded. Abrupt host termination can lose work since the last save. Invalid checkpoints are rejected; storage errors remain available in the internal session status for diagnostics.

## Validation and previews

```sh
make test           # deterministic rules, neural inference, evolution, and checkpoint tests
make smoke          # load the real bundle and render build/preview.png
make verify         # bundle animation, settings creation, stop, and restart
make runtime-check  # accelerated training, exclusive writer, pause, save, and restore in build/
make benchmark     # 10-second unthrottled throughput sample; does not save training
make motion        # 10-second deterministic GIF of initially untrained players
```

The animation is written to `build/lifesaver-motion.gif`. Runtime checks use isolated checkpoint directories under `build/`, not your saved learning. Automated checks do not replace testing full-screen playback and settings interaction in the real macOS host.
