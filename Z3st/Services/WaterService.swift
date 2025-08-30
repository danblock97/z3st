import Foundation
#if canImport(Supabase) && !OFFLINE_TESTS
import Supabase

final class WaterService {
    static let shared = WaterService()
    private let client = SupabaseManager.shared.client
    private let table = "water_entries"

    struct NewWaterEntry: Encodable {
        let id: UUID
        let user_id: UUID
        let volume_ml: Int
        let created_at: String
        let source: String?
    }

    func logWater(volumeML: Int, at date: Date = Date()) async throws {
        guard let uid = AuthService.shared.currentUser?.id.uuidString else { throw NSError(domain: "Auth", code: 401) }
        guard let userUUID = UUID(uuidString: uid) else { throw NSError(domain: "Auth", code: 401) }
        let payload = NewWaterEntry(
            id: UUID(),
            user_id: userUUID,
            volume_ml: volumeML,
            created_at: ISO8601DateFormatter().string(from: date),
            source: "app"
        )
        do {
            _ = try await client.database.from(table).insert(payload).execute()
            await HealthService.shared.writeWaterIfAuthorized(ml: volumeML, at: date)
            // Update widget shared total opportunistically
            let existing = AppGroupManager.defaults()?.integer(forKey: "today_total_ml") ?? 0
            let todayStr = ISO8601DateFormatter.dateFormatterYYYYMMDD.string(from: Date())
            let entryStr = ISO8601DateFormatter.dateFormatterYYYYMMDD.string(from: date)
            if todayStr == entryStr { AppGroupManager.setTodayTotal(existing + volumeML) }
        } catch {
            PendingLogStore.shared.enqueue(ml: volumeML, at: date)
            throw error
        }
    }

    func fetchDayTotals(rangeStart: Date, rangeEnd: Date) async throws -> [WaterDayTotal] {
        // Query by date range and aggregate on the client after fetching
        guard let uid = AuthService.shared.currentUser?.id.uuidString else { return [] }
        let iso = ISO8601DateFormatter()
        let response: PostgrestResponse<[WaterEntry]> = try await client.database.from(table)
            .select()
            .eq("user_id", value: uid)
            .gte("created_at", value: iso.string(from: rangeStart))
            .lte("created_at", value: iso.string(from: rangeEnd))
            .order("created_at", ascending: true)
            .execute()

        let entries = response.value
        let df = ISO8601DateFormatter.dateFormatterYYYYMMDD
        let grouped = Dictionary(grouping: entries) { entry in
            df.string(from: entry.created_at)
        }
        return grouped.keys.sorted().map { key in
            let total = grouped[key]?.reduce(0) { $0 + $1.volume_ml } ?? 0
            return WaterDayTotal(dateString: key, total_ml: total)
        }
    }

    func fetchEntries(rangeStart: Date, rangeEnd: Date) async throws -> [WaterEntry] {
        guard let uid = AuthService.shared.currentUser?.id.uuidString else { return [] }
        let iso = ISO8601DateFormatter()
        let response: PostgrestResponse<[WaterEntry]> = try await client.database.from(table)
            .select()
            .eq("user_id", value: uid)
            .gte("created_at", value: iso.string(from: rangeStart))
            .lte("created_at", value: iso.string(from: rangeEnd))
            .order("created_at", ascending: true)
            .execute()

        return response.value
    }
}

extension WaterService {
    func syncPending() async {
        let pending = PendingLogStore.shared.all()
        guard !pending.isEmpty else { return }
        var succeeded: [UUID] = []
        for item in pending {
            do {
                try await logWater(volumeML: item.ml, at: item.createdAt)
                succeeded.append(item.id)
            } catch { /* keep pending */ }
        }
        if !succeeded.isEmpty { PendingLogStore.shared.remove(ids: succeeded) }
    }
}

extension WaterService {
    func importHealth(rows: [(ml: Int, date: Date)]) async throws {
        guard let uid = AuthService.shared.currentUser?.id.uuidString else { return }
        guard !rows.isEmpty else { return }
        let iso = ISO8601DateFormatter()
        guard let userUUID = UUID(uuidString: uid) else { return }
        let payload: [NewWaterEntry] = rows.map { r in
            .init(
                id: UUID(),
                user_id: userUUID,
                volume_ml: r.ml,
                created_at: iso.string(from: r.date),
                source: "health"
            )
        }
        _ = try await client.database.from(table)
            .upsert(payload, onConflict: "user_id,created_at,volume_ml,source")
            .execute()
    }
}

extension ISO8601DateFormatter {
    static let dateFormatterYYYYMMDD: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone.current
        return df
    }()
}
#else
final class WaterService {
    static let shared = WaterService()
    func logWater(volumeML: Int, at date: Date = Date()) async throws {}
    func fetchDayTotals(rangeStart: Date, rangeEnd: Date) async throws -> [WaterDayTotal] { [] }
    func fetchEntries(rangeStart: Date, rangeEnd: Date) async throws -> [WaterEntry] { [] }
}
extension WaterService {
    func syncPending() async {}
    func importHealth(rows: [(ml: Int, date: Date)]) async throws {}
}
extension ISO8601DateFormatter {
    static let dateFormatterYYYYMMDD: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone.current
        return df
    }()
}
#endif
