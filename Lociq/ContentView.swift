//
//  ContentView.swift
//  Lociq
//
//  Created by Chris Mahlke on 3/6/26.
//

import SwiftUI

struct ContentView: View {
    private let snapshot = DemographicSnapshot.sample
    @State private var isShowingDetails = false

    var body: some View {
        GeometryReader { geometry in
            let topInset = max(54, geometry.safeAreaInsets.top + 34)
            let bottomReserve: CGFloat = geometry.size.height < 520 ? 168 : 190
            let detailHeight = max(120, geometry.size.height - topInset - bottomReserve)

            ZStack(alignment: .topTrailing) {
                MinimalBackground()

                ZipBoundaryPreview()
                    .frame(
                        width: min(max(geometry.size.width * 0.28, 96), 142),
                        height: min(max(geometry.size.height * 0.19, 112), 158)
                    )
                    .padding(.top, topInset + 96)
                    .padding(.leading, 30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .accessibilityLabel("Sample ZIP code boundary")

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .trailing, spacing: 34) {
                        HeaderBlock(snapshot: snapshot)

                        FadingContentPanel(
                            snapshot: snapshot,
                            isShowingDetails: isShowingDetails
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(
                    maxWidth: min(geometry.size.width * 0.58, 310),
                    maxHeight: detailHeight,
                    alignment: .topTrailing
                )
                .padding(.top, topInset)
                .padding(.trailing, 28)

                BottomIdentity(snapshot: snapshot) {
                    withAnimation(.easeInOut(duration: 0.58)) {
                        isShowingDetails.toggle()
                    }
                }
                    .padding(.horizontal, 24)
                    .padding(.bottom, max(30, geometry.safeAreaInsets.bottom + 20))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color.lociqInk)
        .preferredColorScheme(.dark)
    }
}

private struct MinimalBackground: View {
    var body: some View {
        ZStack {
            Color.lociqInk

            Rectangle()
                .fill(Color.white.opacity(0.045))
                .frame(width: 260)
                .rotationEffect(.degrees(-31))
                .offset(x: 84, y: -150)

            VStack {
                Spacer()
                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(0.035),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1)
                .padding(.horizontal, 24)
                .padding(.bottom, 142)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct HeaderBlock: View {
    let snapshot: DemographicSnapshot

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(snapshot.market)
                .font(.system(size: 28, weight: .light, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()

            Text(snapshot.dateLabel)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))

            Text(snapshot.cadence)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .multilineTextAlignment(.trailing)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("demographics.header")
    }
}

private struct MetricBlock: View {
    let metric: DemographicMetric

    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
            Text(metric.title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))

            Text(metric.primaryValue)
                .font(.system(size: 18, weight: .light, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()

            Text(metric.detail)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.54))
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct BottomIdentity: View {
    let snapshot: DemographicSnapshot
    let onShowDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("LOCIQ")
                .font(.system(size: 52, weight: .ultraLight, design: .rounded))
                .foregroundStyle(.white.opacity(0.74))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .accessibilityIdentifier("app.brand")

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 18) {
                    Text(snapshot.mode)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))

                    Spacer(minLength: 28)

                    Button(action: onShowDetails) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white.opacity(0.68))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Info")
                }

                ProgressLine(progress: snapshot.confidence)
            }
            .frame(maxWidth: 520)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("demographics.summary")
    }
}

private struct FadingContentPanel: View {
    let snapshot: DemographicSnapshot
    let isShowingDetails: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isShowingDetails {
                DetailContent(snapshot: snapshot)
                    .transition(.opacity)
            } else {
                MetricContent(metrics: snapshot.metrics)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topTrailing)
        .animation(.easeInOut(duration: 0.58), value: isShowingDetails)
    }
}

private struct MetricContent: View {
    let metrics: [DemographicMetric]

