//
//  LociqTests.swift
//  LociqTests
//
//  Created by Chris Mahlke on 3/2/26.
//

import Testing
@testable import Lociq

struct LociqTests {
    @Test func formatsNumberAndCurrencyValues() async throws {
        #expect(InsightsFormatting.number(12345) == "12,345")
        #expect(InsightsFormatting.currency(987654) == "$987,654")
    }

    @Test func normalizesPercentValuesIntoUnitInterval() async throws {
        #expect(InsightsFormatting.normalizedPercent(nil) == 0)
        #expect(InsightsFormatting.normalizedPercent(25) == 0.25)
        #expect(InsightsFormatting.normalizedPercent(140) == 1)
    }

    @Test func computesDemographicShareSafely() async throws {
        #expect(InsightsFormatting.demographicShare(25, totalPopulation: 100) == 0.25)
        #expect(InsightsFormatting.demographicShare(nil, totalPopulation: 100) == 0)
        #expect(InsightsFormatting.demographicShare(10, totalPopulation: 0) == 0)
    }
}
