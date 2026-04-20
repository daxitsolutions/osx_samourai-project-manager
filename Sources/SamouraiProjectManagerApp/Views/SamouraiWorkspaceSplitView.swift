import SwiftUI

struct SamouraiWorkspaceSplitView<Sidebar: View, Detail: View>: View {
    let sidebarMinWidth: CGFloat
    let sidebarIdealWidth: CGFloat
    let showsDetail: Bool
    @ViewBuilder let sidebar: () -> Sidebar
    @ViewBuilder let detail: () -> Detail

    init(
        sidebarMinWidth: CGFloat,
        sidebarIdealWidth: CGFloat,
        showsDetail: Bool = true,
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder detail: @escaping () -> Detail
    ) {
        self.sidebarMinWidth = sidebarMinWidth
        self.sidebarIdealWidth = sidebarIdealWidth
        self.showsDetail = showsDetail
        self.sidebar = sidebar
        self.detail = detail
    }

    var body: some View {
        Group {
            if showsDetail {
                HSplitView {
                    sidebar()
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                        .frame(minWidth: sidebarMinWidth, idealWidth: sidebarIdealWidth, alignment: .topLeading)
                        .background(SamouraiSurface.sidebar)
                        .overlay(alignment: .trailing) {
                            Rectangle()
                                .fill(SamouraiSurface.borderStrong)
                                .frame(width: 1)
                        }

                    detail()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(SamouraiSurface.canvasTop)
                }
            } else {
                sidebar()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(SamouraiSurface.canvasTop)
            }
        }
        .samouraiCanvasBackground()
    }
}
