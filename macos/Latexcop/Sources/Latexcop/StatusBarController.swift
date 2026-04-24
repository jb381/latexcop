import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate, NSWindowDelegate {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var repoWindow: NSWindow?
    private var cancellable: AnyCancellable?

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        super.init()

        if let button = statusItem.button {
            button.title = model.menuTitle
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        popover.behavior = .applicationDefined
        popover.contentSize = NSSize(width: 390, height: 1)
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(
                onAddRepo: { [weak self] in
                    self?.showRepoWindow(repo: nil)
                },
                onEditRepo: { [weak self] repo in
                    self?.showRepoWindow(repo: repo)
                }
            )
            .environmentObject(model)
        )

        cancellable = model.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.statusItem.button?.title = self?.model.menuTitle ?? "👮"
            }
        }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            model.refreshAll()
        }
    }

    private func showRepoWindow(repo: TrackedRepo?) {
        NSApp.activate(ignoringOtherApps: true)

        if let repoWindow {
            repoWindow.makeKeyAndOrderFront(nil)
            return
        }

        let view = AddRepoView(existingRepo: repo) { [weak self] in
            self?.repoWindow?.close()
            self?.repoWindow = nil
        }
        .environmentObject(model)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 430),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = repo == nil ? "Add Repo" : "Edit Repo"
        window.isReleasedWhenClosed = false
        window.center()
        window.level = .floating
        window.delegate = self
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
        repoWindow = window
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === repoWindow else {
            return
        }
        repoWindow = nil
    }
}
