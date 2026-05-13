//
//  ContentView.swift
//  Lociq
//
//  Created by Chris Mahlke on 3/6/26.
//

import Combine
import CoreLocation
import SwiftUI

struct ContentView: View {
    @StateObject private var locationAccess = LocationAccessModel()
    @StateObject private var locationProfile = GeminiLocationProfileModel()
    @StateObject private var boundaryModel = BoundaryGeometryModel()
    @State private var isShowingDetails = false
    @State private var isLoadingContent = false

    private var displaySnapshot: DemographicSnapshot {
        guard locationAccess.canUseLocation else { return .placeholder }
        return locationProfile.snapshot ?? .loading
    }

    var body: some View {
        GeometryReader { geometry in
            let topInset = max(54, geometry.safeAreaInsets.top + 34)
            let bottomReserve: CGFloat = geometry.size.height < 520 ? 168 : 190
            let detailHeight = max(120, geometry.size.height - topInset - bottomReserve)

            ZStack(alignment: .topTrailing) {
                MinimalBackground()

                ZipBoundaryPreview(
                    boundary: boundaryModel.boundary,
                    traceToken: boundaryModel.traceToken + (locationAccess.canUseLocation ? 1 : 0)
                )
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
                        HeaderBlock(snapshot: displaySnapshot)

                        FadingContentPanel(
                            snapshot: displaySnapshot,
                            isShowingDetails: isShowingDetails,
                            locationInsight: locationProfile.displayText
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(
                    maxWidth: min(geometry.size.width * 0.64, 340),
                    maxHeight: detailHeight,
                    alignment: .topTrailing
                )
                .padding(.top, topInset)
                .padding(.trailing, 28)

                BottomIdentity(
                    snapshot: displaySnapshot,
                    isShowingDetails: isShowingDetails,
                    isLoading: isLoadingContent || locationProfile.isLoading
                ) {
                    cycleContent()
                }
                    .padding(.horizontal, 24)
                    .padding(.bottom, max(30, geometry.safeAreaInsets.bottom + 20))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color.lociqInk)
        .preferredColorScheme(.dark)
        .onAppear {
            locationAccess.requestAccessIfNeeded()
        }
        .onReceive(locationAccess.$coordinate.compactMap { $0 }) { coordinate in
            locationProfile.load(for: coordinate)
            boundaryModel.load(for: coordinate)
        }
    }

    private func cycleContent() {
        guard !isLoadingContent else { return }

        withAnimation(.easeInOut(duration: 0.18)) {
            isLoadingContent = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.easeInOut(duration: 0.62)) {
                isShowingDetails.toggle()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
            withAnimation(.easeInOut(duration: 0.32)) {
                isLoadingContent = false
            }
        }
    }
}

private final class LocationAccessModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var coordinate: CLLocationCoordinate2D?

    private let manager = CLLocationManager()

    var canUseLocation: Bool {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        case .denied, .notDetermined, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestAccessIfNeeded() {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if canUseLocation {
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        guard canUseLocation else { return }
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        coordinate = locations.last?.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        coordinate = nil
    }
}

@MainActor
private final class GeminiLocationProfileModel: ObservableObject {
    @Published private(set) var displayText = "WAITING FOR LOCATION"
    @Published private(set) var snapshot: DemographicSnapshot?
    @Published private(set) var isLoading = false

    private let geminiClient = GeminiLocationInsightClient.makeDefaultIfAvailable()
    private var lastCoordinateKey: String?

    func load(for coordinate: CLLocationCoordinate2D) {
        let coordinateKey = String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
        guard coordinateKey != lastCoordinateKey else { return }
        lastCoordinateKey = coordinateKey

        isLoading = true
        displayText = "ASKING GEMINI"
        snapshot = .loading

        Task {
            guard let geminiClient else {
                displayText = "ADD GEMINI KEY"
                snapshot = .geminiKeyMissing
                isLoading = false
                return
            }

            do {
                let insight = try await geminiClient.censusProfile(for: coordinate)
                snapshot = insight.snapshot
                displayText = insight.summary.uppercased()
            } catch {
                displayText = "GEMINI UNAVAILABLE"
                snapshot = .geminiUnavailable
            }
            isLoading = false
        }
    }
}

@MainActor
private final class BoundaryGeometryModel: ObservableObject {
    @Published private(set) var boundary: GeoJSONFeatureCollection?
    @Published private(set) var traceToken = 0

    private let geocoderClient: CensusGeocoderClient
    private let boundaryClient: TIGERBoundaryClient
    private var lastCoordinateKey: String?

    init() {
        let httpClient = CensusHTTPClient(session: .shared)
        geocoderClient = CensusGeocoderClient(httpClient: httpClient)
        boundaryClient = TIGERBoundaryClient(httpClient: httpClient)
    }

    func load(for coordinate: CLLocationCoordinate2D) {
        let coordinateKey = String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
        guard coordinateKey != lastCoordinateKey else { return }
        lastCoordinateKey = coordinateKey

        Task {
            do {
                let geography = try await geocoderClient.fetchGeographiesFromCoordinate(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
                var resolvedBoundary = await boundaryClient.fetchPlaceBoundary(place: geography.place)
                if resolvedBoundary == nil {
                    resolvedBoundary = await boundaryClient.fetchTractBoundary(tractGeoid: geography.tract?.geoid)
                }
                if resolvedBoundary == nil {
                    resolvedBoundary = try? await boundaryClient.fetchZCTABoundaryGeoJSON(zcta: geography.zcta)
                }

                if let resolvedBoundary {
                    boundary = resolvedBoundary
                    traceToken += 1
                }
            } catch {
                boundary = nil
                traceToken += 1
            }
        }
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
    let isShowingDetails: Bool
    let isLoading: Bool
    let onShowDetails: () -> Void

    private var iconName: String {
        isShowingDetails ? "house" : "list.bullet.rectangle"
    }

    private var actionLabel: String {
        isShowingDetails ? "Show home view" : "Show data view"
    }

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
                        Image(systemName: iconName)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white.opacity(0.68))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                    .accessibilityLabel(actionLabel)
                }

                ProgressLine(progress: snapshot.confidence, isLoading: isLoading)
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
    let locationInsight: String

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isShowingDetails {
                DetailContent(snapshot: snapshot, locationInsight: locationInsight)
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
    let locationInsight: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 18) {
            ForEach(snapshot.detailSections) { section in
                DetailSectionView(section: section)
            }

            GeminiInsightView(text: locationInsight)

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

private struct GeminiInsightView: View {
    let text: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 7) {
            Text("GEMINI")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.48))

            Text(text)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(3)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

private final class GeminiLocationInsightClient: @unchecked Sendable {
    private let apiKey: String
    private let model: String
    private let session: URLSession

    nonisolated init(apiKey: String, model: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    nonisolated static func makeDefaultIfAvailable() -> GeminiLocationInsightClient? {
        let apiKey = AppConfig.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { return nil }
        return GeminiLocationInsightClient(apiKey: apiKey, model: AppConfig.geminiModel)
    }

    func censusProfile(for coordinate: CLLocationCoordinate2D) async throws -> GeminiLocationInsight {
        let prompt = """
        You are helping a minimal demographic iOS app.

        Coordinates:
        latitude: \(coordinate.latitude)
        longitude: \(coordinate.longitude)

        Identify the likely city/locality for these coordinates. Return display-ready census demographic values for the app fields. Use the best available U.S. Census public data you know for the matching city, place, tract, or ZIP-like area. If you are uncertain, use "--" for that field rather than inventing a number.

        Do not default to Oakland unless the coordinates are actually in or near Oakland. Keep all values concise and formatted for direct UI display.
        """

        var request = URLRequest(url: endpointURL())
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = 18
        request.httpBody = try JSONSerialization.data(withJSONObject: makeRequestBody(prompt: prompt), options: [])

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiLocationInsightError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw GeminiLocationInsightError.httpError(httpResponse.statusCode)
        }

        let apiResponse = try JSONDecoder().decode(GeminiLocationGenerateContentResponse.self, from: data)
        guard let text = apiResponse.firstTextPart else {
            throw GeminiLocationInsightError.missingText
        }

        return try JSONDecoder().decode(GeminiLocationInsight.self, from: Data(text.utf8))
    }

    private func endpointURL() -> URL {
        URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
    }

    private func makeRequestBody(prompt: String) -> [String: Any] {
        [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2,
                "responseMimeType": "application/json",
                "responseJsonSchema": GeminiLocationInsight.responseSchema
            ]
        ]
    }
}

private enum GeminiLocationInsightError: Error {
    case invalidResponse
    case httpError(Int)
    case missingText
}

private struct GeminiLocationInsight: Codable {
    let area: String
    let dataLabel: String
    let summary: String
    let population: String
    let households: String
    let medianAge: String
    let medianHouseholdIncome: String
    let rentersPercent: String
    let ownerOccupiedPercent: String
    let bachelorsOrHigherPercent: String
    let under18Percent: String
    let age18To34Percent: String
    let age35To64Percent: String
    let age65PlusPercent: String
    let medianRent: String
    let medianHomeValue: String
    let vacancyPercent: String
    let transitPercent: String
    let remoteWorkPercent: String
    let medianCommute: String

    var snapshot: DemographicSnapshot {
        DemographicSnapshot(
            market: area.uppercased(),
            dateLabel: dataLabel.uppercased(),
            cadence: "GEMINI CENSUS",
            mode: "DEMOGRAPHICS",
            confidence: 0.62,
            metrics: [
                DemographicMetric(
                    title: "POPULATION",
                    primaryValue: population,
                    detail: "MEDIAN AGE \(medianAge)"
                ),
                DemographicMetric(
                    title: "HOUSEHOLDS",
                    primaryValue: households,
                    detail: "CENSUS STYLE"
                ),
                DemographicMetric(
                    title: "INCOME",
                    primaryValue: medianHouseholdIncome,
                    detail: "MEDIAN HOUSEHOLD"
                ),
                DemographicMetric(
                    title: "RENTERS",
                    primaryValue: rentersPercent,
                    detail: "\(ownerOccupiedPercent) OWNER OCCUPIED"
                ),
                DemographicMetric(
                    title: "EDUCATION",
                    primaryValue: bachelorsOrHigherPercent,
                    detail: "BACHELOR'S OR HIGHER"
                )
            ],
            detailSections: [
                DemographicDetailSection(
                    title: "AGE",
                    rows: [
                        DemographicDetailRow(label: "UNDER 18", value: under18Percent),
                        DemographicDetailRow(label: "18 TO 34", value: age18To34Percent),
                        DemographicDetailRow(label: "35 TO 64", value: age35To64Percent),
                        DemographicDetailRow(label: "65 PLUS", value: age65PlusPercent)
                    ]
                ),
                DemographicDetailSection(
                    title: "HOUSING",
                    rows: [
                        DemographicDetailRow(label: "MEDIAN RENT", value: medianRent),
                        DemographicDetailRow(label: "MEDIAN VALUE", value: medianHomeValue),
                        DemographicDetailRow(label: "VACANCY", value: vacancyPercent)
                    ]
                ),
                DemographicDetailSection(
                    title: "MOBILITY",
                    rows: [
                        DemographicDetailRow(label: "TRANSIT", value: transitPercent),
                        DemographicDetailRow(label: "REMOTE WORK", value: remoteWorkPercent),
                        DemographicDetailRow(label: "MEDIAN COMMUTE", value: medianCommute)
                    ]
                )
            ]
        )
    }

    private enum CodingKeys: String, CodingKey {
        case area
        case dataLabel = "data_label"
        case summary
        case population
        case households
        case medianAge = "median_age"
        case medianHouseholdIncome = "median_household_income"
        case rentersPercent = "renters_percent"
        case ownerOccupiedPercent = "owner_occupied_percent"
        case bachelorsOrHigherPercent = "bachelors_or_higher_percent"
        case under18Percent = "under_18_percent"
        case age18To34Percent = "age_18_to_34_percent"
        case age35To64Percent = "age_35_to_64_percent"
        case age65PlusPercent = "age_65_plus_percent"
        case medianRent = "median_rent"
        case medianHomeValue = "median_home_value"
        case vacancyPercent = "vacancy_percent"
        case transitPercent = "transit_percent"
        case remoteWorkPercent = "remote_work_percent"
        case medianCommute = "median_commute"
    }

    static let responseSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "area": [
                "type": "string",
                "description": "Likely city/locality and state or region, such as 'Pasadena, CA'."
            ],
            "data_label": [
                "type": "string",
                "description": "Short source/vintage label, such as 'CENSUS ESTIMATE' or 'RECENT CENSUS'."
            ],
            "summary": [
                "type": "string",
                "description": "One concise demographic context sentence."
            ],
            "population": [
                "type": "string",
                "description": "Display-ready population, formatted like '152,000' or '--'."
            ],
            "households": [
                "type": "string",
                "description": "Display-ready households, formatted like '58,000' or '--'."
            ],
            "median_age": [
                "type": "string",
                "description": "Display-ready median age, formatted like '39.4' or '--'."
            ],
            "median_household_income": [
                "type": "string",
                "description": "Display-ready median household income, formatted like '$92,000' or '--'."
            ],
            "renters_percent": [
                "type": "string",
                "description": "Display-ready renter household percent, formatted like '54%' or '--'."
            ],
            "owner_occupied_percent": [
                "type": "string",
                "description": "Display-ready owner-occupied household percent, formatted like '46%' or '--'."
            ],
            "bachelors_or_higher_percent": [
                "type": "string",
                "description": "Display-ready bachelor's degree or higher percent, formatted like '41%' or '--'."
            ],
            "under_18_percent": [
                "type": "string",
                "description": "Display-ready under 18 percent, formatted like '19%' or '--'."
            ],
            "age_18_to_34_percent": [
                "type": "string",
                "description": "Display-ready age 18 to 34 percent, formatted like '28%' or '--'."
            ],
            "age_35_to_64_percent": [
                "type": "string",
                "description": "Display-ready age 35 to 64 percent, formatted like '39%' or '--'."
            ],
            "age_65_plus_percent": [
                "type": "string",
                "description": "Display-ready age 65 plus percent, formatted like '14%' or '--'."
            ],
            "median_rent": [
                "type": "string",
                "description": "Display-ready median rent, formatted like '$2,100' or '--'."
            ],
            "median_home_value": [
                "type": "string",
                "description": "Display-ready median home value, formatted like '$780,000' or '--'."
            ],
            "vacancy_percent": [
                "type": "string",
                "description": "Display-ready vacancy percent, formatted like '5.2%' or '--'."
            ],
            "transit_percent": [
                "type": "string",
                "description": "Display-ready commute by public transit percent, formatted like '12%' or '--'."
            ],
            "remote_work_percent": [
                "type": "string",
                "description": "Display-ready remote work percent, formatted like '22%' or '--'."
            ],
            "median_commute": [
                "type": "string",
                "description": "Display-ready median commute, formatted like '29 MIN' or '--'."
            ]
        ],
        "required": [
            "area",
            "data_label",
            "summary",
            "population",
            "households",
            "median_age",
            "median_household_income",
            "renters_percent",
            "owner_occupied_percent",
            "bachelors_or_higher_percent",
            "under_18_percent",
            "age_18_to_34_percent",
            "age_35_to_64_percent",
            "age_65_plus_percent",
            "median_rent",
            "median_home_value",
            "vacancy_percent",
            "transit_percent",
            "remote_work_percent",
            "median_commute"
        ]
    ]
}

private struct GeminiLocationGenerateContentResponse: Codable {
    let candidates: [GeminiLocationCandidate]?

