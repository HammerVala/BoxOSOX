import Foundation
import AVFoundation

public class SpeechAnalyzer {
    private let silenceThreshold: Float
    private let minSilenceDuration: TimeInterval
    private let sampleRate: Double
    private let patternDetector: SpeechPatternDetector
    private let speakerDetector: SpeakerDetector
    
    public struct SpeechSegment {
        public let startTime: TimeInterval
        public let endTime: TimeInterval
        public let isSilence: Bool
        public let averageAmplitude: Float
        public let duration: TimeInterval
        public let patterns: [SpeechPatternDetector.SpeechPattern]?
        public let speakerId: String?
        public let speakerConfidence: Float?
    }
    
    public init(silenceThreshold: Float = 0.01, 
                minSilenceDuration: TimeInterval = 0.5, 
                sampleRate: Double = 44100.0,
                maxSpeakers: Int = 4) {
        self.silenceThreshold = silenceThreshold
        self.minSilenceDuration = minSilenceDuration
        self.sampleRate = sampleRate
        self.patternDetector = SpeechPatternDetector(sampleRate: sampleRate)
        self.speakerDetector = SpeakerDetector(
            sampleRate: sampleRate,
            maxSpeakers: maxSpeakers
        )
    }
    
    /// Analyze audio data to detect speech segments, patterns, and speakers
    /// - Parameter data: Raw audio data
    /// - Returns: Array of speech segments with timing information
    public func analyzeSpeech(_ data: Data) throws -> [SpeechSegment] {
        var samples = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> [Float] in
            let floatPtr = ptr.bindMemory(to: Float.self)
            return Array(floatPtr)
        }
        
        var segments: [SpeechSegment] = []
        var currentSegmentStart = 0
        var isInSilence = false
        var silenceStart = 0
        
        // Calculate average amplitude for each window
        let windowSize = Int(sampleRate * 0.1) // 100ms windows
        var currentWindow: [Float] = []
        
        // Detect speech patterns and speakers
        let patterns = try patternDetector.detectPatterns(data)
        let speakerSegments = try speakerDetector.detectSpeakers(data)
        
        for i in 0..<samples.count {
            currentWindow.append(abs(samples[i]))
            
            if currentWindow.count >= windowSize {
                let averageAmplitude = currentWindow.reduce(0, +) / Float(windowSize)
                let isSilence = averageAmplitude < silenceThreshold
                
                if isSilence && !isInSilence {
                    // Start of silence
                    silenceStart = i - windowSize
                    isInSilence = true
                } else if !isSilence && isInSilence {
                    // End of silence
                    let silenceDuration = Double(i - silenceStart) / sampleRate
                    
                    if silenceDuration >= minSilenceDuration {
                        // Add speech segment before silence
                        if currentSegmentStart < silenceStart {
                            let speechDuration = Double(silenceStart - currentSegmentStart) / sampleRate
                            let startTime = Double(currentSegmentStart) / sampleRate
                            let endTime = startTime + speechDuration
                            
                            // Find patterns that occur during this segment
                            let segmentPatterns = patterns.filter { pattern in
                                pattern.startTime >= startTime && pattern.endTime <= endTime
                            }
                            
                            // Find speaker for this segment
                            let speakerSegment = speakerSegments.first { segment in
                                segment.startTime <= startTime && segment.endTime >= endTime
                            }
                            
                            segments.append(SpeechSegment(
                                startTime: startTime,
                                endTime: endTime,
                                isSilence: false,
                                averageAmplitude: averageAmplitude,
                                duration: speechDuration,
                                patterns: segmentPatterns,
                                speakerId: speakerSegment?.speakerId,
                                speakerConfidence: speakerSegment?.confidence
                            ))
                        }
                        
                        // Add silence segment
                        segments.append(SpeechSegment(
                            startTime: Double(silenceStart) / sampleRate,
                            endTime: Double(i) / sampleRate,
                            isSilence: true,
                            averageAmplitude: averageAmplitude,
                            duration: silenceDuration,
                            patterns: nil,
                            speakerId: nil,
                            speakerConfidence: nil
                        ))
                        
                        currentSegmentStart = i
                    }
                    isInSilence = false
                }
                
                currentWindow.removeFirst()
            }
        }
        
        // Add final segment if needed
        if currentSegmentStart < samples.count {
            let duration = Double(samples.count - currentSegmentStart) / sampleRate
            let startTime = Double(currentSegmentStart) / sampleRate
            let endTime = startTime + duration
            
            // Find patterns that occur during this segment
            let segmentPatterns = patterns.filter { pattern in
                pattern.startTime >= startTime && pattern.endTime <= endTime
            }
            
            // Find speaker for this segment
            let speakerSegment = speakerSegments.first { segment in
                segment.startTime <= startTime && segment.endTime >= endTime
            }
            
            segments.append(SpeechSegment(
                startTime: startTime,
                endTime: endTime,
                isSilence: false,
                averageAmplitude: currentWindow.reduce(0, +) / Float(currentWindow.count),
                duration: duration,
                patterns: segmentPatterns,
                speakerId: speakerSegment?.speakerId,
                speakerConfidence: speakerSegment?.confidence
            ))
        }
        
