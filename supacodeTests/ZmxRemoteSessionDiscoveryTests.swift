import Foundation
import SupacodeSettingsShared
import Testing

@testable import supacode

@MainActor
struct ZmxRemoteSessionDiscoveryTests {
  @Test func discoveryIsOptInAndCodable() throws {
    #expect(GlobalSettings.default.remoteSessionDiscoveryEnabled == false)

    var settings = GlobalSettings.default
    settings.remoteSessionDiscoveryEnabled = true
    let data = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(GlobalSettings.self, from: data)
    #expect(decoded.remoteSessionDiscoveryEnabled)
  }

  @Test func reconciliationAddsMissingNamesAndRemovesOnlyDiscoveredOnes() {
    let changes = ZmxSessionReconciliation.diff(
      remote: [
        .init(name: "existing", clients: 0),
        .init(name: "new shell", clients: 1),
        .init(name: "new shell", clients: 1),
      ],
      local: [
        .init(name: "existing", isDiscovered: true),
        .init(name: "gone", isDiscovered: true),
        .init(name: "owned", isDiscovered: false),
      ]
    )

    #expect(changes.added == ["new shell"])
    #expect(changes.removed == ["gone"])
  }

  @Test func discoveryUsesEndpointScopedGlobalOpenSet() {
    let remote = [
      ZmxSessionListParser.Entry(name: "New_1", clients: 1),
      ZmxSessionListParser.Entry(name: "New_2", clients: 0),
    ]
    let open = [
      ZmxSessionReconciliation.OpenSession(endpoint: "local", name: "New_1")
    ]

    #expect(
      ZmxSessionReconciliation.missingNames(
        remote: remote,
        endpoint: "strix|saparow|22",
        openSessions: open
      ) == ["New_1", "New_2"]
    )
    #expect(
      ZmxSessionReconciliation.missingNames(
        remote: remote,
        endpoint: "local",
        openSessions: open
      ) == ["New_2"]
    )
  }

  @Test func localDiscoveryExcludesRemoteSurfaceWrappers() {
    let remoteWrapper = ZmxSessionID.make(
      surfaceID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    )
    let entries = [
      ZmxSessionListParser.Entry(name: "New_1", clients: 1),
      ZmxSessionListParser.Entry(name: remoteWrapper, clients: 1),
      ZmxSessionListParser.Entry(name: "manual shell", clients: 0),
    ]

    #expect(
      ZmxSessionReconciliation.localDiscoveryEntries(
        entries,
        excludingRemoteWrappers: Set([remoteWrapper])
      ) == [
        .init(name: "New_1", clients: 1),
        .init(name: "manual shell", clients: 0),
      ]
    )
  }

  @Test func emptyDiscoveryListingDoesNotProduceRemovals() {
    #expect(
      ZmxSessionReconciliation.missingNames(
        remote: [],
        endpoint: "local",
        openSessions: [
          .init(endpoint: "local", name: "New_1")
        ]
      ).isEmpty
    )
  }

  @Test func equivalentSSHFormsShareCanonicalEndpointIdentity() {
    let config = """
      hostname 192.168.5.130
      user saparow
      port 22
      """

    #expect(
      ZmxRemoteEndpointIdentity.parse(config) == "192.168.5.130|saparow|22"
    )
  }
}
