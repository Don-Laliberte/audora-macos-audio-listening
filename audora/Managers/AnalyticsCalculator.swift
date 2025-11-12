import Foundation

/// Calculates speech analytics from transcript chunks
class AnalyticsCalculator {
    
    /// Analyze transcript chunks and generate speech analytics
    /// - Parameters:
    ///   - chunks: The transcript chunks to analyze
    ///   - durationMinutes: Duration of the recording in minutes
    /// - Returns: Speech analytics data
    static func analyzeTranscript(chunks: [TranscriptChunk], durationMinutes: Double) -> SpeechAnalytics? {
        // Filter to final chunks only
        let finalChunks = chunks.filter { $0.isFinal }
        
        guard !finalChunks.isEmpty else {
            return nil
        }
        
        // Combine all text
        let fullText = finalChunks.map { $0.text }.joined(separator: " ")
        let lowercaseText = fullText.lowercased()
        
        // Split into words and filter empty
        let words = lowercaseText.split(separator: " ").map { String($0) }.filter { !$0.isEmpty }
        let wordCount = words.count
        
        guard wordCount > 0 else {
            return nil
        }
        
        // 1. Filler Word Detection
        let fillerInstances = detectFillerWords(words: words)
        let fillerRate = Double(fillerInstances.count) / max(durationMinutes, 0.1)
        
        let fillerWords = FillerWords(
            count: fillerInstances.count,
            ratePerMinute: fillerRate,
            instances: Array(fillerInstances.prefix(20))
        )
        
        // 2. Pacing Metrics
        let wordsPerMinute = Int(Double(wordCount) / max(durationMinutes, 0.1))
        let pacing = PacingMetrics(
            wordsPerMinute: wordsPerMinute,
            averagePauseDuration: nil,
            longestPause: nil
        )
        
        // 3. Repetition Detection
        let (repeatedWords, repeatedPhrases) = detectRepetitions(words: words)
        let repetitions = Repetitions(
            repeatedWords: repeatedWords,
            repeatedPhrases: repeatedPhrases
        )
        
        // 4. Sentence Starter Analysis
        let sentences = fullText.split(separator: ".").map { String($0.trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.isEmpty }
        let (weakStarters, weakStarterCount) = analyzeSentenceStarters(sentences: sentences)
        let sentenceStarters = SentenceStarters(
            total: sentences.count,
            weak: weakStarters
        )
        
        // 5. Weak Word Detection
        let weakWordInstances = detectWeakWords(sentences: sentences)
        
        // 6. Calculate Scores (0-100)
        let clarityScore = calculateClarityScore(fillerCount: fillerInstances.count, wordCount: wordCount)
        let concisenessScore = calculateConcisenessScore(repeatedWords: repeatedWords, wordCount: wordCount)
        let confidenceScore = calculateConfidenceScore(weakStarterCount: weakStarterCount, totalSentences: sentences.count)
        
        let scores = AnalyticsScores(
            clarity: clarityScore,
            conciseness: concisenessScore,
            confidence: confidenceScore
        )
        
        return SpeechAnalytics(
            fillerWords: fillerWords,
            pacing: pacing,
            repetitions: repetitions,
            sentenceStarters: sentenceStarters,
            weakWords: weakWordInstances,
            scores: scores
        )
    }
    
    // MARK: - Private Helper Methods
    
    private static func detectFillerWords(words: [String]) -> [FillerWordInstance] {
        var instances: [FillerWordInstance] = []
        
        for (index, word) in words.enumerated() {
            if AnalyticsConstants.fillerWords.contains(word) {
                instances.append(FillerWordInstance(word: word, position: index))
            }
        }
        
        return instances
    }
    
    private static func detectRepetitions(words: [String]) -> ([RepeatedWord], [RepeatedPhrase]) {
        // Detect repeated words
        var wordFrequency: [String: Int] = [:]
        
        for word in words {
            if !AnalyticsConstants.stopWords.contains(word) && word.count >= AnalyticsConstants.minWordLength {
                wordFrequency[word, default: 0] += 1
            }
        }
        
        let repeatedWords = wordFrequency
            .filter { $0.value >= AnalyticsConstants.minRepetitionCount }
            .map { RepeatedWord(word: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(10)
        
        // Detect repeated phrases (2-word sequences)
        var phraseFrequency: [String: Int] = [:]
        
        for i in 0..<(words.count - 1) {
            let phrase = "\(words[i]) \(words[i + 1])"
            if !AnalyticsConstants.stopWords.contains(words[i]) || !AnalyticsConstants.stopWords.contains(words[i + 1]) {
                phraseFrequency[phrase, default: 0] += 1
            }
        }
        
        let repeatedPhrases = phraseFrequency
            .filter { $0.value >= AnalyticsConstants.minPhraseRepetitionCount }
            .map { RepeatedPhrase(phrase: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(5)
        
        return (Array(repeatedWords), Array(repeatedPhrases))
    }
    
    private static func analyzeSentenceStarters(sentences: [String]) -> ([WeakStarter], Int) {
        var weakStarterFreq: [String: Int] = [:]
        var totalWeakStarters = 0
        
        for sentence in sentences {
            let firstWord = sentence.lowercased().split(separator: " ").first.map { String($0) }
            
            if let firstWord = firstWord, AnalyticsConstants.weakStarters.contains(firstWord) {
                weakStarterFreq[firstWord, default: 0] += 1
                totalWeakStarters += 1
            }
        }
        
        let weakStarters = weakStarterFreq
            .map { WeakStarter(word: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
        
        return (weakStarters, totalWeakStarters)
    }
    
    private static func detectWeakWords(sentences: [String]) -> [WeakWordInstance] {
        var instances: [WeakWordInstance] = []
        
        for sentence in sentences {
            let lowerSentence = sentence.lowercased()
            
            for weakWord in AnalyticsConstants.weakWords {
                if lowerSentence.contains(weakWord) {
                    instances.append(WeakWordInstance(
                        word: weakWord,
                        sentence: sentence.trimmingCharacters(in: .whitespaces),
                        suggestion: nil
                    ))
                }
            }
        }
        
        return Array(instances.prefix(10))
    }
    
    // MARK: - Score Calculations
    
    private static func calculateClarityScore(fillerCount: Int, wordCount: Int) -> Int {
        let fillerRate = (Double(fillerCount) / Double(wordCount)) * 100.0
        let score = 100.0 - (fillerRate * 10.0)
        return max(0, min(100, Int(score.rounded())))
    }
    
    private static func calculateConcisenessScore(repeatedWords: [RepeatedWord], wordCount: Int) -> Int {
        let totalRepetitions = repeatedWords.reduce(0) { $0 + $1.count }
        let repetitionRate = Double(totalRepetitions) / Double(wordCount)
        let score = 100.0 - (repetitionRate * 50.0)
        return max(0, min(100, Int(score.rounded())))
    }
    
    private static func calculateConfidenceScore(weakStarterCount: Int, totalSentences: Int) -> Int {
        guard totalSentences > 0 else { return 100 }
        let weakStarterRate = Double(weakStarterCount) / Double(totalSentences)
        let score = 100.0 - (weakStarterRate * 100.0)
        return max(0, min(100, Int(score.rounded())))
    }
}

