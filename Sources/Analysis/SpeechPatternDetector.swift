import Foundation
import AVFoundation

public class SpeechPatternDetector {
    private let sampleRate: Double
    private let windowSize: Int
    private let energyThreshold: Float
    private let pitchThreshold: Float
    
    public struct SpeechPattern {
        public let type: PatternType
        public let startTime: TimeInterval
        public let endTime: TimeInterval
        public let confidence: Float
        public let metadata: [String: Any]
        
        public enum PatternType {
            case question        // Rising intonation
            case statement       // Falling intonation
            case emphasis        // Increased volume
            case hesitation      // Filled pauses
            case interruption    // Sudden cutoff
            case listItem        // Consistent pauses
            case emphasisGroup   // Group of emphasized words
            case fillerWord      // Common filler words
        }
    }
    
    public init(sampleRate: Double = 44100.0, 
                windowSize: Int = 1024,
                energyThreshold: Float = 0.1,
                pitchThreshold: Float = 0.05) {
        self.sampleRate = sampleRate
        self.windowSize = windowSize
        self.energyThreshold = energyThreshold
        self.pitchThreshold = pitchThreshold
    }
    
    /// Analyze audio data for speech patterns
    /// - Parameter data: Raw audio data
    /// - Returns: Array of detected speech patterns
    public func detectPatterns(_ data: Data) throws -> [SpeechPattern] {
        var patterns: [SpeechPattern] = []
        let samples = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> [Float] in
            let floatPtr = ptr.bindMemory(to: Float.self)
            return Array(floatPtr)
        }
        
        // Calculate pitch and energy for each window
        var pitchValues: [Float] = []
        var energyValues: [Float] = []
        
        for i in stride(from: 0, to: samples.count - windowSize, by: windowSize/2) {
            let window = Array(samples[i..<min(i + windowSize, samples.count)])
            let pitch = calculatePitch(window)
            let energy = calculateEnergy(window)
            pitchValues.append(pitch)
            energyValues.append(energy)
        }
        
        // Detect patterns based on pitch and energy analysis
        patterns.append(contentsOf: detectIntonationPatterns(pitchValues))
        patterns.append(contentsOf: detectEmphasisPatterns(energyValues))
        patterns.append(contentsOf: detectHesitationPatterns(samples))
        patterns.append(contentsOf: detectListPatterns(pitchValues, energyValues))
        