    var firstTextPart: String? {
        candidates?
            .first?
            .content?
            .parts?
            .compactMap(\.text)
            .joined()
    }
}

private struct GeminiLocationCandidate: Codable {
    let content: GeminiLocationContent?
}

private struct GeminiLocationContent: Codable {
    let parts: [GeminiLocationPart]?
}

private struct GeminiLocationPart: Codable {
    let text: String?
}

private struct ZipBoundaryPreview: View {
    let boundary: GeoJSONFeatureCollection?
    let traceToken: Int
    @State private var traceProgress: CGFloat = 0
    @State private var connectorProgress: CGFloat = 0

    var body: some View {
        ZStack {
            BoundaryPreviewShape(boundary: boundary)
                .trim(from: 0, to: traceProgress)
                .stroke(
                    Color.white.opacity(0.18),
                    style: StrokeStyle(lineWidth: 0.75, lineCap: .round, lineJoin: .round)
                )

            BoundaryConnectorShape()
                .trim(from: 0, to: connectorProgress)
                .stroke(
                    Color.white.opacity(0.10),
                    style: StrokeStyle(lineWidth: 0.5, lineCap: .round)
                )
        }
        .background(Color.clear)
            .onAppear {
                traceBoundary()
            }
            .onChange(of: traceToken) { _ in
                traceBoundary()
            }
            .accessibilityHidden(true)
    }

