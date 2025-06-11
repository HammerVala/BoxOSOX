import Foundation
import AVFoundation

public class AudioFormatHandler {
    /// Supported audio formats
    public enum Format {
        case wav
        case mp3
        case aac
        case pcm
        case flac
    }
    
    /// Read audio data from a file
    /// - Parameter url: File URL
    /// - Returns: Audio data and format information
    public func read(from url: URL) throws -> (Data, AudioFormat) {
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        
        let audioFormat = AudioFormat(
            sampleRate: format.sampleRate,
            channelCount: Int(format.channelCount),
            bitDepth: Int(format.commonFormat.rawValue),
            isFloat: format.isInterleaved
        )
        
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(audioFile.length))!
        try audioFile.read(into: buffer)
        
        guard let data = buffer.floatChannelData?[0] else {
            throw AudioError.readError
        }
        
        return (Data(bytes: data, count: Int(buffer.frameLength) * MemoryLayout<Float>.size), audioFormat)
    }
    
    /// Write audio data to a file
    /// - Parameters:
    ///   - data: Audio data to write
    ///   - format: Audio format information
    ///   - url: Destination file URL
    public func write(_ data: Data, format: AudioFormat, to url: URL) throws {
        let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: format.sampleRate,
            channels: UInt32(format.channelCount),
            interleaved: format.isFloat
        )!
        
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(data.count / MemoryLayout<Float>.size))!
        buffer.frameLength = buffer.frameCapacity
        
        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            let floatPtr = ptr.bindMemory(to: Float.self)
            buffer.floatChannelData?[0].initialize(from: floatPtr.baseAddress!, count: Int(buffer.frameLength))
        }
        
        let audioFile = try AVAudioFile(forWriting: url, settings: audioFormat.settings)
        try audioFile.write(from: buffer)
    }
}

/// Audio processing errors
public enum AudioError: Error {
    case readError
    case writeError
    case formatError
    case processingError
} 