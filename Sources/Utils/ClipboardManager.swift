import Foundation
import UIKit

public class ClipboardManager {
    public struct AudioClipboardData: Codable {
        public let audioData: Data
        public let format: AudioFormat
        public let segments: [SpeechAnalyzer.SpeechSegment]
        public let paragraphBreaks: [TimeInterval]
        public let sentenceEndings: [TimeInterval]
        public let statistics: [String: Any]
        
        public init(audioData: Data, format: AudioFormat, segments: [SpeechAnalyzer.SpeechSegment]) {
            self.audioData = audioData
            self.format = format
            self.segments = segments
            self.paragraphBreaks = SpeechAnalyzer().detectParagraphBreaks(segments)
            self.sentenceEndings = SpeechAnalyzer().detectSentenceEndings(segments)
            self.statistics = SpeechAnalyzer().getSpeechStatistics(segments)
        }
    }
    
    /// Copy processed audio data to clipboard
    /// - Parameter data: AudioClipboardData containing processed audio and metadata
    public func copyToClipboard(_ data: AudioClipboardData) {
        do {
            let jsonData = try JSONEncoder().encode(data)
            let base64Data = jsonData.base64EncodedData()
            
            // Create a dictionary with both the audio data and metadata
            let clipboardData: [String: Any] = [
                "audioData": base64Data,
                "timestamp": Date().timeIntervalSince1970
            ]
            
            // Convert to JSON
            let jsonString = try JSONSerialization.data(withJSONObject: clipboardData)
            
            // Copy to clipboard
            UIPasteboard.general.string = String(data: jsonString, encoding: .utf8)
        } catch {
            print("Error copying to clipboard: \(error)")
        }
    }
    
    /// Read audio data from clipboard
    /// - Returns: AudioClipboardData if available, nil otherwise
    public func readFromClipboard() -> AudioClipboardData? {
        guard let jsonString = UIPasteboard.general.string,
              let jsonData = jsonString.data(using: .utf8),
              let clipboardData = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let base64Data = clipboardData["audioData"] as? Data,
              let decodedData = Data(base64Encoded: base64Data),
              let audioData = try? JSONDecoder().decode(AudioClipboardData.self, from: decodedData) else {
            return nil
        }
        
        return audioData
    }
    
    /// Clear clipboard
    public func clearClipboard() {
        UIPasteboard.general.string = nil
    }
    
    /// Check if clipboard contains valid audio data
    /// - Returns: Boolean indicating if clipboard contains valid audio data
    public func hasAudioData() -> Bool {
        return readFromClipboard() != nil
    }
} 