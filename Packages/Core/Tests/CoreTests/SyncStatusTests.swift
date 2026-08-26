import Core
import Testing

@Suite("Sync status")
struct SyncStatusTests {
    @Test("only an attached, signed-in store counts as syncing")
    func onlySyncingIsSyncing() {
        #expect(SyncStatus.syncing.isSyncing)
        #expect(!SyncStatus.signedOut.isSyncing)
        #expect(!SyncStatus.checking.isSyncing)
        for reason in SyncUnavailableReason.allCases {
            #expect(!SyncStatus.localOnly(reason).isSyncing)
        }
    }

    @Test("the fallback reporter never claims more than it can do")
    func fallbackReporterIsHonest() async {
        for reason in SyncUnavailableReason.allCases {
            #expect(await LocalOnlySync(reason: reason).status == .localOnly(reason))
        }
        #expect(await LocalOnlySync().status == .localOnly(.notAttached))
    }
}
