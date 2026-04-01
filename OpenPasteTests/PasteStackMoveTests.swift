import Foundation
import Testing
@testable import OpenPaste

/// Tests for PasteStackViewModel.moveItems(from:to:) reordering logic
/// and additional add/remove/clear behavior.
struct PasteStackMoveTests {

    // MARK: - Helpers

    private func makeVM(count: Int) -> PasteStackViewModel {
        let vm = PasteStackViewModel()
        for i in 0..<count {
            vm.addToStack(TestHelpers.makeTextItem(text: "item\(i)"))
        }
        return vm
    }

    private func texts(_ vm: PasteStackViewModel) -> [String] {
        vm.items.compactMap { $0.plainTextContent }
    }

    // MARK: - moveItems Tests

    @Test func moveItemForward() {
        // Move item at index 0 to after index 2 → destination = 3 in List semantics
        // [A, B, C] → move 0 to 3 → [B, C, A]
        let vm = makeVM(count: 3)
        let originalTexts = texts(vm)
        vm.moveItems(from: IndexSet(integer: 0), to: 3)

        #expect(texts(vm) == [originalTexts[1], originalTexts[2], originalTexts[0]])
    }

    @Test func moveItemBackward() {
        // Move item at index 2 to position 0
        // [A, B, C] → move 2 to 0 → [C, A, B]
        let vm = makeVM(count: 3)
        let originalTexts = texts(vm)
        vm.moveItems(from: IndexSet(integer: 2), to: 0)

        #expect(texts(vm) == [originalTexts[2], originalTexts[0], originalTexts[1]])
    }

    @Test func moveItemToSamePosition() {
        // Move item 1 to position 1 (no-op effectively)
        let vm = makeVM(count: 3)
        let originalTexts = texts(vm)
        vm.moveItems(from: IndexSet(integer: 1), to: 1)

        #expect(texts(vm) == originalTexts)
    }

    @Test func moveCurrentItemForward() {
        // currentIndex = 0, move item 0 to position 3
        // currentIndex should follow the moved item
        let vm = makeVM(count: 3)
        vm.currentIndex = 0
        vm.moveItems(from: IndexSet(integer: 0), to: 3)

        // destination(3) > sourceIdx(0), so currentIndex = destination - 1 = 2
        #expect(vm.currentIndex == 2)
    }

    @Test func moveCurrentItemBackward() {
        // currentIndex = 2, move item 2 to position 0
        // currentIndex should follow the moved item
        let vm = makeVM(count: 3)
        vm.currentIndex = 2
        vm.moveItems(from: IndexSet(integer: 2), to: 0)

        // destination(0) <= sourceIdx(2), so currentIndex = destination = 0
        #expect(vm.currentIndex == 0)
    }

    @Test func moveItemBeforeCurrentAdjustsIndex() {
        // currentIndex = 1, move item 0 to position 3 (after current)
        // Item before current moved after → currentIndex decreases by 1
        let vm = makeVM(count: 4)
        vm.currentIndex = 1
        vm.moveItems(from: IndexSet(integer: 0), to: 3)

        #expect(vm.currentIndex == 0)
    }

    @Test func moveItemAfterCurrentAdjustsIndex() {
        // currentIndex = 1, move item 2 to position 0 (before current)
        // Item after current moved before → currentIndex increases by 1
        let vm = makeVM(count: 4)
        vm.currentIndex = 1
        vm.moveItems(from: IndexSet(integer: 2), to: 0)

        #expect(vm.currentIndex == 2)
    }

    @Test func moveItemDoesNotAffectUnrelatedCurrentIndex() {
        // currentIndex = 0, move item 1 to position 3
        // Since source(1) > current(0) and destination(3) > current(0),
        // currentIndex should not change
        let vm = makeVM(count: 4)
        vm.currentIndex = 0
        vm.moveItems(from: IndexSet(integer: 1), to: 3)

        #expect(vm.currentIndex == 0)
    }

    // MARK: - Add & Remove Round-Trip

    @Test func addAndRemoveRoundTrip() {
        let vm = PasteStackViewModel()
        let item = TestHelpers.makeTextItem(text: "round-trip")
        vm.addToStack(item)
        #expect(vm.items.count == 1)
        #expect(vm.isActive)

        vm.removeFromStack(item)
        #expect(vm.items.isEmpty)
        #expect(!vm.isActive)
    }

    @Test func removeMiddleItem() {
        let vm = makeVM(count: 3)
        let middleItem = vm.items[1]
        vm.removeFromStack(middleItem)
        #expect(vm.items.count == 2)
        #expect(!vm.items.contains(where: { $0.id == middleItem.id }))
    }

    @Test func removeLastItemAdjustsCurrentIndex() {
        let vm = makeVM(count: 3)
        vm.currentIndex = 2
        let lastItem = vm.items[2]
        vm.removeFromStack(lastItem)
        // currentIndex should be clamped to count - 1
        #expect(vm.currentIndex <= vm.items.count - 1)
    }

    // MARK: - Clear

    @Test func clearResetsState() {
        let vm = makeVM(count: 5)
        vm.currentIndex = 3
        vm.clear()
        #expect(vm.items.isEmpty)
        #expect(vm.currentIndex == 0)
        #expect(!vm.isActive)
        #expect(vm.positionText == "")
    }

    // MARK: - Position Text After Move

    @Test func positionTextAfterMove() {
        let vm = makeVM(count: 3)
        vm.currentIndex = 0
        vm.moveItems(from: IndexSet(integer: 0), to: 3)
        // After move, items still has 3 items, currentIndex should be 2
        #expect(vm.positionText == "3/3")
    }
}
