import Foundation
import Darwin

/// One checkpoint writer across screensaver processes; atomic replacement protects readers.
private final class CheckpointStore {
    let directory: URL
    private var descriptor: Int32 = -1
    var ownsLock: Bool { descriptor >= 0 }
    private(set) var error: String?

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LifeSaver", isDirectory: true)
    }
    deinit { release() }
    func acquire() -> Bool {
        if ownsLock { return true }
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        catch { self.error = "Learning cannot be saved"; return false }
        let fd = open(directory.appendingPathComponent("training.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { error = "Learning cannot be saved"; return false }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { close(fd); return false }
        descriptor = fd
        return true
    }
    func release() {
        if descriptor >= 0 { flock(descriptor, LOCK_UN); close(descriptor); descriptor = -1 }
    }
    func load() -> EvolutionCheckpoint? {
        let url = directory.appendingPathComponent("evolution.plist")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size < 16 * 1024 * 1024 else { error = "Saved learning is invalid"; return nil }
            let checkpoint = try PropertyListDecoder().decode(EvolutionCheckpoint.self, from: Data(contentsOf: url))
            guard checkpoint.isValid else { error = "Saved learning is invalid"; return nil }
            return checkpoint
        } catch { self.error = "Saved learning is unreadable"; return nil }
    }
    func save(_ checkpoint: EvolutionCheckpoint) {
        guard ownsLock else { return }
        do {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            try encoder.encode(checkpoint).write(to: directory.appendingPathComponent("evolution.plist"), options: .atomic)
            error = nil
        } catch { self.error = "Learning could not be saved" }
    }
}

/// All windows in one host share this worker. Preview windows never enable training.
@MainActor
final class SimulationSession {
    static let shared = SimulationSession()
    private(set) var snapshot = ArenaSnapshot.initial()
    private var clients: [UUID: Bool] = [:]
    private var settings = SaverSettings()
    private var worker: Task<Void, Never>?
    private var workerID: UUID?
    private let checkpointDirectory: URL?

    init(checkpointDirectory: URL? = nil) { self.checkpointDirectory = checkpointDirectory }

    func attach(preview: Bool, settings: SaverSettings) -> UUID {
        let id = UUID()
        clients[id] = preview
        self.settings = settings
        if worker == nil { startWorker() }
        return id
    }
    func configure(_ settings: SaverSettings) { self.settings = settings }
    func detach(_ id: UUID) {
        clients[id] = nil
        if clients.isEmpty {
            worker?.cancel()
            worker = nil
            workerID = nil
        }
    }

    private func startWorker() {
        let id = UUID()
        workerID = id
        let directory = checkpointDirectory
        worker = Task.detached(priority: .utility) { [weak self] in
            let store = CheckpointStore(directory: directory)
            var evolution = Evolution(checkpoint: store.load())
            var random = SeededRandom(state: UInt64(Date().timeIntervalSince1970))
            var match = Match(seed: random.next(), amber: evolution.checkpoint.champion, blue: evolution.checkpoint.challenger)
            var previous = match.board
            var round = 1
            var nextFrame = 0.0
            var finishedAt: Double?
            var lastSave = ProcessInfo.processInfo.systemUptime
            var nextLockAttempt = 0.0
            var frameTime = 0.0
            while !Task.isCancelled {
                guard let control = await self?.control(for: id) else { break }
                let started = ProcessInfo.processInfo.systemUptime
                let wantsTraining = control.1 && control.0.trainingEnabled
                if wantsTraining && !store.ownsLock && started >= nextLockAttempt {
                    _ = store.acquire()
                    // Spectator hosts also pick up newly trained players. If ownership
                    // changes, resume from the latest atomic checkpoint.
                    if let saved = store.load() { evolution = Evolution(checkpoint: saved) }
                    nextLockAttempt = started + 5
                }
                if !wantsTraining && store.ownsLock {
                    store.save(evolution.checkpoint)
                    store.release()
                }
                if started >= nextFrame {
                    previous = match.board
                    if match.finished {
                        if finishedAt == nil { finishedAt = started }
                        if started - finishedAt! >= 3 {
                            round += 1
                            // Swap champion colors each round; weights stay fixed within a match.
                            let a = round.isMultiple(of: 2) ? evolution.checkpoint.challenger : evolution.checkpoint.champion
                            let b = round.isMultiple(of: 2) ? evolution.checkpoint.champion : evolution.checkpoint.challenger
                            match = Match(seed: random.next(), amber: a, blue: b)
                            previous = match.board
                            finishedAt = nil
                        }
                    } else { match.advance() }
                    frameTime = ProcessInfo.processInfo.systemUptime
                    let interval = 1 / control.0.generationsPerSecond
                    nextFrame = nextFrame == 0 ? frameTime + interval : max(nextFrame + interval, frameTime)
                }
                var trainingTime = 0.0
                if wantsTraining && store.ownsLock {
                    let before = ProcessInfo.processInfo.systemUptime
                    repeat {
                        let selected = evolution.advance()
                        if selected { store.save(evolution.checkpoint); lastSave = before }
                        trainingTime = ProcessInfo.processInfo.systemUptime - before
                    } while trainingTime < 0.008 && !Task.isCancelled
                    if started - lastSave > 60 {
                        store.save(evolution.checkpoint)
                        lastSave = started
                    }
                }
                let status = store.error ?? (wantsTraining ? (store.ownsLock ? "Learning" : "Learning in another window") : (control.1 ? "Learning paused" : "Preview · learning paused"))
                let snapshot = ArenaSnapshot(board: match.board, previous: previous, placements: match.lastPlacements,
                    generation: match.generation, round: round, averageAdvantage: match.averageAdvantage,
                    finished: match.finished, winner: match.winner, evolution: evolution.checkpoint.generation,
                    evaluated: evolution.evaluatedThisRound, evaluationTotal: evolution.evaluationsPerRound,
                    trainedMatches: evolution.checkpoint.completedMatches, trainingStatus: status, updatedAt: frameTime)
                await self?.publish(snapshot, for: id)
                // Four units of rest per unit of training: ~20% of one worker's time,
                // plus visible match work. A single neural move is not preemptible.
                let delay = max(0.008, trainingTime * 4)
                try? await Task.sleep(for: .seconds(delay))
            }
            store.save(evolution.checkpoint)
        }
    }
    private func control(for id: UUID) -> (SaverSettings, Bool)? {
        guard workerID == id && !clients.isEmpty else { return nil }
        return (settings, clients.values.contains(false))
    }
    private func publish(_ snapshot: ArenaSnapshot, for id: UUID) {
        guard workerID == id else { return }
        self.snapshot = snapshot
    }
}
