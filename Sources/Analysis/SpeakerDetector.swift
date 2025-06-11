import Foundation
import AVFoundation

public class SpeakerDetector {
    private let sampleRate: Double
    private let windowSize: Int
    private let minSegmentDuration: TimeInterval
    private let maxSpeakers: Int
    
    public struct SpeakerProfile {
        public let id: String
        public let characteristics: VoiceCharacteristics
        public let confidence: Float
        public let metadata: [String: Any]
    }
    
    public struct VoiceCharacteristics {
        public let pitch: Float              // Average pitch
        public let pitchRange: Float        // Range of pitch variation
        public let energy: Float            // Average energy
        public let energyRange: Float       // Range of energy variation
        public let speakingRate: Float      // Words per minute estimate
        public let formants: [Float]        // Formant frequencies
        public let spectralFeatures: [Float] // Spectral characteristics
    }
    
    public struct SpeakerSegment {
        public let speakerId: String
        public let startTime: TimeInterval
        public let endTime: TimeInterval
        public let confidence: Float
        public let characteristics: VoiceCharacteristics
    }
    
    public init(sampleRate: Double = 44100.0,
                windowSize: Int = 1024,
                minSegmentDuration: TimeInterval = 0.5,
                maxSpeakers: Int = 4) {
        self.sampleRate = sampleRate
        self.windowSize = windowSize
        self.minSegmentDuration = minSegmentDuration
        self.maxSpeakers = maxSpeakers
    }
    
    /// Analyze audio data to detect different speakers
    /// - Parameter data: Raw audio data
    /// - Returns: Array of speaker segments with timing information
    public func detectSpeakers(_ data: Data) throws -> [SpeakerSegment] {
        var segments: [SpeakerSegment] = []
        let samples = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> [Float] in
            let floatPtr = ptr.bindMemory(to: Float.self)
            return Array(floatPtr)
        }
        
        // Extract voice characteristics for each window
        var characteristics: [(TimeInterval, VoiceCharacteristics)] = []
        for i in stride(from: 0, to: samples.count - windowSize, by: windowSize/2) {
            let window = Array(samples[i..<min(i + windowSize, samples.count)])
            let time = Double(i) / sampleRate
            let voiceChar = extractVoiceCharacteristics(window)
            characteristics.append((time, voiceChar))
        }
        
        // Cluster characteristics to identify speakers
        let clusters = clusterVoiceCharacteristics(characteristics)
        
        // Create speaker segments
        var currentSpeaker: String?
        var segmentStart: TimeInterval?
        
        for (time, char) in characteristics {
            let speakerId = identifySpeaker(char, clusters: clusters)
            
            if speakerId != currentSpeaker {
                // End current segment if exists
                if let start = segmentStart, let speaker = currentSpeaker {
                    let duration = time - start
                    if duration >= minSegmentDuration {
                        segments.append(SpeakerSegment(
                            speakerId: speaker,
                            startTime: start,
                            endTime: time,
                            confidence: calculateConfidence(char, clusters: clusters),
                            characteristics: char
                        ))
                    }
                }
                
                // Start new segment
                currentSpeaker = speakerId
                segmentStart = time
            }
        }
        
        // Add final segment
        if let start = segmentStart, let speaker = currentSpeaker {
            let duration = Double(samples.count) / sampleRate - start
            if duration >= minSegmentDuration {
                segments.append(SpeakerSegment(
                    speakerId: speaker,
                    startTime: start,
                    endTime: Double(samples.count) / sampleRate,
                    confidence: calculateConfidence(characteristics.last?.1 ?? VoiceCharacteristics(
                        pitch: 0, pitchRange: 0, energy: 0, energyRange: 0,
                        speakingRate: 0, formants: [], spectralFeatures: []
                    ), clusters: clusters),
                    characteristics: characteristics.last?.1 ?? VoiceCharacteristics(
                        pitch: 0, pitchRange: 0, energy: 0, energyRange: 0,
                        speakingRate: 0, formants: [], spectralFeatures: []
                    )
                ))
            }
        }
        