    var body: some View {
        VStack(alignment: .trailing, spacing: 22) {
            ForEach(metrics) { metric in
                MetricBlock(metric: metric)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct DetailContent: View {
    let snapshot: DemographicSnapshot

    var body: some View {
        VStack(alignment: .trailing, spacing: 18) {
            ForEach(snapshot.detailSections) { section in
                DetailSectionView(section: section)
            }

            VStack(alignment: .trailing, spacing: 8) {
                Text("SIGNAL")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.48))

                ProgressLine(progress: snapshot.confidence)
                    .frame(maxWidth: 220)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct ZipBoundaryPreview: View {
    var body: some View {
        SampleZipBoundaryShape()
            .stroke(
                Color.white.opacity(0.18),
                style: StrokeStyle(lineWidth: 0.75, lineCap: .round, lineJoin: .round)
            )
            .background(Color.clear)
            .accessibilityHidden(true)
    }
}

private struct SampleZipBoundaryShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.47, y: rect.minY + rect.height * 0.02))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.65, y: rect.minY + rect.height * 0.08),
            control1: CGPoint(x: rect.minX + rect.width * 0.54, y: rect.minY + rect.height * 0.03),
            control2: CGPoint(x: rect.minX + rect.width * 0.58, y: rect.minY + rect.height * 0.06)
        )
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.75, y: rect.minY + rect.height * 0.06))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.87, y: rect.minY + rect.height * 0.21),
            control1: CGPoint(x: rect.minX + rect.width * 0.80, y: rect.minY + rect.height * 0.09),
            control2: CGPoint(x: rect.minX + rect.width * 0.84, y: rect.minY + rect.height * 0.14)
        )
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.95, y: rect.minY + rect.height * 0.29))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.89, y: rect.minY + rect.height * 0.45),
            control1: CGPoint(x: rect.minX + rect.width * 0.96, y: rect.minY + rect.height * 0.36),
            control2: CGPoint(x: rect.minX + rect.width * 0.93, y: rect.minY + rect.height * 0.40)
        )
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.81, y: rect.minY + rect.height * 0.53))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.91, y: rect.minY + rect.height * 0.71),
            control1: CGPoint(x: rect.minX + rect.width * 0.83, y: rect.minY + rect.height * 0.61),
            control2: CGPoint(x: rect.minX + rect.width * 0.89, y: rect.minY + rect.height * 0.65)
        )
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.96, y: rect.minY + rect.height * 0.82))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.78, y: rect.minY + rect.height * 0.92),
            control1: CGPoint(x: rect.minX + rect.width * 0.90, y: rect.minY + rect.height * 0.88),
            control2: CGPoint(x: rect.minX + rect.width * 0.85, y: rect.minY + rect.height * 0.91)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.59, y: rect.minY + rect.height * 0.98),
            control1: CGPoint(x: rect.minX + rect.width * 0.72, y: rect.minY + rect.height * 0.91),
            control2: CGPoint(x: rect.minX + rect.width * 0.67, y: rect.minY + rect.height * 0.96)
        )
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.92))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.minY + rect.height * 0.87),
            control1: CGPoint(x: rect.minX + rect.width * 0.37, y: rect.minY + rect.height * 0.95),
            control2: CGPoint(x: rect.minX + rect.width * 0.33, y: rect.minY + rect.height * 0.91)
        )
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.14, y: rect.minY + rect.height * 0.74))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.19, y: rect.minY + rect.height * 0.58),
            control1: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.minY + rect.height * 0.67),
            control2: CGPoint(x: rect.minX + rect.width * 0.13, y: rect.minY + rect.height * 0.62)
        )
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.45))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.09, y: rect.minY + rect.height * 0.29),
            control1: CGPoint(x: rect.minX + rect.width * 0.17, y: rect.minY + rect.height * 0.40),
            control2: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.35)
        )
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.minY + rect.height * 0.17))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.10),
            control1: CGPoint(x: rect.minX + rect.width * 0.11, y: rect.minY + rect.height * 0.13),
            control2: CGPoint(x: rect.minX + rect.width * 0.17, y: rect.minY + rect.height * 0.10)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.47, y: rect.minY + rect.height * 0.02),
            control1: CGPoint(x: rect.minX + rect.width * 0.33, y: rect.minY + rect.height * 0.12),
            control2: CGPoint(x: rect.minX + rect.width * 0.40, y: rect.minY + rect.height * 0.05)
        )
        path.closeSubpath()
        return path
    }
}

