import Testing
@testable import UnixLifeCore

private func cells(_ pairs: [(Int, Int)]) -> Set<Cell> {
    Set(pairs.map { Cell(x: $0.0, y: $0.1) })
}

@Test func stillLifeRemainsStable() {
    let seed = cells([(2,2), (2,3), (3,2), (3,3)])
    var board = LifeBoard(width: 8, height: 8, cells: seed)
    board.step()
    #expect(board.cells == seed)
    var detector = RepeatDetector(initial: seed)
    let repeated = detector.observe(board.cells)
    #expect(repeated)
}

@Test func blinkerIsDetectedWithoutConfusingItsFirstGeneration() {
    let seed = cells([(2,3), (3,3), (4,3)])
    var board = LifeBoard(width: 8, height: 8, cells: seed)
    var detector = RepeatDetector(initial: seed)
    board.step()
    #expect(board.cells == cells([(3,2), (3,3), (3,4)]))
    let firstRepeat = detector.observe(board.cells)
    #expect(!firstRepeat)
    board.step()
    #expect(board.cells == seed)
    let repeated = detector.observe(board.cells)
    #expect(repeated)
}

@Test func gliderMovesAndDoesNotCountAsAnExactRepeat() {
    let seed = cells([(2,1), (3,2), (1,3), (2,3), (3,3)])
    var board = LifeBoard(width: 12, height: 12, cells: seed)
    var detector = RepeatDetector(initial: seed)
    for _ in 0..<4 {
        board.step()
        let firstRepeat = detector.observe(board.cells)
        #expect(!firstRepeat)
    }
    #expect(board.cells == Set(seed.map { Cell(x: $0.x + 1, y: $0.y + 1) }))
}

@Test func finiteWorldDoesNotWrapAndIsolatedCellsDie() {
    var board = LifeBoard(width: 5, height: 5, cells: cells([(0,0), (0,1), (0,2), (-1,1)]))
    board.step()
    #expect(board.cells == cells([(0,1), (1,1)]))
    var isolated = LifeBoard(width: 5, height: 5, cells: cells([(2,2)]))
    isolated.step()
    #expect(isolated.cells.isEmpty)
}

@Test func timestampFitsAndIsCentered() {
    let seed = TimestampPattern.cells(timestamp: 1_800_000_000, columns: 240, rows: 135, margin: 16)
    #expect(!seed.isEmpty)
    #expect(seed.allSatisfy { $0.x >= 16 && $0.x < 256 && $0.y >= 16 && $0.y < 151 })
    let middleX = Double(seed.map(\.x).min()! + seed.map(\.x).max()!) / 2
    #expect(abs(middleX - 135.5) <= 2)
}

@Test func cycleHoldsThenEvolvesAndRestartsAtTimeout() {
    var cycle = SaverCycle(columns: 240, rows: 135,
                           settings: SaverSettings(clockDuration: 0.75, evolutionDuration: 1), now: 0, unixTime: 100)
    #expect(cycle.phase == .building)
    cycle.advance(now: SaverCycle.buildDuration, unixTime: 100)
    #expect(cycle.phase == .holding)
    cycle.advance(now: 1.64, unixTime: 101)
    #expect(cycle.timestamp == 100)
    #expect(cycle.phase == .holding)
    cycle.advance(now: 1.66, unixTime: 101)
    #expect(cycle.phase == .releasing)
    cycle.advance(now: 2.37, unixTime: 102)
    #expect(cycle.phase == .evolving)
    cycle.advance(now: 3.38, unixTime: 102)
    #expect(cycle.phase == .building)
    #expect(cycle.timestamp == 102)
}

@Test func longHoldUpdatesWallClockWithoutResettingHold() {
    var cycle = SaverCycle(columns: 240, rows: 135,
                           settings: SaverSettings(clockDuration: 2), now: 0, unixTime: 100)
    cycle.advance(now: SaverCycle.buildDuration, unixTime: 100)
    cycle.advance(now: 1, unixTime: 101)
    #expect(cycle.timestamp == 101)
    cycle.advance(now: 2.91, unixTime: 102)
    #expect(cycle.phase == .holding)
    cycle.advance(now: 3.24, unixTime: 102)
    #expect(cycle.phase == .releasing)
    #expect(cycle.timestamp == 102)
}

@Test func settingsRejectInvalidPersistedValues() {
    let settings = SaverSettings(clockDuration: .nan, generationsPerSecond: 0,
                                 evolutionDuration: .infinity, cellSize: -20)
    #expect(settings.clockDuration == 20)
    #expect(settings.generationsPerSecond == 1)
    #expect(settings.evolutionDuration == 30)
    #expect(settings.cellSize == 3)
}

@Test func defaultClockTicksForTwentySecondsBeforeLife() {
    var cycle = SaverCycle(columns: 240, rows: 135, settings: SaverSettings(), now: 0, unixTime: 100)
    cycle.advance(now: SaverCycle.buildDuration, unixTime: 100)
    for second in 1...20 {
        cycle.advance(now: Double(second), unixTime: Int64(100 + second))
        #expect(cycle.phase == .holding)
        #expect(cycle.timestamp == Int64(100 + second))
    }
    cycle.advance(now: 20.91, unixTime: 120)
    #expect(cycle.phase == .releasing)
    cycle.advance(now: 21.62, unixTime: 121)
    #expect(cycle.phase == .evolving)
    #expect(cycle.board.cells == TimestampPattern.cells(timestamp: 120, columns: 240, rows: 135, margin: 16))
}

