import Testing
@testable import Spot

@Suite("Block user confirmation copy")
struct BlockUserConfirmationCopyTests {
    @Test func titlesNamedUser() {
        let copy = BlockUserConfirmationCopy.make(username: "eddie")
        #expect(copy.title == "Block @eddie?")
        #expect(copy.confirmTitle == "Block")
        #expect(copy.cancelTitle == "Cancel")
        #expect(copy.message == BlockUserConfirmationCopy.defaultMessage)
    }

    @Test func titleFallsBackWhenUsernameMissing() {
        #expect(BlockUserConfirmationCopy.title(for: nil) == "Block this user?")
        #expect(BlockUserConfirmationCopy.title(for: "") == "Block this user?")
        #expect(BlockUserConfirmationCopy.title(for: "   ") == "Block this user?")
        #expect(BlockUserConfirmationCopy.title(for: "@") == "Block this user?")
        #expect(BlockUserConfirmationCopy.title(for: " @ ") == "Block this user?")
    }

    @Test func displayHandleNormalizesAtPrefixAndWhitespace() {
        #expect(BlockUserConfirmationCopy.displayHandle(from: "eddie") == "@eddie")
        #expect(BlockUserConfirmationCopy.displayHandle(from: "  eddie  ") == "@eddie")
        #expect(BlockUserConfirmationCopy.displayHandle(from: "@eddie") == "@eddie")
        #expect(BlockUserConfirmationCopy.displayHandle(from: " @eddie ") == "@eddie")
        #expect(BlockUserConfirmationCopy.displayHandle(from: nil) == nil)
        #expect(BlockUserConfirmationCopy.displayHandle(from: "") == nil)
        #expect(BlockUserConfirmationCopy.displayHandle(from: "   ") == nil)
        #expect(BlockUserConfirmationCopy.displayHandle(from: "@") == nil)
    }

    @Test func makeUsesFallbackTitleWithoutHandle() {
        let copy = BlockUserConfirmationCopy.make(username: nil)
        #expect(copy.title == BlockUserConfirmationCopy.fallbackTitle)
        #expect(copy.confirmTitle == BlockUserConfirmationCopy.defaultConfirmTitle)
        #expect(copy.cancelTitle == BlockUserConfirmationCopy.defaultCancelTitle)
    }
}
