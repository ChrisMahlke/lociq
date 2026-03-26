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
        let isSelected = selection == tab

        return Button {
            selection = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                Text(title)
                    .font(.caption2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.18) : Color.clear, lineWidth: 0.9)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