    private func traceBoundary() {
        withAnimation(.none) {
            traceProgress = 0
            connectorProgress = 0
        }
        withAnimation(.easeInOut(duration: 2.2).delay(0.18)) {
            traceProgress = 1
        }
        withAnimation(.easeOut(duration: 1.05).delay(2.55)) {
            connectorProgress = 1
        }
    }
}

private struct BoundaryConnectorShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.maxY - rect.height * 0.08))
        return path
    }
}

private struct BoundaryPreviewShape: Shape {
    let boundary: GeoJSONFeatureCollection?

    func path(in rect: CGRect) -> Path {
        guard
            let boundary,
            let boundaryPath = GeoJSONBoundaryPathBuilder.path(for: boundary, in: rect)
        else {
            return SampleZipBoundaryShape().path(in: rect)
        }

        return boundaryPath
    }
}

private enum GeoJSONBoundaryPathBuilder {
    nonisolated static func path(for boundary: GeoJSONFeatureCollection, in rect: CGRect) -> Path? {
        let rings = boundary.features
            .compactMap(\.geometry)
            .flatMap(exteriorRings(from:))
            .filter { $0.count > 2 }

        guard !rings.isEmpty else { return nil }

        let points = rings.flatMap { ring in
            ring.compactMap { coordinate -> CGPoint? in
                guard coordinate.count >= 2 else { return nil }
                return CGPoint(x: coordinate[0], y: coordinate[1])
            }
        }

        guard
            let minLon = points.map(\.x).min(),
            let maxLon = points.map(\.x).max(),
            let minLat = points.map(\.y).min(),
            let maxLat = points.map(\.y).max(),
            maxLon > minLon,
            maxLat > minLat
        else {
            return nil
        }

        let longitudeSpan = maxLon - minLon
        let latitudeSpan = maxLat - minLat
        let scale = min(rect.width / longitudeSpan, rect.height / latitudeSpan) * 0.92
        let drawingWidth = longitudeSpan * scale
        let drawingHeight = latitudeSpan * scale
        let xOffset = rect.midX - drawingWidth / 2
        let yOffset = rect.midY - drawingHeight / 2

        var path = Path()
        for ring in rings {
            var didMove = false
            for coordinate in ring where coordinate.count >= 2 {
                let x = xOffset + (coordinate[0] - minLon) * scale
                let y = yOffset + (maxLat - coordinate[1]) * scale
                let point = CGPoint(x: x, y: y)

                if didMove {
                    path.addLine(to: point)
                } else {
                    path.move(to: point)
                    didMove = true
                }
            }
            path.closeSubpath()
        }

        return path
    }

