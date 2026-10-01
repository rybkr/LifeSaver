import Foundation

@main
struct VerifyRuntime {
    @MainActor static func main() async throws {
        func require(_ condition: Bool, _ message: String = "Runtime verification failed") {
            if !condition {
                FileHandle.standardError.write(Data((message + "\n").utf8))
                exit(1)
            }
        }
        let directory = URL(fileURLWithPath: "build/runtime-check-\(UUID().uuidString)", isDirectory: true)
        let session = SimulationSession(checkpointDirectory: directory)
        let preview = session.attach(preview: true, settings: SaverSettings())
        try await Task.sleep(for: .seconds(0.3))
        require(session.snapshot.trainedMatches == 0)
        require(!FileManager.default.fileExists(atPath: directory.path), "Preview must not create training files")
        let full = session.attach(preview: false, settings: SaverSettings())
        let deadline = ProcessInfo.processInfo.systemUptime + 15
        while session.snapshot.trainedMatches == 0 && ProcessInfo.processInfo.systemUptime < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        require(session.snapshot.trainedMatches > 0, "No training matches: \(session.snapshot.trainingStatus), trials \(session.snapshot.evaluated)")
        let another = SimulationSession(checkpointDirectory: directory)
        let otherID = another.attach(preview: false, settings: SaverSettings())
        try await Task.sleep(for: .seconds(0.3))
        require(another.snapshot.trainingStatus == "Learning in another window", "Only one session may train")
        another.detach(otherID)
        session.detach(full)
        try await Task.sleep(for: .seconds(0.3))
        require(session.snapshot.trainingStatus.contains("paused"), "Expected paused, got: \(session.snapshot.trainingStatus)")
        let count = session.snapshot.trainedMatches
        try await Task.sleep(for: .seconds(0.3))
        require(session.snapshot.trainedMatches == count, "Training must pause when only previews remain")
        let checkpoint = try PropertyListDecoder().decode(EvolutionCheckpoint.self,
            from: Data(contentsOf: directory.appendingPathComponent("evolution.plist")))
        require(checkpoint.isValid && checkpoint.completedMatches > 0)
        session.detach(preview)
        let restored = SimulationSession(checkpointDirectory: directory)
        let restoredID = restored.attach(preview: true, settings: SaverSettings())
        try await Task.sleep(for: .seconds(0.3))
        require(restored.snapshot.evolution == checkpoint.generation && restored.snapshot.trainedMatches == checkpoint.completedMatches, "Checkpoint did not restore")
        restored.detach(restoredID)
        try await Task.sleep(for: .seconds(0.1))
        print("PASS: preview isolation, runtime evolution, exclusive training, pause, checkpoint, and restore")
    }
}
