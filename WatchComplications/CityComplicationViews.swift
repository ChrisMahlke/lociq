//
//  CityComplicationViews.swift
//  LociqWatch
//
//  Draws the city complication for each watch face family.
//
//  The complication repeats the app's composition in miniature: the city's
//  outline, its name, and its population. It cannot check where the wearer
//  is, so it never draws the location dot, and it always says when the city
//  was where the watch app found the wearer: the time in the rectangular
//  family, and in the others the date once that day has passed.
//

import SwiftUI
import WidgetKit

/// The city complication for one widget family.
///
/// The family is a parameter, rather than read from the environment, so the
/// Debug complication gallery in the watch app can draw every family.
struct CityComplicationView: View {
    let entry: CityComplicationEntry
    let family: WidgetFamily

    var body: some View {
        if let snapshot = entry.snapshot {
            content(snapshot)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(for: snapshot))
        } else {
            emptyView
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("LOC IQ. Open the app to find your city.")
        }
    }

    @ViewBuilder
    private func content(_ snapshot: ComplicationSnapshot) -> some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    outlineOrSymbol(snapshot)
                        .frame(width: 26, height: 22)
                    Text(shortLine(snapshot))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                .padding(4)
            }
        case .accessoryInline:
            Text("\(snapshot.shortTitle) · \(shortLine(snapshot))")
        case .accessoryCorner:
            outlineOrSymbol(snapshot)
                .padding(4)
                .widgetLabel {
                    Text(cornerLabel(snapshot))
                }
        default:
            HStack(alignment: .center, spacing: 6) {
                if !snapshot.outline.isEmpty {
                    ComplicationOutline(rings: snapshot.outline, size: snapshot.outlineSize)
                        .frame(width: 36, height: 36)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(snapshot.title)
                        .font(.system(.headline, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .widgetAccentable()
                    Text(secondLine(snapshot))
                        .font(.system(.body, design: .rounded).weight(.light))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(snapshot.asOfLabel(now: entry.date))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Before the watch app has found the wearer: the name and what to do.
    @ViewBuilder
    private var emptyView: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "location")
                    .font(.system(size: 18, weight: .medium))
                    .widgetAccentable()
            }
        case .accessoryInline:
            Text("LOC IQ")
        case .accessoryCorner:
            Image(systemName: "location")
                .font(.system(size: 18, weight: .medium))
                .widgetAccentable()
                .widgetLabel {
                    Text("LOC IQ")
                }
        default:
            VStack(alignment: .leading, spacing: 0) {
                Text("LOC IQ")
                    .font(.system(.headline, design: .rounded))
                    .widgetAccentable()
                Text("OPEN TO FIND YOUR CITY")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The outline, or a symbol for places without one.
    @ViewBuilder
    private func outlineOrSymbol(_ snapshot: ComplicationSnapshot) -> some View {
        if !snapshot.outline.isEmpty {
            ComplicationOutline(rings: snapshot.outline, size: snapshot.outlineSize)
        } else {
            Image(systemName: snapshot.kind == .message ? "mappin.slash" : "location")
                .font(.system(size: 16, weight: .medium))
                .widgetAccentable()
        }
    }

    /// Rectangular second line: the population, or the message's detail.
    private func secondLine(_ snapshot: ComplicationSnapshot) -> String {
        switch snapshot.kind {
        case .city: return "\(snapshot.population ?? "--") PEOPLE"
        case .message: return snapshot.subtitle
        }
    }

    /// The population on the day the city was confirmed; afterwards the date.
    private func shortLine(_ snapshot: ComplicationSnapshot) -> String {
        guard entry.isFromToday else {
            return ComplicationSnapshot.shortDate(snapshot.confirmedAt, now: entry.date)
        }
        switch snapshot.kind {
        case .city: return snapshot.compactPopulation ?? "--"
        case .message: return "NO CITY"
        }
    }

    /// Corner label: the population that day; afterwards when it was true.
    private func cornerLabel(_ snapshot: ComplicationSnapshot) -> String {
        guard entry.isFromToday else { return snapshot.asOfLabel(now: entry.date) }
        switch snapshot.kind {
        case .city: return "\(snapshot.compactPopulation ?? "--") PEOPLE"
        case .message: return snapshot.title
        }
    }

    private func accessibilityLabel(for snapshot: ComplicationSnapshot) -> String {
        var parts = [SpokenText.title(snapshot.title)]
        switch snapshot.kind {
        case .city:
            parts.append("Population \(snapshot.population ?? "unavailable")")
        case .message:
            if !snapshot.subtitle.isEmpty {
                parts.append(SpokenText.title(snapshot.subtitle))
            }
        }
        parts.append(SpokenText.title(snapshot.asOfLabel(now: entry.date)))
        return parts.joined(separator: ". ")
    }
}

/// A city outline fitted into its frame: one uniform fill and a fine line.
private struct ComplicationOutline: View {
    let rings: [[CGPoint]]
    let size: CGSize

    var body: some View {
        GeometryReader { proxy in
            let path = fittedPath(in: proxy.size)
            ZStack {
                path.fill(Color.white.opacity(0.2), style: FillStyle(eoFill: true))
                path.stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
            }
        }
    }

    /// The rings, aspect-fit and centered, with a little breathing room.
    private func fittedPath(in frame: CGSize) -> Path {
        guard size.width > 0, size.height > 0 else { return Path() }
        let scale = min(frame.width / size.width, frame.height / size.height) * 0.92
        let offset = CGPoint(x: (frame.width - size.width * scale) / 2, y: (frame.height - size.height * scale) / 2)
        var path = Path()
        for ring in rings {
            guard let first = ring.first else { continue }
            path.move(to: CGPoint(x: offset.x + first.x * scale, y: offset.y + first.y * scale))
            for point in ring.dropFirst() {
                path.addLine(to: CGPoint(x: offset.x + point.x * scale, y: offset.y + point.y * scale))
            }
            path.closeSubpath()
        }
        return path
    }
}