private struct DetailSectionView: View {
    let section: DemographicDetailSection

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Text(section.title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))

            VStack(alignment: .trailing, spacing: 7) {
                ForEach(section.rows) { row in
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 18) {
                            Text(row.label)
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(.white.opacity(0.46))
                                .lineLimit(1)

                            Spacer(minLength: 24)

                            Text(row.value)
                                .font(.system(size: 17, weight: .light, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                                .multilineTextAlignment(.trailing)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .monospacedDigit()

                        if let progress = row.progress {
                            ProgressLine(progress: progress)
                                .opacity(0.78)
                                .frame(maxWidth: 220)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ProgressLine: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.24))
                    .frame(height: 1)

                Rectangle()
                    .fill(Color.white.opacity(0.72))
                    .frame(width: geometry.size.width * min(max(progress, 0), 1), height: 1)
            }
        }
        .frame(height: 1)
        .accessibilityHidden(true)
    }
}

private struct DemographicSnapshot {
    let market: String
    let dateLabel: String
    let cadence: String
    let mode: String
    let confidence: Double
    let metrics: [DemographicMetric]
    let detailSections: [DemographicDetailSection]

    static let sample = DemographicSnapshot(
        market: "OAKLAND, CA",
        dateLabel: "MAY 12, 2026",
        cadence: "ACS 5-YEAR SAMPLE",
        mode: "DEMOGRAPHICS",
        confidence: 0.78,
        metrics: [
            DemographicMetric(
                title: "POPULATION",
                primaryValue: "437,500",
                detail: "MEDIAN AGE 37.2"
            ),
            DemographicMetric(
                title: "HOUSEHOLDS",
                primaryValue: "172,900",
                detail: "2.45 PEOPLE PER HOME"
            ),
            DemographicMetric(
                title: "INCOME",
                primaryValue: "$98,400",
                detail: "MEDIAN HOUSEHOLD"
            ),
            DemographicMetric(
                title: "RENTERS",
                primaryValue: "57%",
                detail: "43% OWNER OCCUPIED"
            ),
            DemographicMetric(
                title: "EDUCATION",
                primaryValue: "49%",
                detail: "BACHELOR'S OR HIGHER"
            )
        ],
        detailSections: [
            DemographicDetailSection(
                title: "AGE",
                rows: [
                    DemographicDetailRow(label: "UNDER 18", value: "19%"),
                    DemographicDetailRow(label: "18 TO 34", value: "28%"),
                    DemographicDetailRow(label: "35 TO 64", value: "39%"),
                    DemographicDetailRow(label: "65 PLUS", value: "14%")
                ]
            ),
            DemographicDetailSection(
                title: "HOUSING",
                rows: [
                    DemographicDetailRow(label: "MEDIAN RENT", value: "$2,180"),
                    DemographicDetailRow(label: "MEDIAN VALUE", value: "$812,000"),
                    DemographicDetailRow(label: "VACANCY", value: "5.8%")
                ]
            ),
            DemographicDetailSection(
                title: "MOBILITY",
                rows: [
                    DemographicDetailRow(label: "TRANSIT", value: "18%"),
                    DemographicDetailRow(label: "REMOTE WORK", value: "24%"),
                    DemographicDetailRow(label: "MEDIAN COMMUTE", value: "31 MIN")
                ]
            )
        ]
    )
}

private struct DemographicMetric: Identifiable {
    let id = UUID()
    let title: String
    let primaryValue: String
    let detail: String
}

private struct DemographicDetailSection: Identifiable {
    let id = UUID()
    let title: String
    let rows: [DemographicDetailRow]
}

private struct DemographicDetailRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let progress: Double?

    init(label: String, value: String, progress: Double? = nil) {
        self.label = label
        self.value = value
        self.progress = progress
    }
}

private extension Color {
    static let lociqInk = Color(red: 0.075, green: 0.075, blue: 0.072)
}

#Preview {
    ContentView()
}
