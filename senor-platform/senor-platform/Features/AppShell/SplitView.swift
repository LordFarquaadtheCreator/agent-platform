import SwiftUI
import AppKit

struct SplitView<Sidebar: View, Content: View, Detail: View>: NSViewRepresentable {
    @Binding var sidebarVisible: Bool
    @Binding var detailVisible: Bool
    let sidebar: Sidebar
    let content: Content
    let detail: Detail

    init(
        sidebarVisible: Binding<Bool>,
        detailVisible: Binding<Bool>,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder content: () -> Content,
        @ViewBuilder detail: () -> Detail
    ) {
        self._sidebarVisible = sidebarVisible
        self._detailVisible = detailVisible
        self.sidebar = sidebar()
        self.content = content()
        self.detail = detail()
    }

    func makeNSView(context: Context) -> NSSplitView {
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.autosaveName = "MainSplitView"

        let sidebarController = NSHostingController(rootView: sidebar)
        let contentController = NSHostingController(rootView: content)
        let detailController = NSHostingController(rootView: detail)

        sidebarController.view.translatesAutoresizingMaskIntoConstraints = false
        contentController.view.translatesAutoresizingMaskIntoConstraints = false
        detailController.view.translatesAutoresizingMaskIntoConstraints = false

        splitView.addArrangedSubview(sidebarController.view)
        splitView.addArrangedSubview(contentController.view)
        splitView.addArrangedSubview(detailController.view)

        splitView.setPosition(250, ofDividerAt: 0)
        splitView.setPosition(900, ofDividerAt: 1)

        context.coordinator.sidebarController = sidebarController
        context.coordinator.contentController = contentController
        context.coordinator.detailController = detailController
        context.coordinator.splitView = splitView

        return splitView
    }

    func updateNSView(_ splitView: NSSplitView, context: Context) {
        context.coordinator.updateVisibility(
            sidebar: sidebarVisible,
            detail: detailVisible
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSSplitViewDelegate {
        var parent: SplitView
        weak var splitView: NSSplitView?
        weak var sidebarController: NSHostingController<Sidebar>?
        weak var contentController: NSHostingController<Content>?
        weak var detailController: NSHostingController<Detail>?

        private var sidebarWidth: CGFloat = 250
        private var detailWidth: CGFloat = 320

        init(_ parent: SplitView) {
            self.parent = parent
        }

        func updateVisibility(sidebar: Bool, detail: Bool) {
            guard let splitView = splitView else { return }

            if sidebar != (splitView.isSubviewCollapsed(splitView.arrangedSubviews[0]) == false) {
                if sidebar {
                    splitView.setPosition(sidebarWidth, ofDividerAt: 0)
                } else {
                    sidebarWidth = splitView.arrangedSubviews[0].frame.width
                    splitView.setPosition(0, ofDividerAt: 0)
                }
            }

            if detail != (splitView.isSubviewCollapsed(splitView.arrangedSubviews[2]) == false) {
                if detail {
                    let contentWidth = splitView.arrangedSubviews[1].frame.width
                    splitView.setPosition(contentWidth + detailWidth, ofDividerAt: 1)
                } else {
                    detailWidth = splitView.arrangedSubviews[2].frame.width
                    let contentWidth = splitView.arrangedSubviews[1].frame.width
                    splitView.setPosition(contentWidth, ofDividerAt: 1)
                }
            }
        }

        func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
            true
        }

        func splitView(_ splitView: NSSplitView, shouldCollapseSubview subview: NSView, forDoubleClickOnDividerAt dividerIndex: Int) -> Bool {
            true
        }
    }
}