        return patterns
    }
    
    /// Calculate pitch using autocorrelation
    private func calculatePitch(_ samples: [Float]) -> Float {
        let maxLag = samples.count / 2
        var maxCorrelation: Float = 0
        var bestLag = 0
        
        for lag in 1..<maxLag {
            var correlation: Float = 0
            for i in 0..<(samples.count - lag) {
                correlation += samples[i] * samples[i + lag]
            }
            
            if correlation > maxCorrelation {
                maxCorrelation = correlation
                bestLag = lag
            }
        }
        
        return bestLag > 0 ? Float(sampleRate) / Float(bestLag) : 0
    }
    
    /// Calculate energy (RMS) of the signal
    private func calculateEnergy(_ samples: [Float]) -> Float {
        let sum = samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sum / Float(samples.count))
    }
    
    /// Detect intonation patterns (questions vs statements)
    private func detectIntonationPatterns(_ pitchValues: [Float]) -> [SpeechPattern] {
        var patterns: [SpeechPattern] = []
        let windowDuration = Double(windowSize) / sampleRate
        
        // Analyze pitch contour
        for i in 0..<pitchValues.count - 1 {
            let pitchChange = pitchValues[i + 1] - pitchValues[i]
            let startTime = Double(i) * windowDuration
            let endTime = Double(i + 1) * windowDuration
            
            if abs(pitchChange) > pitchThreshold {
                let patternType: SpeechPattern.PatternType = pitchChange > 0 ? .question : .statement
                let confidence = min(abs(pitchChange) / (pitchThreshold * 2), 1.0)
                
                patterns.append(SpeechPattern(
                    type: patternType,
                    startTime: startTime,
                    endTime: endTime,
                    confidence: confidence,
                    metadata: ["pitchChange": pitchChange]
                ))
            }
        }
        
        return patterns
    }
    
    /// Detect emphasis patterns
    private func detectEmphasisPatterns(_ energyValues: [Float]) -> [SpeechPattern] {
        var patterns: [SpeechPattern] = []
        let windowDuration = Double(windowSize) / sampleRate
        
        // Find local energy maxima
        for i in 1..<energyValues.count - 1 {
            if energyValues[i] > energyValues[i-1] && 
               energyValues[i] > energyValues[i+1] &&
               energyValues[i] > energyThreshold {
                
                let startTime = Double(i) * windowDuration
                let endTime = Double(i + 1) * windowDuration
                let confidence = min(energyValues[i] / (energyThreshold * 2), 1.0)
                
                patterns.append(SpeechPattern(
                    type: .emphasis,
                    startTime: startTime,
                    endTime: endTime,
                    confidence: confidence,
                    metadata: ["energy": energyValues[i]]
                ))
            }
        }
        
        return patterns
    }
    
    /// Detect hesitation patterns (filled pauses)
    private func detectHesitationPatterns(_ samples: [Float]) -> [SpeechPattern] {
        var patterns: [SpeechPattern] = []
        let windowDuration = Double(windowSize) / sampleRate
        
        // Look for low energy segments with irregular patterns
        for i in stride(from: 0, to: samples.count - windowSize, by: windowSize/2) {
            let window = Array(samples[i..<min(i + windowSize, samples.count)])
            let energy = calculateEnergy(window)
            let zeroCrossings = calculateZeroCrossings(window)
            
            if energy < energyThreshold * 0.5 && zeroCrossings > 5 {
                let startTime = Double(i) / sampleRate
                let endTime = Double(i + windowSize) / sampleRate
                
                patterns.append(SpeechPattern(
                    type: .hesitation,
                    startTime: startTime,
                    endTime: endTime,
                    confidence: 1.0 - (energy / energyThreshold),
                    metadata: [
                        "energy": energy,
                        "zeroCrossings": zeroCrossings
                    ]
                ))
            }
        }
        
        return patterns
    }
    
    /// Detect list patterns (consistent pauses with similar intonation)
    private func detectListPatterns(_ pitchValues: [Float], _ energyValues: [Float]) -> [SpeechPattern] {
        var patterns: [SpeechPattern] = []
        let windowDuration = Double(windowSize) / sampleRate
        
        // Look for repeating patterns in pitch and energy
        var lastPauseTime: TimeInterval?
        var lastPitch: Float?
        
        for i in 0..<pitchValues.count {
            let currentTime = Double(i) * windowDuration
            
            if energyValues[i] < energyThreshold * 0.3 {
                if let lastTime = lastPauseTime,
                   let lastP = lastPitch {
                    let timeDiff = currentTime - lastTime
                    let pitchDiff = abs(pitchValues[i] - lastP)
                    
                    // Check for consistent timing and pitch
                    if timeDiff >= 0.3 && timeDiff <= 1.0 && pitchDiff < pitchThreshold {
                        patterns.append(SpeechPattern(
                            type: .listItem,
                            startTime: lastTime,
                            endTime: currentTime,
                            confidence: 1.0 - (pitchDiff / pitchThreshold),
                            metadata: [
                                "timeInterval": timeDiff,
                                "pitchDifference": pitchDiff
                            ]
                        ))
                    }
                }
                
                lastPauseTime = currentTime
                lastPitch = pitchValues[i]
            }
        }
        
        return patterns
    }
    
    /// Calculate zero crossings in a signal window
    private func calculateZeroCrossings(_ samples: [Float]) -> Int {
        var crossings = 0
        for i in 1..<samples.count {
            if (samples[i] >= 0 && samples[i-1] < 0) || (samples[i] < 0 && samples[i-1] >= 0) {
                crossings += 1
            }
        }
        return crossings
    }
    
    /// Get pattern statistics
    /// - Parameter patterns: Array of detected patterns
    /// - Returns: Dictionary containing pattern statistics
    public func getPatternStatistics(_ patterns: [SpeechPattern]) -> [String: Any] {
        var typeCounts: [SpeechPattern.PatternType: Int] = [:]
        var typeDurations: [SpeechPattern.PatternType: TimeInterval] = [:]
        
        for pattern in patterns {
            typeCounts[pattern.type, default: 0] += 1
            typeDurations[pattern.type, default: 0] += pattern.endTime - pattern.startTime
        }
        
        return [
            "patternCounts": typeCounts,
            "patternDurations": typeDurations,
            "totalPatterns": patterns.count,
            "averageConfidence": patterns.map { $0.confidence }.reduce(0, +) / Float(patterns.count)
        ]
    }
} 