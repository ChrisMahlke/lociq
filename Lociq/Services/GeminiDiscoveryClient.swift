import Foundation

final class GeminiDiscoveryClient: @unchecked Sendable {
    private let apiKey: String
    private let model: String
    private let session: URLSession

    nonisolated init(apiKey: String, model: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    nonisolated static func makeDefaultIfAvailable() -> GeminiDiscoveryClient? {
        let apiKey = AppConfig.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { return nil }
        return GeminiDiscoveryClient(apiKey: apiKey, model: AppConfig.geminiModel)
    }

    func planRecommendations(
        seed: DiscoveryCandidateProfile,
        candidates: [DiscoveryCandidateProfile],
        recentPlaces: [NeighborhoodLibraryEntry]
    ) async throws -> GeminiDiscoveryPlan {
        guard !candidates.isEmpty else { throw NeighborhoodDiscoveryError.noCandidates }

        let prompt = makePrompt(seed: seed, candidates: candidates, recentPlaces: recentPlaces)
        let body = makeRequestBody(prompt: prompt)

        var request = URLRequest(url: endpointURL())
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = 20
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw GeminiClientError.httpError(statusCode: httpResponse.statusCode)
        }

        let apiResponse = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
        guard let text = apiResponse.firstTextPart else {
            throw GeminiClientError.missingText
        }

        let planData = Data(text.utf8)
        return try JSONDecoder().decode(GeminiDiscoveryPlan.self, from: planData)
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
                "temperature": 0.35,
                "responseMimeType": "application/json",
                "responseJsonSchema": GeminiDiscoveryPlan.responseSchema
            ]
        ]
    }

    private func makePrompt(
        seed: DiscoveryCandidateProfile,
        candidates: [DiscoveryCandidateProfile],
        recentPlaces: [NeighborhoodLibraryEntry]
    ) -> String {
        let recentTitles = recentPlaces
            .prefix(6)
            .map(\.displayTitle)
            .joined(separator: ", ")

        let candidateText = candidates.map { candidate in
            """
            candidate_id: \(candidate.id)
            title: \(candidate.title)
            subtitle: \(candidate.subtitle)
            population: \(candidate.metrics.population ?? -1)
            median_income: \(candidate.metrics.medianIncome ?? -1)
            median_age: \(candidate.metrics.medianAge ?? -1)
            households: \(candidate.metrics.households ?? -1)
            median_home_value: \(candidate.demographics.medianHomeValue ?? -1)
            median_gross_rent: \(candidate.demographics.medianGrossRent ?? -1)
            owner_occupied_pct: \(candidate.demographics.ownerOccupiedPct ?? -1)
            remote_work_pct: \(candidate.demographics.workersWfhPct ?? -1)
            poverty_rate_pct: \(candidate.demographics.povertyRatePct ?? -1)
            """
        }
        .joined(separator: "\n\n")

        return """
        You are helping a neighborhood exploration app create discovery recommendations.

        Choose exactly three recommendations from the provided nearby candidates:
        1. hidden_gem: a nearby area that looks promising or under-the-radar.
        2. similar: the candidate most similar to the seed place.
        3. weekly: a different but plausible stretch recommendation for this week.

        Use only the provided candidate IDs. Do not invent places. Keep the writing concise, grounded in the metrics, and useful to a user deciding where to tap next.

        Seed place:
        title: \(seed.title)
        subtitle: \(seed.subtitle)
        population: \(seed.metrics.population ?? -1)
        median_income: \(seed.metrics.medianIncome ?? -1)
        median_age: \(seed.metrics.medianAge ?? -1)
        households: \(seed.metrics.households ?? -1)
        median_home_value: \(seed.demographics.medianHomeValue ?? -1)
        median_gross_rent: \(seed.demographics.medianGrossRent ?? -1)
        owner_occupied_pct: \(seed.demographics.ownerOccupiedPct ?? -1)
        remote_work_pct: \(seed.demographics.workersWfhPct ?? -1)
        poverty_rate_pct: \(seed.demographics.povertyRatePct ?? -1)

        Recent places the user has looked at:
        \(recentTitles.isEmpty ? "none" : recentTitles)

        Nearby candidates:
        \(candidateText)
        """
    }
}

private enum GeminiClientError: Error {
    case invalidResponse
    case httpError(statusCode: Int)
    case missingText
}

struct GeminiDiscoveryPlan: Codable, Sendable {
    let summary: String
    let recommendations: [GeminiDiscoverySelection]

    static let responseSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "summary": [
                "type": "string",
                "description": "One short overview sentence about what stands out across the recommendations."
            ],
            "recommendations": [
                "type": "array",
                "minItems": 3,
                "maxItems": 3,
                "items": [
                    "type": "object",
                    "properties": [
                        "kind": [
                            "type": "string",
                            "enum": NeighborhoodDiscoveryKind.allCases.map(\.rawValue)
                        ],
                        "candidate_id": [
                            "type": "string",
                            "description": "Must exactly match one provided candidate_id."
                        ],
                        "summary": [
                            "type": "string",
                            "description": "One concise sentence explaining the pick."
                        ],
                        "highlights": [
                            "type": "array",
                            "minItems": 2,
                            "maxItems": 3,
                            "items": [
                                "type": "string"
                            ]
                        ]
                    ],
                    "required": ["kind", "candidate_id", "summary", "highlights"]
                ]
            ]
        ],
        "required": ["summary", "recommendations"]
    ]
}

struct GeminiDiscoverySelection: Codable, Sendable {
    let kind: NeighborhoodDiscoveryKind
    let candidateID: String
    let summary: String
    let highlights: [String]

    private enum CodingKeys: String, CodingKey {
        case kind
        case candidateID = "candidate_id"
        case summary
        case highlights
    }
}

private struct GeminiGenerateContentResponse: Codable {
    let candidates: [GeminiCandidate]?

    var firstTextPart: String? {
        candidates?
            .first?
            .content?
            .parts?
            .compactMap(\.text)
            .joined()
    }
}

private struct GeminiCandidate: Codable {
    let content: GeminiContent?
}

private struct GeminiContent: Codable {
    let parts: [GeminiPart]?
}

private struct GeminiPart: Codable {
    let text: String?
}
