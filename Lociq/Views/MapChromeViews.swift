import SwiftUI

struct MapFloatingControls: View {
    let onFocusMyArea: () -> Void

    var body: some View {
        button(
            icon: "location.fill",
            title: AppStrings.More.myArea,
            action: onFocusMyArea
        )
    }

    private func button(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .frame(width: 18, height: 18)
                .foregroundStyle(.primary)
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.10), lineWidth: 0.8)
                )
                .shadow(color: .black.opacity(0.10), radius: 10, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct MissingGoogleMapsKeyView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.93, green: 0.96, blue: 0.99), Color(red: 0.90, green: 0.94, blue: 0.98)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 14) {
                Image(systemName: "key.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.orange)

                Text(AppStrings.Labels.googleMapsKeyRequired)
                    .font(.title3.weight(.semibold))

                Text(AppStrings.Labels.googleMapsKeyBody)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
        }
    }
}

struct MapQuickTipCard: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hand.tap.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.blue)
                .frame(width: 30, height: 30)
                .background(Color.blue.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(AppStrings.Labels.mapTipTitle)
                    .font(.subheadline.weight(.semibold))
                Text(AppStrings.Labels.mapTipBody)
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Color(.systemBackground).opacity(0.7), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppStrings.Labels.dismiss)
        }
        .padding(12)
        .frame(maxWidth: 250, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.blue.opacity(0.15), lineWidth: 0.9)
        )
        .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
    }
}

struct MapLoadingOverlay: View {
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.08)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.blue)
                    .scaleEffect(1.15)

                VStack(spacing: 4) {
                    Text(AppStrings.Labels.loadingBoundary)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(AppStrings.Labels.updatingNeighborhoodOutline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                }

                Button(AppStrings.Labels.cancel, action: onCancel)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(.blue)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.12), radius: 16, y: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MapNoticeBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "mappin.slash.circle.fill")
                .font(.title3)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 4) {
                Text(AppStrings.Labels.locationUnavailable)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color(red: 0.91, green: 0.30, blue: 0.28), Color(red: 0.78, green: 0.18, blue: 0.27)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 10, y: 3)
    }
}

struct OptionalTopSafeAreaIgnoring: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.ignoresSafeArea(edges: .top)
        } else {
            content
        }
    }
}
