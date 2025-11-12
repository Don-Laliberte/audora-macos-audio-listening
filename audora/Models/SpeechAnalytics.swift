import Foundation

// MARK: - Speech Analytics Data Structures

struct FillerWordInstance: Codable, Identifiable, Hashable {
    let id = UUID()
    let word: String
    let position: Int
    
    enum CodingKeys: String, CodingKey {
        case word, position
    }
}

struct FillerWords: Codable, Hashable {
    let count: Int
    let ratePerMinute: Double
    let instances: [FillerWordInstance]
}

struct PacingMetrics: Codable, Hashable {
    let wordsPerMinute: Int
    let averagePauseDuration: Double?
    let longestPause: Double?
}

struct RepeatedWord: Codable, Identifiable, Hashable {
    let id = UUID()
    let word: String
    let count: Int
    
    enum CodingKeys: String, CodingKey {
        case word, count
    }
}

struct RepeatedPhrase: Codable, Identifiable, Hashable {
    let id = UUID()
    let phrase: String
    let count: Int
    
    enum CodingKeys: String, CodingKey {
        case phrase, count
    }
}

struct Repetitions: Codable, Hashable {
    let repeatedWords: [RepeatedWord]
    let repeatedPhrases: [RepeatedPhrase]
}

struct WeakStarter: Codable, Identifiable, Hashable {
    let id = UUID()
    let word: String
    let count: Int
    
    enum CodingKeys: String, CodingKey {
        case word, count
    }
}

struct SentenceStarters: Codable, Hashable {
    let total: Int
    let weak: [WeakStarter]
}

struct WeakWordInstance: Codable, Identifiable, Hashable {
    let id = UUID()
    let word: String
    let sentence: String
    let suggestion: String?
    
    enum CodingKeys: String, CodingKey {
        case word, sentence, suggestion
    }
}

struct AnalyticsScores: Codable, Hashable {
    let clarity: Int
    let conciseness: Int
    let confidence: Int
}

/// Complete speech analytics for a transcription session
struct SpeechAnalytics: Codable, Hashable {
    let fillerWords: FillerWords
    let pacing: PacingMetrics
    let repetitions: Repetitions
    let sentenceStarters: SentenceStarters
    let weakWords: [WeakWordInstance]
    let scores: AnalyticsScores
    
    /// Generate a summary string for analytics
    var summary: String {
        """
        Clarity: \(scores.clarity)/100
        Conciseness: \(scores.conciseness)/100
        Confidence: \(scores.confidence)/100
        
        Filler words: \(fillerWords.count) (\(String(format: "%.1f", fillerWords.ratePerMinute))/min)
        Speaking pace: \(pacing.wordsPerMinute) words/min
        """
    }
}

// MARK: - Analytics Constants

enum AnalyticsConstants {
    /// Common filler words to detect in speech
    static let fillerWords = [
        "um", "uh", "like", "you know", "basically", "actually", "literally",
        "sort of", "kind of", "i mean", "right", "okay", "so", "well"
    ]
    
    /// Weak sentence starters that reduce confidence
    static let weakStarters = ["and", "but", "like", "so", "well", "um", "uh"]
    
    /// Weak words that could be improved for stronger communication
    static let weakWords = [
        "thing", "stuff", "just", "really", "very", "quite", "pretty",
        "kind of", "sort of", "a bit", "maybe", "probably"
    ]
    
    /// Common stop words to ignore in repetition analysis
    static let stopWords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "in", "on", "at",
        "to", "for", "of", "with", "is", "was", "are", "were"
    ]
    
    /// Minimum word length to consider for repetition detection
    static let minWordLength = 3
    
    /// Minimum repetition count to flag a word
    static let minRepetitionCount = 3
    
    /// Minimum phrase repetition count
    static let minPhraseRepetitionCount = 2
}