        return segments
    }
    
    /// Detect potential paragraph breaks based on silence duration, patterns, and speaker changes
    /// - Parameter segments: Array of speech segments
    /// - Returns: Array of time points where paragraph breaks likely occur
    public func detectParagraphBreaks(_ segments: [SpeechSegment]) -> [TimeInterval] {
        let paragraphBreakThreshold: TimeInterval = 1.0 // 1 second of silence for paragraph break
        
        return segments
            .filter { segment in
                if segment.isSilence && segment.duration >= paragraphBreakThreshold {
                    // Check if the following segment has patterns that suggest a new paragraph
                    if let nextSegment = segments.first(where: { $0.startTime > segment.endTime }) {
                        // Look for emphasis or statement patterns at the start of the next segment
                        let hasPattern = nextSegment.patterns?.contains { pattern in
                            pattern.type == .emphasis || pattern.type == .statement
                        } ?? false
                        
                        // Check for speaker change
                        let hasSpeakerChange = nextSegment.speakerId != nil && 
                            segments.first(where: { $0.endTime == segment.startTime })?.speakerId != nextSegment.speakerId
                        
                        return hasPattern || hasSpeakerChange
                    }
                    return true
                }
                return false
            }
            .map { $0.startTime }
    }
    
    /// Detect sentence endings based on silence patterns, intonation, and speaker changes
    /// - Parameter segments: Array of speech segments
    /// - Returns: Array of time points where sentences likely end
    public func detectSentenceEndings(_ segments: [SpeechSegment]) -> [TimeInterval] {
        let sentenceBreakThreshold: TimeInterval = 0.3 // 300ms of silence for sentence break
        
        return segments
            .filter { segment in
                if segment.isSilence && segment.duration >= sentenceBreakThreshold {
                    // Check if the previous segment has patterns that suggest a sentence end
                    if let prevSegment = segments.first(where: { $0.endTime == segment.startTime }) {
                        // Look for statement or question patterns at the end of the previous segment
                        let hasPattern = prevSegment.patterns?.contains { pattern in
                            pattern.type == .statement || pattern.type == .question
                        } ?? false
                        
                        // Check for speaker change
                        let hasSpeakerChange = prevSegment.speakerId != nil && 
                            segments.first(where: { $0.startTime == segment.endTime })?.speakerId != prevSegment.speakerId
                        
                        return hasPattern || hasSpeakerChange
                    }
                    return true
                }
                return false
            }
            .map { $0.startTime }
    }
    
    /// Get speech statistics for the entire audio
    /// - Parameter segments: Array of speech segments
    /// - Returns: Dictionary containing various speech statistics
    public func getSpeechStatistics(_ segments: [SpeechSegment]) -> [String: Any] {
        let totalDuration = segments.last?.endTime ?? 0
        let speechSegments = segments.filter { !$0.isSilence }
        let silenceSegments = segments.filter { $0.isSilence }
        
        let totalSpeechDuration = speechSegments.reduce(0) { $0 + $1.duration }
        let totalSilenceDuration = silenceSegments.reduce(0) { $0 + $1.duration }
        
        let averageSpeechDuration = speechSegments.isEmpty ? 0 : totalSpeechDuration / Double(speechSegments.count)
        let averageSilenceDuration = silenceSegments.isEmpty ? 0 : totalSilenceDuration / Double(silenceSegments.count)
        
        // Collect pattern statistics
        var patternStats: [String: Int] = [:]
        for segment in speechSegments {
            if let patterns = segment.patterns {
                for pattern in patterns {
                    let typeString = String(describing: pattern.type)
                    patternStats[typeString, default: 0] += 1
                }
            }
        }
        
        // Collect speaker statistics
        var speakerStats: [String: [String: Any]] = [:]
        for segment in speechSegments {
            if let speakerId = segment.speakerId {
                var stats = speakerStats[speakerId] ?? [
                    "totalDuration": 0.0,
                    "segmentCount": 0,
                    "averageConfidence": 0.0
                ]
                
                stats["totalDuration"] = (stats["totalDuration"] as? TimeInterval ?? 0) + segment.duration
                stats["segmentCount"] = (stats["segmentCount"] as? Int ?? 0) + 1
                stats["averageConfidence"] = ((stats["averageConfidence"] as? Float ?? 0) * Float(stats["segmentCount"] as? Int ?? 0) + (segment.speakerConfidence ?? 0)) / Float(stats["segmentCount"] as? Int ?? 1)
                
                speakerStats[speakerId] = stats
            }
        }
        
        return [
            "totalDuration": totalDuration,
            "totalSpeechDuration": totalSpeechDuration,
            "totalSilenceDuration": totalSilenceDuration,
            "speechSegmentCount": speechSegments.count,
            "silenceSegmentCount": silenceSegments.count,
            "averageSpeechDuration": averageSpeechDuration,
            "averageSilenceDuration": averageSilenceDuration,
            "patternStatistics": patternStats,
            "speakerStatistics": speakerStats
        ]
    }
} 