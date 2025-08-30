import XCTest
@testable import Z3st

final class PendingLogStoreTests: XCTestCase {
    func testEnqueueAndRemove() {
        let store = PendingLogStore.shared
        // Clear existing
        let existing = store.all()
        store.remove(ids: existing.map { $0.id })

        store.enqueue(ml: 200, at: Date(timeIntervalSince1970: 0))
        var items = store.all()
        XCTAssertEqual(items.count, 1)
        let id = items[0].id
        store.remove(ids: [id])
        items = store.all()
        XCTAssertEqual(items.count, 0)
    }
}

