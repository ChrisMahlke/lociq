//
//  SpokenText.swift
//  Lociq
//
//  Rewrites uppercase display text for VoiceOver.
//
//  The interface sets titles in uppercase. VoiceOver can spell out or misread
//  uppercase words, and `capitalized` turns a state code into a word ("Ca").
//  This file has no dependencies, so the watch widget compiles it alone.
//

import Foundation

/// Display text rewritten for VoiceOver.
nonisolated enum SpokenText {
    /// Capitalizes words, keeping a trailing state code and AM or PM uppercase:
    /// `SAN FRANCISCO, CA` becomes `San Francisco, CA`, and `AS OF 9:41 AM`
    /// becomes `As Of 9:41 AM`.
    static func title(_ text: String) -> String {
        let words = text.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        return words.enumerated().map { index, word in
            let letters = word.trimmingCharacters(in: .punctuationCharacters)
            let followsComma = index > 0 && words[index - 1].hasSuffix(",")
            let isStateCode = index == words.count - 1 && followsComma && letters.count == 2 && letters.allSatisfy(\.isLetter)
            if isStateCode || letters == "AM" || letters == "PM" {
                return word
            }
            return word.capitalized
        }
        .joined(separator: " ")
    }
}
