import XCTest
@testable import OvloPhone

/// Tests for AffirmationManager - manages affirmation storage and cycling.
final class AffirmationManagerTests: XCTestCase {
    private let customAffirmationsKey = "customAffirmations"

    override func setUp() {
        // Clear any custom affirmations before each test
        UserDefaults.standard.removeObject(forKey: customAffirmationsKey)
    }

    override func tearDown() {
        // Clean up after tests
        UserDefaults.standard.removeObject(forKey: customAffirmationsKey)
    }

    // MARK: - Default Affirmations

    func testDefaultAffirmationsAreProvided() {
        let manager = AffirmationManager.shared

        XCTAssertFalse(manager.affirmations.isEmpty, "Should have default affirmations")
        XCTAssertEqual(
            manager.affirmations.count,
            AffirmationManager.defaultAffirmations.count,
            "Should return all default affirmations"
        )
    }

    func testHasCustomAffirmationsIsFalseByDefault() {
        let manager = AffirmationManager.shared

        XCTAssertFalse(manager.hasCustomAffirmations, "Should not have custom affirmations initially")
    }

    // MARK: - Custom Affirmations

    func testSettingCustomAffirmations() {
        let manager = AffirmationManager.shared
        let custom = ["First", "Second", "Third"]

        manager.affirmations = custom

        XCTAssertEqual(manager.affirmations, custom, "Should return custom affirmations")
        XCTAssertTrue(manager.hasCustomAffirmations, "Should indicate custom affirmations are set")
    }

    func testResetToDefaults() {
        let manager = AffirmationManager.shared

        // Set custom first
        manager.affirmations = ["Custom one"]
        XCTAssertTrue(manager.hasCustomAffirmations)

        // Reset
        manager.resetToDefaults()

        XCTAssertFalse(manager.hasCustomAffirmations)
        XCTAssertEqual(manager.affirmations, AffirmationManager.defaultAffirmations)
    }

    // MARK: - Shuffling and Cycling

    func testShuffleReordersAffirmations() {
        let manager = AffirmationManager.shared

        // Use a larger set to make shuffle more likely to produce different order
        manager.affirmations = ["A", "B", "C", "D", "E", "F", "G", "H"]

        // Shuffle multiple times and check we get different orders
        var orders: Set<String> = []
        for _ in 0..<10 {
            manager.shuffle()
            var sequence: [String] = []
            for _ in 0..<8 {
                sequence.append(manager.nextAffirmation())
            }
            orders.insert(sequence.joined(separator: ","))
        }

        // With 8 items and 10 shuffles, we should see at least 2 different orders
        XCTAssertGreaterThan(orders.count, 1, "Shuffle should produce different orderings")
    }

    func testNextAffirmationCyclesThroughAll() {
        let manager = AffirmationManager.shared
        manager.affirmations = ["A", "B", "C"]
        manager.shuffle()

        var seen: Set<String> = []
        for _ in 0..<3 {
            seen.insert(manager.nextAffirmation())
        }

        XCTAssertEqual(seen, Set(["A", "B", "C"]), "Should cycle through all affirmations")
    }

    func testNextAffirmationWrapsAround() {
        let manager = AffirmationManager.shared
        manager.affirmations = ["A", "B"]
        manager.shuffle()

        // Go through all affirmations twice
        let first1 = manager.nextAffirmation()
        let first2 = manager.nextAffirmation()
        let second1 = manager.nextAffirmation()
        let second2 = manager.nextAffirmation()

        // After wrapping, we should see the same sequence
        XCTAssertEqual(first1, second1, "Should wrap around to same affirmation")
        XCTAssertEqual(first2, second2, "Second position should also repeat")
    }

    // MARK: - Persistence

    func testAffirmationsPersistAcrossAccess() {
        let manager = AffirmationManager.shared
        let custom = ["Persistent", "Affirmation"]

        manager.affirmations = custom

        // Access again
        let retrieved = manager.affirmations

        XCTAssertEqual(retrieved, custom, "Affirmations should persist")
    }
}
