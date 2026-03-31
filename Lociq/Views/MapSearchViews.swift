import SwiftUI

struct MapSearchBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let isActive: Bool
    let isSearching: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextField("City or ZIP code", text: $text)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .submitLabel(.search)
                    .focused(isFocused)
                    .onSubmit(onSubmit)

                if isSearching {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.secondary)
                        .scaleEffect(0.9)
                } else if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            .frame(maxWidth: .infinity)

            if isActive {
                Button("Cancel", action: onCancel)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.blue)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isActive)
    }
}

struct MapSearchResultsPopup: View {
    let query: String
    let results: [LocationSearchResult]
    let onSelect: (LocationSearchResult) -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Choose a location")
                            .font(.headline.weight(.semibold))
                        Text("Found \(results.count) matches for \"\(query)\"")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color(.secondarySystemBackground), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(AppStrings.Labels.dismiss)
                }
                .padding(18)

                Divider()

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(results) { result in
                            Button {
                                onSelect(result)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.blue)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .multilineTextAlignment(.leading)

                                        if !result.subtitle.isEmpty {
                                            Text(result.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .multilineTextAlignment(.leading)
                                        }
                                    }

                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if result.id != results.last?.id {
                                Divider()
                                    .padding(.leading, 52)
                            }
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
            .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 420))
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
            .padding(.horizontal, 16)
        }
    }
}