@Test func clockSettlesBetweenTicksAndNeverRunsLifeDuringHold() {
    var cycle = SaverCycle(columns: 240, rows: 135, settings: SaverSettings(),
                           now: 0, unixTime: 1_800_000_009)
    cycle.advance(now: SaverCycle.buildDuration, unixTime: 1_800_000_009)
    for second in 1...19 {
        let timestamp = Int64(1_800_000_009 + second)
        cycle.advance(now: Double(second), unixTime: timestamp)
        let expected = TimestampPattern.cells(timestamp: timestamp, columns: 240, rows: 135, margin: 16)
        #expect(cycle.phase == .holding)
        #expect(cycle.board.cells == expected)
        for fraction in [0.4, 0.6, 0.9] {
            let now = Double(second) + fraction
            cycle.advance(now: now, unixTime: timestamp)
            let layers = ClockPresentation.layers(for: cycle, now: now, reduceMotion: false)
            #expect(layers.count == 1)
            #expect(layers[0].cells == expected)
            #expect(layers[0].verticalScale == 1)
            #expect(layers[0].opacity == 1)
            #expect(layers[0].separation == 0)
        }
    }
}

@Test func reducedMotionShowsTheCompleteCurrentClock() {
    var cycle = SaverCycle(columns: 240, rows: 135, settings: SaverSettings(), now: 0, unixTime: 100)
    let building = ClockPresentation.layers(for: cycle, now: 0, reduceMotion: true)
    #expect(Set(building.flatMap(\.cells)) == cycle.board.cells)
    #expect(building.allSatisfy { $0.verticalScale == 1 })
    cycle.advance(now: SaverCycle.buildDuration, unixTime: 100)
    cycle.advance(now: 1, unixTime: 101)
    let ticking = ClockPresentation.layers(for: cycle, now: 1.12, reduceMotion: true)
    #expect(Set(ticking.flatMap(\.cells)) == cycle.board.cells)
    #expect(ticking.allSatisfy { $0.verticalScale == 1 })
}

@Test func historyDetectsAnyEarlierStateAndResetsForNewRuns() {
    let a = cells([(1,1), (1,2)])
    let b = cells([(2,1), (2,2)])
    let c = cells([(3,1), (3,2)])
    var history = RepeatDetector(initial: a)
    let firstB = history.observe(b)
    let firstC = history.observe(c)
    let repeatedB = history.observe(b)
    #expect(!firstB && !firstC && repeatedB)
    var newRun = RepeatDetector(initial: c)
    let newB = newRun.observe(b)
    #expect(!newB)
}

@Test func historyBudgetCannotGrowWithoutBound() {
    var history = RepeatDetector(initial: cells([(1,1)]), byteLimit: 136)
    let repeated = history.observe(cells([(1,1)]))
    #expect(repeated)
    let newState = history.observe(cells([(2,2)]))
    #expect(!newState)
    #expect(history.isFull)
}

@Test func transitionRevealsCellsWithoutEvolvingTheSeed() {
    var cycle = SaverCycle(columns: 240, rows: 135, settings: SaverSettings(), now: 0, unixTime: 100)
    cycle.advance(now: SaverCycle.buildDuration, unixTime: 100)
    cycle.advance(now: 20.91, unixTime: 120)
    cycle.advance(now: 21.24, unixTime: 120)
    let seed = cycle.board.cells
    cycle.advance(now: 21.59, unixTime: 121)
    #expect(cycle.phase == .releasing)
    #expect(cycle.board.cells == seed)
    let layers = ClockPresentation.layers(for: cycle, now: 21.59, reduceMotion: false)
    #expect(layers.count == 1)
    #expect(abs(layers[0].separation - 0.5) < 0.001)
    #expect(layers[0].cells == seed)
}

@Test func rollingDigitsClipOnlyTheChangedPositions() {
    var cycle = SaverCycle(columns: 240, rows: 135, settings: SaverSettings(), now: 0, unixTime: 1_800_000_009)
    cycle.advance(now: SaverCycle.buildDuration, unixTime: 1_800_000_009)
    cycle.advance(now: 1, unixTime: 1_800_000_010)
    let layers = ClockPresentation.layers(for: cycle, now: 1.16, reduceMotion: false)
    #expect(layers.filter { $0.clip != nil }.count == 4)
    #expect(layers.filter { $0.clip == nil && $0.offsetY == 0 }.count == 8)
    #expect(layers.allSatisfy { $0.separation == 0 })
    #expect(cycle.board.cells == TimestampPattern.cells(timestamp: 1_800_000_010, columns: 240, rows: 135, margin: 16))
}

@Test func assembledDigitsEndExactlyOnTheClockSeed() {
    let cycle = SaverCycle(columns: 240, rows: 135, settings: SaverSettings(), now: 0, unixTime: 1_800_000_000)
    let midway = ClockPresentation.layers(for: cycle, now: 0.4, reduceMotion: false)
    #expect(midway.contains { $0.offsetX != 0 && $0.opacity > 0 })
    let finished = ClockPresentation.layers(for: cycle, now: SaverCycle.buildDuration, reduceMotion: false)
        .filter { $0.opacity > 0 }
    #expect(Set(finished.flatMap(\.cells)) == cycle.board.cells)
    #expect(finished.allSatisfy { abs($0.offsetX) < 0.0001 && abs($0.offsetY) < 0.0001 && abs($0.opacity - 1) < 0.0001 })
}
