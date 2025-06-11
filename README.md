# BoxOSOX

BoxOSOX is a streamlined audio processing library specifically designed for AI applications, with initial focus on iOS/macOS platforms. It provides essential audio processing capabilities while maintaining a minimal footprint and high performance.

## Features

- Audio format conversion and processing
- Real-time audio stream handling
- AI-optimized audio preprocessing
- Advanced speech pattern detection
- Minimal memory footprint
- Native iOS/macOS integration
- Swift-first API design

## Project Structure

```
BoxOSOX/
├── Sources/
│   ├── Core/           # Core audio processing functionality
│   ├── Formats/        # Audio format handlers
│   ├── Effects/        # Audio effects and processing
│   └── Utils/          # Utility functions and helpers
├── Tests/              # Unit and integration tests
└── Examples/           # Example implementations
```

## Requirements

- iOS 14.0+ / macOS 11.0+
- Xcode 13.0+
- Swift 5.5+

## Installation

### Swift Package Manager

Add BoxOSOX to your project using Swift Package Manager:

1. In Xcode, go to File > Add Packages...
2. Enter the repository URL
3. Select the version you want to use
4. Click Add Package

## Usage

### Basic Audio Processing

```swift
import BoxOSOX

// Initialize the audio processor
let processor = AudioProcessor(sampleRate: 44100.0, channelCount: 2)

// Process audio data
do {
    let processedData = try processor.process(audioData, format: audioFormat)
    // Use processed data...
} catch {
    print("Error processing audio: \(error)")
}
```

### Speech Analysis

```swift
import BoxOSOX

// Initialize the speech analyzer
let analyzer = SpeechAnalyzer(
    silenceThreshold: 0.01,
    minSilenceDuration: 0.5,
    sampleRate: 44100.0
)

// Analyze speech patterns
do {
    let segments = try analyzer.analyzeSpeech(audioData)
    
    // Get paragraph breaks
    let paragraphBreaks = analyzer.detectParagraphBreaks(segments)
    
    // Get sentence endings
    let sentenceEndings = analyzer.detectSentenceEndings(segments)
    
    // Get speech statistics
    let statistics = analyzer.getSpeechStatistics(segments)
} catch {
    print("Error analyzing speech: \(error)")
}
```

### Advanced Pattern Detection

```swift
import BoxOSOX

// Initialize the pattern detector
let detector = SpeechPatternDetector(
    sampleRate: 44100.0,
    windowSize: 1024,
    energyThreshold: 0.1,
    pitchThreshold: 0.05
)

// Detect speech patterns
do {
    let patterns = try detector.detectPatterns(audioData)
    
    // Process different pattern types
    for pattern in patterns {
        switch pattern.type {
        case .question:
            print("Question detected at \(pattern.startTime)")
        case .statement:
            print("Statement detected at \(pattern.startTime)")
        case .emphasis:
            print("Emphasis detected at \(pattern.startTime)")
        case .hesitation:
            print("Hesitation detected at \(pattern.startTime)")
        case .interruption:
            print("Interruption detected at \(pattern.startTime)")
        case .listItem:
            print("List item detected at \(pattern.startTime)")
        case .emphasisGroup:
            print("Emphasis group detected at \(pattern.startTime)")
        case .fillerWord:
            print("Filler word detected at \(pattern.startTime)")
        }
    }
    
    // Get pattern statistics
    let statistics = detector.getPatternStatistics(patterns)
} catch {
    print("Error detecting patterns: \(error)")
}
```

### Clipboard Integration

```swift
import BoxOSOX

// Initialize the clipboard manager
let clipboardManager = ClipboardManager()

// Process and copy audio to clipboard
do {
    let analyzer = SpeechAnalyzer()
    let segments = try analyzer.analyzeSpeech(audioData)
    
    let clipboardData = AudioClipboardData(
        audioData: audioData,
        format: audioFormat,
        segments: segments
    )
    
    clipboardManager.copyToClipboard(clipboardData)
} catch {
    print("Error processing audio for clipboard: \(error)")
}

// Read audio from clipboard
if let clipboardData = clipboardManager.readFromClipboard() {
    // Use the audio data and its metadata
    let audioData = clipboardData.audioData
    let format = clipboardData.format
    let segments = clipboardData.segments
    let paragraphBreaks = clipboardData.paragraphBreaks
    let sentenceEndings = clipboardData.sentenceEndings
    let statistics = clipboardData.statistics
}
```

## Speaker Detection