    nonisolated private static func exteriorRings(from geometry: GeoJSONGeometry) -> [[[Double]]] {
        switch geometry {
        case .polygon(let rings):
            return rings.first.map { [$0] } ?? []
        case .multiPolygon(let polygons):
            return polygons.compactMap(\.first)
        case .other:
            return []
        }
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
                                .minimumScaleFactor(0.78)
                                .allowsTightening(true)

                            Spacer(minLength: 16)

                            Text(row.value)
                                .font(.system(size: 17, weight: .light, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                                .minimumScaleFactor(0.82)
                                .allowsTightening(true)
                                .fixedSize(horizontal: false, vertical: true)
                                .layoutPriority(1)
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
    var isLoading = false
    @State private var loadingOffset: CGFloat = -0.28

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.24))
                    .frame(height: 1)

                if isLoading {
                    Rectangle()
                        .fill(Color.white.opacity(0.82))
                        .frame(width: max(44, geometry.size.width * 0.24), height: 1)
                        .offset(x: geometry.size.width * loadingOffset)
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.72))
                        .frame(width: geometry.size.width * min(max(progress, 0), 1), height: 1)
                }
            }
            .clipped()
        }
        .frame(height: 1)
        .task(id: isLoading) {
            guard isLoading else {
                loadingOffset = -0.28
                return
            }

            while !Task.isCancelled {
                loadingOffset = -0.28
                try? await Task.sleep(nanoseconds: 35_000_000)
                withAnimation(.linear(duration: 0.82)) {
                    loadingOffset = 1.04
                }
                try? await Task.sleep(nanoseconds: 860_000_000)
            }
        }
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

    static let placeholder = DemographicSnapshot(
        market: "LOCATION OFF",
        dateLabel: "ALLOW LOCATION",
        cadence: "DEMOGRAPHICS PAUSED",
        mode: "LOCATION OFF",
        confidence: 0,
        metrics: [
            DemographicMetric(
                title: "POPULATION",
                primaryValue: "--",
                detail: "WAITING FOR AREA"
            ),
            DemographicMetric(
                title: "HOUSEHOLDS",
                primaryValue: "--",
                detail: "WAITING FOR AREA"
            ),
            DemographicMetric(
                title: "INCOME",
                primaryValue: "--",
                detail: "WAITING FOR AREA"
            ),
            DemographicMetric(
                title: "RENTERS",
                primaryValue: "--",
                detail: "WAITING FOR AREA"
            ),
            DemographicMetric(
                title: "EDUCATION",
                primaryValue: "--",
                detail: "WAITING FOR AREA"
            )
        ],
        detailSections: [
            DemographicDetailSection(
                title: "AGE",
                rows: [
                    DemographicDetailRow(label: "UNDER 18", value: "--"),
                    DemographicDetailRow(label: "18 TO 34", value: "--"),
                    DemographicDetailRow(label: "35 TO 64", value: "--"),
                    DemographicDetailRow(label: "65 PLUS", value: "--")
                ]
            ),
            DemographicDetailSection(
                title: "HOUSING",
                rows: [
                    DemographicDetailRow(label: "MEDIAN RENT", value: "--"),
                    DemographicDetailRow(label: "MEDIAN VALUE", value: "--"),
                    DemographicDetailRow(label: "VACANCY", value: "--")
                ]
            ),
            DemographicDetailSection(
                title: "MOBILITY",
                rows: [
                    DemographicDetailRow(label: "TRANSIT", value: "--"),
                    DemographicDetailRow(label: "REMOTE WORK", value: "--"),
                    DemographicDetailRow(label: "MEDIAN COMMUTE", value: "--")
                ]
            )
        ]
    )

    static let loading = DemographicSnapshot.status(
        market: "LOCATING",
        dateLabel: "GEMINI",
        cadence: "READING AREA",
        mode: "LOADING"
    )

    static let geminiKeyMissing = DemographicSnapshot.status(
        market: "GEMINI OFF",
        dateLabel: "ADD KEY",
        cadence: "NO API KEY",
        mode: "NO KEY"
    )

    static let geminiUnavailable = DemographicSnapshot.status(
        market: "GEMINI",
        dateLabel: "UNAVAILABLE",
        cadence: "TRY AGAIN LATER",
        mode: "OFFLINE"
    )

    private static func status(
        market: String,
        dateLabel: String,
        cadence: String,
        mode: String
    ) -> DemographicSnapshot {
        DemographicSnapshot(
            market: market,
            dateLabel: dateLabel,
            cadence: cadence,
            mode: mode,
            confidence: 0,
            metrics: [
                DemographicMetric(title: "POPULATION", primaryValue: "--", detail: "WAITING FOR AREA"),
                DemographicMetric(title: "HOUSEHOLDS", primaryValue: "--", detail: "WAITING FOR AREA"),
                DemographicMetric(title: "INCOME", primaryValue: "--", detail: "WAITING FOR AREA"),
                DemographicMetric(title: "RENTERS", primaryValue: "--", detail: "WAITING FOR AREA"),
                DemographicMetric(title: "EDUCATION", primaryValue: "--", detail: "WAITING FOR AREA")
            ],
            detailSections: [
                DemographicDetailSection(
                    title: "AGE",
                    rows: [
                        DemographicDetailRow(label: "UNDER 18", value: "--"),
                        DemographicDetailRow(label: "18 TO 34", value: "--"),
                        DemographicDetailRow(label: "35 TO 64", value: "--"),
                        DemographicDetailRow(label: "65 PLUS", value: "--")
                    ]
                ),
                DemographicDetailSection(
                    title: "HOUSING",
                    rows: [
                        DemographicDetailRow(label: "MEDIAN RENT", value: "--"),
                        DemographicDetailRow(label: "MEDIAN VALUE", value: "--"),
                        DemographicDetailRow(label: "VACANCY", value: "--")
                    ]
                ),
                DemographicDetailSection(
                    title: "MOBILITY",
                    rows: [
                        DemographicDetailRow(label: "TRANSIT", value: "--"),
                        DemographicDetailRow(label: "REMOTE WORK", value: "--"),
                        DemographicDetailRow(label: "MEDIAN COMMUTE", value: "--")
                    ]
                )
            ]
        )
    }
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
