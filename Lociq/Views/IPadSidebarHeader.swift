import SwiftUI

struct IPadSidebarHeader: View {
    @Binding var selection: TabSelection

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppStrings.Labels.appTitle)
                    .font(.title2.weight(.bold))
                Text(AppStrings.Labels.ipadSidebarBody)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                button(
                    title: AppStrings.Tabs.map,
                    systemImage: selection == .map ? IconNames.mapFilled : IconNames.map,
                    tab: .map
                )
                button(
                    title: AppStrings.Tabs.library,
                    systemImage: selection == .library ? IconNames.libraryFilled : IconNames.library,
                    tab: .library
                )
                button(
                    title: AppStrings.Tabs.guide,
                    systemImage: selection == .guide ? IconNames.guideFilled : IconNames.guide,
                    tab: .guide
                )
            }
        }
    }

    private func button(title: String, systemImage: String, tab: TabSelection) -> some View {
        let isSelected = selection == tab
        let identifier: String = switch tab {
        case .map:
            "sidebar.map"
        case .library:
            "sidebar.library"
        case .guide:
            "sidebar.guide"
        }

        return Button {
            selection = tab
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(.systemBackground))
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(height: 2)
                    .padding(.horizontal, 14)
            }
        }
        .accessibilityIdentifier(identifier)
        .buttonStyle(.plain)
    }
}
