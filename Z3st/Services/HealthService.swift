import Foundation
import HealthKit

final class HealthService {
    static let shared = HealthService()
    private let store = HKHealthStore()
    private let waterType = HKObjectType.quantityType(forIdentifier: .dietaryWater)!

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorizationIfNeeded() async {
        guard isAvailable else { return }
        let types: Set = [waterType]
        do { try await store.requestAuthorization(toShare: types, read: types) } catch { }
    }

    func writeWaterIfAuthorized(ml: Int, at date: Date) async {
        guard isAvailable else { return }
        let status = store.authorizationStatus(for: waterType)
        guard status == .sharingAuthorized else { return }
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: Double(ml))
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: date, end: date)
        try? await store.save(sample)
    }

    func readWater(from start: Date, to end: Date) async throws -> [(ml: Int, date: Date)] {
        guard isAvailable else { return [] }
        let status = store.authorizationStatus(for: waterType)
        guard status != .notDetermined else { return [] }
        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { c in
            let q = HKSampleQuery(sampleType: waterType, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: sort) { _, res, err in
                if let err { c.resume(throwing: err); return }
                c.resume(returning: (res as? [HKQuantitySample]) ?? [])
            }
            store.execute(q)
        }
        return samples.map { s in
            let ml = s.quantity.doubleValue(for: .literUnit(with: .milli))
            return (Int(round(ml)), s.endDate)
        }
    }

    func importLastNDays(_ days: Int) async {
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        do {
            let rows = try await readWater(from: start, to: now)
            try await WaterService.shared.importHealth(rows: rows)
        } catch { }
    }
}