        return segments
    }
    
    /// Extract voice characteristics from audio window
    private func extractVoiceCharacteristics(_ samples: [Float]) -> VoiceCharacteristics {
        // Calculate pitch using autocorrelation
        let pitch = calculatePitch(samples)
        let pitchRange = calculatePitchRange(samples)
        
        // Calculate energy characteristics
        let energy = calculateEnergy(samples)
        let energyRange = calculateEnergyRange(samples)
        
        // Estimate speaking rate
        let speakingRate = estimateSpeakingRate(samples)
        
        // Extract formants
        let formants = extractFormants(samples)
        
        // Extract spectral features
        let spectralFeatures = extractSpectralFeatures(samples)
        
        return VoiceCharacteristics(
            pitch: pitch,
            pitchRange: pitchRange,
            energy: energy,
            energyRange: energyRange,
            speakingRate: speakingRate,
            formants: formants,
            spectralFeatures: spectralFeatures
        )
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
    
    /// Calculate pitch range
    private func calculatePitchRange(_ samples: [Float]) -> Float {
        let windowSize = Int(sampleRate * 0.1) // 100ms windows
        var pitches: [Float] = []
        
        for i in stride(from: 0, to: samples.count - windowSize, by: windowSize/2) {
            let window = Array(samples[i..<min(i + windowSize, samples.count)])
            pitches.append(calculatePitch(window))
        }
        
        return pitches.max() ?? 0 - pitches.min() ?? 0
    }
    
    /// Calculate energy (RMS)
    private func calculateEnergy(_ samples: [Float]) -> Float {
        let sum = samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sum / Float(samples.count))
    }
    
    /// Calculate energy range
    private func calculateEnergyRange(_ samples: [Float]) -> Float {
        let windowSize = Int(sampleRate * 0.1) // 100ms windows
        var energies: [Float] = []
        
        for i in stride(from: 0, to: samples.count - windowSize, by: windowSize/2) {
            let window = Array(samples[i..<min(i + windowSize, samples.count)])
            energies.append(calculateEnergy(window))
        }
        
        return energies.max() ?? 0 - energies.min() ?? 0
    }
    
    /// Estimate speaking rate
    private func estimateSpeakingRate(_ samples: [Float]) -> Float {
        // Simple implementation - can be enhanced with more sophisticated methods
        let energy = calculateEnergy(samples)
        let zeroCrossings = calculateZeroCrossings(samples)
        return Float(zeroCrossings) * energy / Float(samples.count)
    }
    
    /// Extract formant frequencies
    private func extractFormants(_ samples: [Float]) -> [Float] {
        // Simple implementation - can be enhanced with LPC analysis
        let fft = performFFT(samples)
        return findPeaks(fft, count: 3) // Return top 3 formant frequencies
    }
    
    /// Extract spectral features
    private func extractSpectralFeatures(_ samples: [Float]) -> [Float] {
        let fft = performFFT(samples)
        return [
            calculateSpectralCentroid(fft),
            calculateSpectralRolloff(fft),
            calculateSpectralFlux(fft)
        ]
    }
    
    /// Perform FFT on samples
    private func performFFT(_ samples: [Float]) -> [Float] {
        // Simple implementation - can be enhanced with vDSP
        var real = samples
        var imag = [Float](repeating: 0, count: samples.count)
        
        // Perform FFT
        // This is a placeholder - implement actual FFT using vDSP
        return real
    }
    
    /// Find peaks in frequency spectrum
    private func findPeaks(_ spectrum: [Float], count: Int) -> [Float] {
        // Simple peak finding implementation
        var peaks: [Float] = []
        for i in 1..<spectrum.count-1 {
            if spectrum[i] > spectrum[i-1] && spectrum[i] > spectrum[i+1] {
                peaks.append(Float(i) * Float(sampleRate) / Float(spectrum.count))
            }
        }
        return Array(peaks.sorted().prefix(count))
    }
    
    /// Calculate spectral centroid
    private func calculateSpectralCentroid(_ spectrum: [Float]) -> Float {
        var numerator: Float = 0
        var denominator: Float = 0
        
        for i in 0..<spectrum.count {
            let frequency = Float(i) * Float(sampleRate) / Float(spectrum.count)
            numerator += frequency * spectrum[i]
            denominator += spectrum[i]
        }
        
        return denominator > 0 ? numerator / denominator : 0
    }
    
    /// Calculate spectral rolloff
    private func calculateSpectralRolloff(_ spectrum: [Float]) -> Float {
        let totalEnergy = spectrum.reduce(0, +)
        var cumulativeEnergy: Float = 0
        let threshold = totalEnergy * 0.85 // 85% of total energy
        
        for i in 0..<spectrum.count {
            cumulativeEnergy += spectrum[i]
            if cumulativeEnergy >= threshold {
                return Float(i) * Float(sampleRate) / Float(spectrum.count)
            }
        }
        
        return 0
    }
    
    /// Calculate spectral flux
    private func calculateSpectralFlux(_ spectrum: [Float]) -> Float {
        var flux: Float = 0
        for i in 1..<spectrum.count {
            flux += abs(spectrum[i] - spectrum[i-1])
        }
        return flux
    }
    
    /// Calculate zero crossings
    private func calculateZeroCrossings(_ samples: [Float]) -> Int {
        var crossings = 0
        for i in 1..<samples.count {
            if (samples[i] >= 0 && samples[i-1] < 0) || (samples[i] < 0 && samples[i-1] >= 0) {
                crossings += 1
            }
        }
        return crossings
    }
    
    /// Cluster voice characteristics to identify speakers
    private func clusterVoiceCharacteristics(_ characteristics: [(TimeInterval, VoiceCharacteristics)]) -> [[VoiceCharacteristics]] {
        // Simple k-means clustering implementation
        // This is a placeholder - implement actual clustering algorithm
        var clusters: [[VoiceCharacteristics]] = Array(repeating: [], count: maxSpeakers)
        
        // Assign each characteristic to nearest cluster
        for (_, char) in characteristics {
            let clusterIndex = findNearestCluster(char, clusters: clusters)
            clusters[clusterIndex].append(char)
        }
        
        return clusters
    }
    
    /// Find nearest cluster for voice characteristics
    private func findNearestCluster(_ characteristics: VoiceCharacteristics, clusters: [[VoiceCharacteristics]]) -> Int {
        // Simple distance calculation
        // This is a placeholder - implement actual distance metric
        return 0
    }
    
    /// Identify speaker from voice characteristics
    private func identifySpeaker(_ characteristics: VoiceCharacteristics, clusters: [[VoiceCharacteristics]]) -> String {
        // Find nearest cluster and return speaker ID
        let clusterIndex = findNearestCluster(characteristics, clusters: clusters)
        return "speaker_\(clusterIndex + 1)"
    }
    
    /// Calculate confidence in speaker identification
    private func calculateConfidence(_ characteristics: VoiceCharacteristics, clusters: [[VoiceCharacteristics]]) -> Float {
        // Calculate confidence based on distance to cluster center
        // This is a placeholder - implement actual confidence calculation
        return 0.8
    }
    
    /// Get speaker statistics
    /// - Parameter segments: Array of speaker segments
    /// - Returns: Dictionary containing speaker statistics
    public func getSpeakerStatistics(_ segments: [SpeakerSegment]) -> [String: Any] {
        var speakerStats: [String: [String: Any]] = [:]
        
        for segment in segments {
            var stats = speakerStats[segment.speakerId] ?? [
                "totalDuration": 0.0,
                "segmentCount": 0,
                "averageConfidence": 0.0,
                "characteristics": VoiceCharacteristics(
                    pitch: 0, pitchRange: 0, energy: 0, energyRange: 0,
                    speakingRate: 0, formants: [], spectralFeatures: []
                )
            ]
            
            stats["totalDuration"] = (stats["totalDuration"] as? TimeInterval ?? 0) + (segment.endTime - segment.startTime)
            stats["segmentCount"] = (stats["segmentCount"] as? Int ?? 0) + 1
            stats["averageConfidence"] = ((stats["averageConfidence"] as? Float ?? 0) * Float(stats["segmentCount"] as? Int ?? 0) + segment.confidence) / Float(stats["segmentCount"] as? Int ?? 1)
            stats["characteristics"] = segment.characteristics
            
            speakerStats[segment.speakerId] = stats
        }
        
        return [
            "speakerCount": speakerStats.count,
            "speakerDetails": speakerStats
        ]
    }
} 