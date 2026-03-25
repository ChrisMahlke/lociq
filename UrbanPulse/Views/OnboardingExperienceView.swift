import SwiftUI

struct OnboardingExperienceView: View {
    let onDone: () -> Void

    @State private var pageIndex = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: AppStrings.Labels.onboardingTitleOne,
            body: AppStrings.Labels.onboardingBodyOne,
            symbol: "globe.americas.fill",
            colors: [Color(red: 0.10, green: 0.42, blue: 0.82), Color(red: 0.18, green: 0.62, blue: 0.86)]
        ),
        OnboardingPage(
            title: AppStrings.Labels.onboardingTitleTwo,
            body: AppStrings.Labels.onboardingBodyTwo,
            symbol: "square.stack.3d.up.fill",
            colors: [Color(red: 0.82, green: 0.45, blue: 0.12), Color(red: 0.95, green: 0.69, blue: 0.18)]
        ),
        OnboardingPage(
            title: AppStrings.Labels.onboardingTitleThree,
            body: AppStrings.Labels.onboardingBodyThree,
            symbol: "rectangle.portrait.and.arrow.right.fill",
            colors: [Color(red: 0.20, green: 0.56, blue: 0.36), Color(red: 0.33, green: 0.74, blue: 0.49)]
        )
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    Spacer()
                    Button(AppStrings.Labels.onboardingSkip) {
                        onDone()
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)

                TabView(selection: $pageIndex) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingCard(page: page)
                            .padding(.horizontal, 20)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button {
                    if pageIndex < pages.count - 1 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            pageIndex += 1
                        }
                    } else {
                        onDone()
                    }
                } label: {
                    Text(pageIndex == pages.count - 1 ? AppStrings.Labels.onboardingGetStarted : AppStrings.Labels.onboardingNext)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }
}

private struct OnboardingPage {
    let title: String
    let body: String
    let symbol: String
    let colors: [Color]
}

private struct OnboardingCard: View {
    let page: OnboardingPage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: page.colors, startPoint: .topLeading, endPoint: .bottomTrailing))

                Image(systemName: page.symbol)
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(height: 220)

            Text(page.title)
                .font(.title2.weight(.bold))

            Text(page.body)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
    }
}

#Preview {
    OnboardingExperienceView(onDone: {})
}
