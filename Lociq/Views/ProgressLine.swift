import SwiftUI

struct ProgressLine: View {
    let progress: Double
    var isLoading = false
    var reduceMotion = false
    @State private var loadingOffset: CGFloat = -0.28

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.24))
                    .frame(height: 1)

                if isLoading {
                    Rectangle()
                        .fill(Color.white.opacity(0.82))
                        .frame(
                            width: reduceMotion ? geometry.size.width : max(44, geometry.size.width * 0.24),
                            height: 1
                        )
                        .offset(x: reduceMotion ? 0 : geometry.size.width * loadingOffset)
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.72))
                        .frame(width: geometry.size.width * min(max(progress, 0), 1), height: 1)
                }
            }
            .clipped()
        }
        .frame(height: 1)
        .task(id: isLoading) {
            guard isLoading else {
                loadingOffset = -0.28
                return
            }
            guard !reduceMotion else {
                loadingOffset = 0
                return
            }

            while !Task.isCancelled {
                loadingOffset = -0.28
                try? await Task.sleep(nanoseconds: 35_000_000)
                guard let animation = LociqMotion.loadingSweep(reduceMotion: reduceMotion) else { return }
                withAnimation(animation) {
                    loadingOffset = 1.04
                }
                try? await Task.sleep(nanoseconds: LociqMotion.loadingSweepPauseNanoseconds)
            }
        }
        .accessibilityHidden(true)
    }
}