BoxOSOX includes advanced speaker detection capabilities that can identify different speakers in a conversation and track their participation. This is particularly useful for:

- Multi-person conversations
- Meeting transcriptions
- Speaker diarization
- Conversation analysis

### Basic Speaker Detection

```swift
import BoxOSOX

// Initialize the speech analyzer with speaker detection
let analyzer = SpeechAnalyzer(
    silenceThreshold: 0.01,
    minSilenceDuration: 0.5,
    sampleRate: 44100.0,
    maxSpeakers: 4  // Maximum number of speakers to detect
)

// Analyze audio data
let segments = try analyzer.analyzeSpeech(audioData)

// Process speech segments with speaker information
for segment in segments {
    if let speakerId = segment.speakerId {
        print("Speaker \(speakerId) spoke from \(segment.startTime) to \(segment.endTime)")
        print("Confidence: \(segment.speakerConfidence ?? 0)")
    }
}
```

### Speaker Statistics

The analyzer provides detailed statistics about each speaker's participation:

```swift
let stats = analyzer.getSpeechStatistics(segments)

// Access speaker statistics
if let speakerStats = stats["speakerStatistics"] as? [String: [String: Any]] {
    for (speakerId, stats) in speakerStats {
        print("Speaker \(speakerId):")
        print("  Total Duration: \(stats["totalDuration"] ?? 0) seconds")
        print("  Segment Count: \(stats["segmentCount"] ?? 0)")
        print("  Average Confidence: \(stats["averageConfidence"] ?? 0)")
    }
}
```

### Speaker-Aware Pattern Detection

The analyzer can detect speech patterns while considering speaker changes:

```swift
// Detect paragraph breaks (now considers speaker changes)
let paragraphBreaks = analyzer.detectParagraphBreaks(segments)

// Detect sentence endings (now considers speaker changes)
let sentenceEndings = analyzer.detectSentenceEndings(segments)
```

### Speaker Detection Features

- **Multiple Speaker Support**: Detect up to 4 speakers by default (configurable)
- **Speaker Confidence**: Each speaker identification includes a confidence score
- **Speaker Transitions**: Automatically detect when speakers change
- **Speaker Statistics**: Track speaking time, segment count, and confidence per speaker
- **Integration with Patterns**: Combine speaker detection with speech pattern analysis

### Best Practices for Speaker Detection

1. **Audio Quality**:
   - Use high-quality audio input
   - Minimize background noise
   - Ensure speakers are clearly audible

2. **Configuration**:
   - Set appropriate `maxSpeakers` based on your use case
   - Adjust `silenceThreshold` and `minSilenceDuration` for your environment
   - Consider the expected number of speakers

3. **Speaker Identification**:
   - Use confidence scores to filter out uncertain identifications
   - Consider speaker transitions in your analysis
   - Track speaker statistics for better insights

4. **Performance Considerations**:
   - Speaker detection adds computational overhead
   - Consider processing in chunks for long recordings
   - Cache speaker profiles when possible

## Pattern Detection Types

The library can detect the following speech patterns:

1. **Questions**: Rising intonation patterns
2. **Statements**: Falling intonation patterns
3. **Emphasis**: Increased volume or stress
4. **Hesitation**: Filled pauses and uncertainty
5. **Interruption**: Sudden cutoffs in speech
6. **List Items**: Consistent pauses with similar intonation
7. **Emphasis Groups**: Groups of emphasized words
8. **Filler Words**: Common speech fillers

## Configuration

### SpeechAnalyzer Configuration

```swift
let analyzer = SpeechAnalyzer(
    silenceThreshold: 0.01,    // Threshold for silence detection
    minSilenceDuration: 0.5,   // Minimum duration for silence
    sampleRate: 44100.0        // Audio sample rate
)
```

### SpeechPatternDetector Configuration

```swift
let detector = SpeechPatternDetector(
    sampleRate: 44100.0,       // Audio sample rate
    windowSize: 1024,          // Analysis window size
    energyThreshold: 0.1,      // Energy threshold for emphasis
    pitchThreshold: 0.05       // Pitch threshold for intonation
)
```

## Best Practices

1. **Memory Management**:
   - Process audio in chunks for large files
   - Clear processed data when no longer needed
   - Use appropriate buffer sizes

2. **Performance**:
   - Adjust window sizes based on your needs
   - Use appropriate thresholds for your use case
   - Consider background processing for large files

3. **Error Handling**:
   - Always use try-catch blocks
   - Handle all potential errors
   - Provide meaningful error messages

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - See LICENSE file for details 