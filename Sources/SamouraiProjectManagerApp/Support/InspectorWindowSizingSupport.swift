import SwiftUI
import AppKit

@MainActor
private final class InspectorWindowLayoutManager {
    static let shared = InspectorWindowLayoutManager()

    private struct WindowState {
        var baseFrame: CGRect?
        var activeInspectorWidths: [UUID: CGFloat] = [:]
    }

    private var windowStates: [ObjectIdentifier: WindowState] = [:]

    func update(
        window: NSWindow,
        inspectorID: UUID,
        isPresented: Bool,
        preferredInspectorWidth: CGFloat
    ) {
        let key = ObjectIdentifier(window)
        var state = windowStates[key] ?? WindowState()

        if isPresented {
            state.activeInspectorWidths[inspectorID] = preferredInspectorWidth
        } else {
            state.activeInspectorWidths.removeValue(forKey: inspectorID)
        }

        reconcile(state: &state, for: window)
        persist(state: state, for: key)
    }

    func detach(window: NSWindow?, inspectorID: UUID) {
        if let window {
            detach(inspectorID: inspectorID, from: window)
            return
        }

        for candidateWindow in NSApplication.shared.windows {
            detach(inspectorID: inspectorID, from: candidateWindow)
        }
    }

    private func detach(inspectorID: UUID, from window: NSWindow) {
        let key = ObjectIdentifier(window)
        guard var state = windowStates[key] else { return }
        guard state.activeInspectorWidths.removeValue(forKey: inspectorID) != nil else { return }

        reconcile(state: &state, for: window)
        persist(state: state, for: key)
    }

    private func reconcile(state: inout WindowState, for window: NSWindow) {
        let preferredInspectorWidth = state.activeInspectorWidths.values.max() ?? 0

        if preferredInspectorWidth > 0 {
            if state.baseFrame == nil {
                state.baseFrame = window.frame
            }

            if let baseFrame = state.baseFrame {
                let expandedFrame = expandedFrame(
                    from: baseFrame,
                    in: window,
                    extraWidth: preferredInspectorWidth
                )
                applyFrameIfNeeded(expandedFrame, to: window)
            }
        } else if let baseFrame = state.baseFrame {
            applyFrameIfNeeded(clampedFrame(baseFrame, for: window), to: window)
            state.baseFrame = nil
        }
    }

    private func persist(state: WindowState, for key: ObjectIdentifier) {
        if state.baseFrame == nil && state.activeInspectorWidths.isEmpty {
            windowStates.removeValue(forKey: key)
        } else {
            windowStates[key] = state
        }
    }

    private func expandedFrame(from baseFrame: CGRect, in window: NSWindow, extraWidth: CGFloat) -> CGRect {
        var expanded = baseFrame
        expanded.size.width += extraWidth
        expanded.origin.x -= extraWidth
        return clampedFrame(expanded, for: window)
    }

    private func clampedFrame(_ frame: CGRect, for window: NSWindow) -> CGRect {
        guard let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else {
            return frame
        }

        var adjusted = frame
        adjusted.size.width = min(max(adjusted.size.width, window.minSize.width), visibleFrame.width)
        adjusted.size.height = min(max(adjusted.size.height, window.minSize.height), visibleFrame.height)

        if adjusted.maxX > visibleFrame.maxX {
            adjusted.origin.x = visibleFrame.maxX - adjusted.size.width
        }
        if adjusted.minX < visibleFrame.minX {
            adjusted.origin.x = visibleFrame.minX
        }
        if adjusted.maxY > visibleFrame.maxY {
            adjusted.origin.y = visibleFrame.maxY - adjusted.size.height
        }
        if adjusted.minY < visibleFrame.minY {
            adjusted.origin.y = visibleFrame.minY
        }

        return adjusted
    }

    private func applyFrameIfNeeded(_ frame: CGRect, to window: NSWindow) {
        guard frame.origin.x.isFinite,
              frame.origin.y.isFinite,
              frame.size.width.isFinite,
              frame.size.height.isFinite else {
            return
        }
        guard frame.equalTo(window.frame) == false else { return }
        applyFrame(frame, to: window)
    }

    private func applyFrame(_ frame: CGRect, to window: NSWindow) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(frame, display: true)
        }
    }
}

private struct InspectorWindowSizingModifier: ViewModifier {
    let isPresented: Bool
    let preferredInspectorWidth: CGFloat

    @State private var inspectorID = UUID()
    @State private var wasPresented = false
    @State private var window: NSWindow?

    func body(content: Content) -> some View {
        content
            .background(
                HostingWindowReader { resolvedWindow in
                    guard window !== resolvedWindow else { return }

                    if let previousWindow = window,
                       previousWindow !== resolvedWindow,
                       wasPresented {
                        InspectorWindowLayoutManager.shared.detach(
                            window: previousWindow,
                            inspectorID: inspectorID
                        )
                    }

                    window = resolvedWindow
                    syncWindow()
                }
            )
            .onAppear {
                syncWindow()
            }
            .onChange(of: isPresented) { _, _ in
                syncWindow()
            }
            .onChange(of: preferredInspectorWidth) { _, _ in
                syncWindow()
            }
            .onDisappear {
                if wasPresented {
                    InspectorWindowLayoutManager.shared.detach(window: window, inspectorID: inspectorID)
                    wasPresented = false
                }
            }
    }

    private func syncWindow() {
        guard let window else { return }
        InspectorWindowLayoutManager.shared.update(
            window: window,
            inspectorID: inspectorID,
            isPresented: isPresented,
            preferredInspectorWidth: preferredInspectorWidth
        )
        wasPresented = isPresented
    }
}

private struct HostingWindowReader: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> HostingWindowReaderView {
        let view = HostingWindowReaderView()
        view.onResolve = onResolve
        return view
    }

    func updateNSView(_ nsView: HostingWindowReaderView, context: Context) {
        nsView.onResolve = onResolve
        nsView.reportWindowIfNeeded()
    }
}

private final class HostingWindowReaderView: NSView {
    var onResolve: (NSWindow?) -> Void = { _ in }

    private weak var lastReportedWindow: NSWindow?

    // This bridge view exists only to discover the hosting NSWindow.
    // It must stay completely out of the event system so it cannot block clicks.
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        false
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        reportWindowIfNeeded()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        reportWindowIfNeeded()
    }

    func reportWindowIfNeeded() {
        let currentWindow = window
        guard lastReportedWindow !== currentWindow else { return }
        lastReportedWindow = currentWindow

        DispatchQueue.main.async { [weak self] in
            self?.onResolve(self?.window)
        }
    }
}

extension View {
    func dynamicWindowSizingForInspector(isPresented: Bool, preferredInspectorWidth: CGFloat) -> some View {
        modifier(
            InspectorWindowSizingModifier(
                isPresented: isPresented,
                preferredInspectorWidth: preferredInspectorWidth
            )
        )
    }
}
