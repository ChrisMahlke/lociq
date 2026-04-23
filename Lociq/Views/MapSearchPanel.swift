import SwiftUI

struct MapSearchLauncher: View {
    let query: String
    let onTap: () -> Void

    private var displayText: String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? AppStrings.Labels.searchPlaceholder : trimmed
    }

    private var isPlaceholder: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(displayText)
                    .font(.subheadline)
                    .foregroundStyle(isPlaceholder ? .secondary : .primary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.97))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 420, alignment: .leading)
        .accessibilityIdentifier("map.search.launcher")
    }
}

struct MapSearchExperienceView: View {
    @ObservedObject var model: MapSearchModel
    let promptTitle: String
    let promptBody: String
    let onDismiss: () -> Void
    let onSelectResult: (PlaceSearchResult) -> Void

    @FocusState private var isFieldFocused: Bool
    @State private var isSubmitting = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
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
                            submitTopResult()
                        }
                        .accessibilityIdentifier("map.search.field")

                        if model.isSearching || isSubmitting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.accentColor)
                                .scaleEffect(0.85)
                        } else if !model.query.isEmpty {
                            Button {
                                model.clear()
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
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.systemBackground))
                    )

                    Button(AppStrings.Labels.searchCancel) {
                        isFieldFocused = false
                        onDismiss()
                    }
                    .font(.body.weight(.medium))
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 14)
                .background(
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea(edges: .top)
                )

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if model.shouldShowResults {
                            if let errorMessage = model.errorMessage {
                                SearchStatusCard(
                                    symbol: "exclamationmark.triangle.fill",
                                    title: AppStrings.Labels.searchUnavailableTitle,
                                    message: errorMessage,
                                    tint: .orange
                                )
                            } else if model.isSearching || isSubmitting {
                                SearchStatusCard(
                                    symbol: "point.3.connected.trianglepath.dotted",
                                    title: AppStrings.Labels.searchingPlaces,
                                    message: AppStrings.Labels.searchingPlacesBody,
                                    tint: .blue
                                )
                            } else if model.results.isEmpty {
                                SearchStatusCard(
                                    symbol: "mappin.slash.circle.fill",
                                    title: AppStrings.Labels.noSearchResultsTitle,
                                    message: AppStrings.Labels.noSearchResultsBody,
                                    tint: .secondary
                                )
                            } else {
                                searchResultsList
                            }
                        } else {
                            SearchPromptCard(
                                title: promptTitle,
                                message: promptBody
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                isFieldFocused = true
            }
        }
    }

    private var searchResultsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
                Button {
                    chooseResult(result)
                } label: {
                    SearchResultRow(result: result)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("map.search.result.\(index)")

                if index < model.results.count - 1 {
                    Divider()
                        .padding(.leading, 56)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func chooseResult(_ result: PlaceSearchResult) {
        isFieldFocused = false
        onSelectResult(result)
        onDismiss()
    }

    private func submitTopResult() {
        guard !isSubmitting else { return }

        isSubmitting = true
        Task { @MainActor in
            let result = await model.submitSearchAndResolveTopResult()
            isSubmitting = false

            guard let result else {
                isFieldFocused = true
                return
            }

            chooseResult(result)
        }
    }
}

private struct SearchPromptCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "map.circle.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct SearchResultRow: View {
    let result: PlaceSearchResult

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(Color.accentColor.opacity(0.14))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(result.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if !result.subtitle.isEmpty {
                    Text(result.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct SearchStatusCard: View {
    let symbol: String
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(tint.opacity(0.14))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: symbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
