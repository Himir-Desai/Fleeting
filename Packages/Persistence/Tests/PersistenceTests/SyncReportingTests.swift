import Core
@testable import Persistence
import Testing

@Suite("Sync reporting")
struct SyncReportingTests {
    @Test("a store that never reached iCloud reports exactly why, and nothing rosier")
    func unavailableStoreRepeatsItsReason() async {
        for reason in SyncUnavailableReason.allCases {
            let reporter = CloudKitSyncReporter(attachment: .unavailable(reason))
            #expect(await reporter.status == .localOnly(reason))
        }
    }

    @Test("a store that never reached iCloud never claims to be syncing")
    func unavailableStoreNeverClaimsToSync() async {
        for reason in SyncUnavailableReason.allCases {
            let reporter = CloudKitSyncReporter(attachment: .unavailable(reason))
            #expect(await reporter.status.isSyncing == false)
        }
    }

    @Test("every reason has something to say to the user")
    func everyReasonReads() {
        for reason in SyncUnavailableReason.allCases {
            #expect(!reason.summary.isEmpty)
            #expect(reason.summary.hasSuffix("."))
        }
    }
}
