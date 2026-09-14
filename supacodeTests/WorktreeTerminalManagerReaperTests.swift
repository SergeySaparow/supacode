import Dependencies
import Foundation
import IdentifiedCollections
import Testing

@testable import supacode

@MainActor
struct WorktreeTerminalManagerReaperTests {
  @Test func terminateKillsTrackedSessionsWithoutScanningOrphans() async {
    let killed = LockIsolated<[String]>([])
    let manager = withDependencies {
      $0.zmxClient = ZmxClient(
        executableURL: { nil },
        isBundled: { true },
        killSession: { id in killed.withValue { $0.append(id) } },
        killRemoteSession: { _, _ in },
        listRemoteSessions: { _ in nil }
      )
    } operation: {
      WorktreeTerminalManager(runtime: GhosttyRuntime())
    }

    let worktree = makeWorktree()
    let host = manager.host(for: worktree)
    let trackedSurfaceID = UUID()
    let paneID = PaneID()
    let tabID = TabID(rawValue: trackedSurfaceID)
    let layout = PaneLayout(
      tree: SplitTree(view: paneID),
      panes: [
        Pane(
          id: paneID,
          tabs: [
            TabItem(
              id: tabID,
              title: "Tab",
              content: ContentSnapshot(
                id: ContentID(rawValue: trackedSurfaceID),
                state: .terminal(TerminalContentState(workingDirectory: nil))
              )
            )
          ],
          selectedTabID: tabID
        )
      ],
      focusedPaneID: paneID
    )
    host.layout = { layout }

    await manager.terminateAllSessions()

    #expect(killed.value == [ZmxSessionID.make(surfaceID: trackedSurfaceID)])
  }

  private func makeWorktree(id: String = "/tmp/repo/wt-1") -> Worktree {
    let name = URL(fileURLWithPath: id).lastPathComponent
    return Worktree(
      id: WorktreeID(id),
      name: name,
      detail: "detail",
      workingDirectory: URL(fileURLWithPath: id),
      repositoryRootURL: URL(fileURLWithPath: "/tmp/repo")
    )
  }
}
