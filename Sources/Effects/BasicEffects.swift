import Foundation

/// Normalize audio data to a target level
public class NormalizeEffect: AudioEffect {
    private let targetLevel: Float
    
    public init(targetLevel: Float = 0.0) {
        self.targetLevel = targetLevel
    }
    
    public func process(_ data: Data) throws -> Data {
        var samples = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> [Float] in
            let floatPtr = ptr.bindMemory(to: Float.self)
            return Array(floatPtr)
        }
        
        // Find the maximum absolute value
        let maxValue = samples.map { abs($0) }.max() ?? 1.0
        
        // Normalize to target level
        let scale = pow(10.0, targetLevel / 20.0) / maxValue
        samples = samples.map { $0 * scale }
        
        return Data(bytes: samples, count: samples.count * MemoryLayout<Float>.size)
    }
}

/// Apply a simple low-pass filter
public class LowPassFilter: AudioEffect {
    private let cutoffFrequency: Float
    private let sampleRate: Float
    
    public init(cutoffFrequency: Float, sampleRate: Float) {
        self.cutoffFrequency = cutoffFrequency
        self.sampleRate = sampleRate
    }
    
    public func process(_ data: Data) throws -> Data {
        var samples = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> [Float] in
            let floatPtr = ptr.bindMemory(to: Float.self)
            return Array(floatPtr)
        }
        
        let alpha = cutoffFrequency / (cutoffFrequency + sampleRate)
        var previousSample = samples[0]
        
        for i in 1..<samples.count {
            samples[i] = alpha * samples[i] + (1 - alpha) * previousSample
            previousSample = samples[i]
        }
        
        return Data(bytes: samples, count: samples.count * MemoryLayout<Float>.size)
    }
}

/// Apply noise reduction
public class NoiseReduction: AudioEffect {
    private let threshold: Float
    
    public init(threshold: Float = 0.01) {
        self.threshold = threshold
    }
    
    public func process(_ data: Data) throws -> Data {
        var samples = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> [Float] in
            let floatPtr = ptr.bindMemory(to: Float.self)
            return Array(floatPtr)
        }
        
        // Simple noise gate implementation
        for i in 0..<samples.count {
            if abs(samples[i]) < threshold {
                samples[i] = 0
            }
        }
        
        return Data(bytes: samples, count: samples.count * MemoryLayout<Float>.size)
    }
} 