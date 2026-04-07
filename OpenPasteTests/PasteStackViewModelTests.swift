import Foundation
import Testing
@testable import OpenPaste

struct PasteStackViewModelTests {
    @Test func initiallyInactive() {
        let vm = PasteStackViewModel()
        #expect(!vm.isActive)
        #expect(vm.items.isEmpty)
        #expect(vm.currentIndex == 0)
    }

    @Test func addToStack() {
        let vm = PasteStackViewModel()
        let item = TestHelpers.makeTextItem().toSummary()
        vm.addToStack(item)
        #expect(vm.items.count == 1)
        #expect(vm.isActive)
    }

    @Test func noDuplicateItems() {
        let vm = PasteStackViewModel()
        let item = TestHelpers.makeTextItem().toSummary()
        vm.addToStack(item)
        vm.addToStack(item)
        #expect(vm.items.count == 1)
    }

    @Test func addMultipleItems() {
        let vm = PasteStackViewModel()
        vm.addToStack(TestHelpers.makeTextItem(text: "a").toSummary())
        vm.addToStack(TestHelpers.makeTextItem(text: "b").toSummary())
        vm.addToStack(TestHelpers.makeTextItem(text: "c").toSummary())
        #expect(vm.items.count == 3)
    }

    @Test func removeFromStack() {
        let vm = PasteStackViewModel()
        let item = TestHelpers.makeTextItem().toSummary()
        vm.addToStack(item)
        vm.removeFromStack(item)
        #expect(vm.items.isEmpty)
        #expect(!vm.isActive)
    }

    @Test func removeAdjustsIndex() {
        let vm = PasteStackViewModel()
        vm.addToStack(TestHelpers.makeTextItem(text: "a").toSummary())
        let itemB = TestHelpers.makeTextItem(text: "b").toSummary()
        vm.addToStack(itemB)
        vm.currentIndex = 1
        vm.removeFromStack(itemB)
        #expect(vm.currentIndex == 0)
    }

    @Test func currentItem() {
        let vm = PasteStackViewModel()
        let item = TestHelpers.makeTextItem(text: "first").toSummary()
        vm.addToStack(item)
        #expect(vm.currentItem?.id == item.id)
    }

    @Test func currentItemNilWhenEmpty() {
        let vm = PasteStackViewModel()
        #expect(vm.currentItem == nil)
    }

    @Test func positionText() {
        let vm = PasteStackViewModel()
        vm.addToStack(TestHelpers.makeTextItem(text: "a").toSummary())
        vm.addToStack(TestHelpers.makeTextItem(text: "b").toSummary())
        vm.addToStack(TestHelpers.makeTextItem(text: "c").toSummary())
        #expect(vm.positionText == "1/3")
    }

    @Test func positionTextEmpty() {
        let vm = PasteStackViewModel()
        #expect(vm.positionText == "")
    }

    @Test func clear() {
        let vm = PasteStackViewModel()
        vm.addToStack(TestHelpers.makeTextItem(text: "a").toSummary())
        vm.addToStack(TestHelpers.makeTextItem(text: "b").toSummary())
        vm.currentIndex = 1
        vm.clear()
        #expect(vm.items.isEmpty)
        #expect(vm.currentIndex == 0)
        #expect(!vm.isActive)
    }
}
