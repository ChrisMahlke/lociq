import SwiftUI

struct MapSearchPanel: View {
    @ObservedObject var model: MapSearchModel
    let onSelectResult: (PlaceSearchResult) -> Void

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField(
                    AppStrings.Labels.searchPlaceholder,
                    text: Binding(
                        get: { model.query },
                        set: { model.updateQuery($0) }
                    )
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isFieldFocused)
                .onSubmit {
                    model.submitSearch()
                }
                .accessibilityIdentifier("map.search.field")

                if model.isSearching {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.accentColor)
                        .scaleEffect(0.85)
                } else if !model.query.isEmpty {
                    Button {
                        model.clear()
                        isFieldFocused = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("map.search.clear")
                    .accessibilityLabel(AppStrings.Labels.clearSearch)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.10), radius: 10, y: 4)

            if model.shouldShowResults {
                VStack(alignment: .leading, spacing: 0) {
                    if let errorMessage = model.errorMessage {
                        SearchStatusRow(
                            symbol: "exclamationmark.triangle.fill",
                            title: AppStrings.Labels.searchUnavailableTitle,
                            message: errorMessage,
                            tint: .orange
                        )
                    } else if model.isSearching {
                        SearchStatusRow(
                            symbol: "point.3.connected.trianglepath.dotted",
                            title: AppStrings.Labels.searchingPlaces,
                            message: AppStrings.Labels.searchingPlacesBody,
                            tint: .blue
                        )
                    } else if model.results.isEmpty {
                        SearchStatusRow(
                            symbol: "mappin.slash.circle.fill",
                            title: AppStrings.Labels.noSearchResultsTitle,
                            message: AppStrings.Labels.noSearchResultsBody,
                            tint: .secondary
                        )
                    } else {
                        ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
                            Button {
                                isFieldFocused = false
                                onSelectResult(result)
                            } label: {
                                SearchResultRow(result: result)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("map.search.result.\(index)")

                            if index < model.results.count - 1 {
                                Divider()
                                    .padding(.leading, 48)
                            }
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.97))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: 420, alignment: .leading)
        .animation(.easeInOut(duration: 0.2), value: model.shouldShowResults)
    }
}

private struct SearchResultRow: View {
    let result: PlaceSearchResult

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.accentColor.opacity(0.14))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if !result.subtitle.isEmpty {
                    Text(result.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct SearchStatusRow: View {
    let symbol: String
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(tint.opacity(0.14))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: symbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }
}
