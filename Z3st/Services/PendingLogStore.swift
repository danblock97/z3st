import Foundation

struct PendingLog: Codable, Equatable, Identifiable {
    let id: UUID
    let ml: Int
    let createdAt: Date
}

final class PendingLogStore {
    static let shared = PendingLogStore()
    private let key = "pending_logs"

    private func load() -> [PendingLog] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([PendingLog].self, from: data)) ?? []
    }

    private func save(_ logs: [PendingLog]) {
        let data = try? JSONEncoder().encode(logs)
        UserDefaults.standard.set(data, forKey: key)
    }

    func enqueue(ml: Int, at date: Date = Date()) {
        var logs = load()
        logs.append(PendingLog(id: UUID(), ml: ml, createdAt: date))
        save(logs)
    }

    func all() -> [PendingLog] { load() }

    func remove(ids: [UUID]) {
        var logs = load()
        logs.removeAll { ids.contains($0.id) }
        save(logs)
    }
}

