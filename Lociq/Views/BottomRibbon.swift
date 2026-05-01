import SwiftUI

struct BottomRibbon: View {
    @Binding var selection: TabSelection

    var body: some View {
        HStack(spacing: 10) {
            ribbonButton(title: AppStrings.Tabs.map, systemImage: selection == .map ? IconNames.mapFilled : IconNames.map, tab: .map)
            ribbonButton(title: AppStrings.Tabs.library, systemImage: selection == .library ? IconNames.libraryFilled : IconNames.library, tab: .library)
            ribbonButton(title: AppStrings.Tabs.guide, systemImage: selection == .guide ? IconNames.guideFilled : IconNames.guide, tab: .guide)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 1)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func ribbonButton(title: String, systemImage: String, tab: TabSelection) -> some View {
        let isSelected = selection == tab
        let identifier: String = switch tab {
        case .map:
            "tab.map"
        case .library:
            "tab.library"
        case .guide:
            "tab.guide"
        }

        return Button {
            selection = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(height: 2)
                    .padding(.horizontal, 16)
            }
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier(identifier)
        .buttonStyle(.plain)
    }
}
