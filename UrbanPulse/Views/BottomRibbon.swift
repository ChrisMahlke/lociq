import SwiftUI

struct BottomRibbon: View {
    @Binding var selection: TabSelection

    var body: some View {
        HStack(spacing: 0) {
            ribbonButton(title: AppStrings.Tabs.map, systemImage: selection == .map ? IconNames.mapFilled : IconNames.map, tab: .map)
            ribbonButton(title: AppStrings.Tabs.more, systemImage: selection == .more ? IconNames.moreFilled : IconNames.more, tab: .more)
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(
            Color(.secondarySystemBackground)
                .opacity(0.96)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.14))
                .frame(height: 1)
        }
        .shadow(color: .black.opacity(0.10), radius: 10, y: -1)
            .ignoresSafeArea(edges: .bottom)
    }

    private func ribbonButton(title: String, systemImage: String, tab: TabSelection) -> some View {
        Button {
            selection = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                Text(title)
                    .font(.caption2)
                Capsule()
                    .fill(selection == tab ? Color.accentColor : Color.clear)
                    .frame(height: 3)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(selection == tab ? .accentColor : .secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
