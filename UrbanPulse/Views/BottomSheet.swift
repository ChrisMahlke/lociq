import SwiftUI

struct BottomSheet<Content: View>: View {
    @Binding var sheetOffset: CGFloat
    @ViewBuilder var content: Content

    @State private var translation: CGFloat = 0
    @State private var dragStartHeight: CGFloat? = nil

    // Snap points relative to available height.
    private func snapPoints(in height: CGFloat) -> (peek: CGFloat, mid: CGFloat, full: CGFloat) {
        let peek: CGFloat = max(140, min(220, height * 0.25))
        let mid: CGFloat = height * 0.50
        let full: CGFloat = height * 0.92
        return (peek, mid, full)
    }

    var body: some View {
        GeometryReader { geo in
            let totalHeight = geo.size.height
            let snaps = snapPoints(in: totalHeight)
            let bottomSafe = geo.safeAreaInsets.bottom
            let reservedBottom = (bottomSafe > 0 ? bottomSafe : 0)

            let clampedHeight = max(snaps.peek, min(snaps.full, sheetOffset + translation))
            let sheetHeight = clampedHeight
            let bottomOffset: CGFloat = reservedBottom

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                content
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: geo.size.width)
            .frame(height: sheetHeight, alignment: .top)
                .background(.regularMaterial)
            .shadow(color: .black.opacity(0.16), radius: 10, y: 2)
            .overlay(
                Rectangle()
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
            )
            .offset(y: totalHeight - sheetHeight - bottomOffset)
            .gesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .global)
                    .onChanged { value in
                        if dragStartHeight == nil { dragStartHeight = sheetOffset }
                        let proposed = (dragStartHeight ?? sheetOffset) - value.translation.height
                        let clamped = max(snaps.peek, min(snaps.full, proposed))
                        translation = clamped - (dragStartHeight ?? sheetOffset)
                    }
                    .onEnded { value in
                        let velocity = -value.velocity.height
                        let proposed = (dragStartHeight ?? sheetOffset) - value.translation.height
                        let currentHeight = max(snaps.peek, min(snaps.full, proposed))
                        let targets = [snaps.peek, snaps.mid, snaps.full]
                        let target: CGFloat
                        if velocity > 500 { target = targets.last! }
                        else if velocity < -500 { target = targets.first! }
                        else { target = targets.min(by: { abs($0 - currentHeight) < abs($1 - currentHeight) }) ?? snaps.mid }

                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            sheetOffset = target
                            translation = 0
                        }
                        dragStartHeight = nil
                    }
            )
            .onAppear {
                if sheetOffset == 0 { sheetOffset = snaps.peek }
            }
            .allowsHitTesting(true)
            .accessibilityElement(children: .contain)
        }
    }
}
