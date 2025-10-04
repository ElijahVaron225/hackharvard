import SwiftUI

// MARK: - Paragraph Interpreter Feature
struct ParagraphInterpreter {
    var text: String
    
    var wordCount: Int {
        text.split(separator: " ").count
    }
    
    var characterCount: Int {
        text.count
    }
    
    var sentenceCount: Int {
        text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }
    
    func analyze() -> TextAnalysis {
        TextAnalysis(
            wordCount: wordCount,
            characterCount: characterCount,
            sentenceCount: sentenceCount,
            originalText: text
        )
    }
}

// MARK: - Analysis Result Model
struct TextAnalysis {
    let wordCount: Int
    let characterCount: Int
    let sentenceCount: Int
    let originalText: String
    
    var formattedOutput: String {
        """
        📝 Text Analysis:
        
        Words: \(wordCount)
        Characters: \(characterCount)
        Sentences: \(sentenceCount)
        
        ━━━━━━━━━━━━━━━━━━━━
        
        Your Text:
        
        \(originalText)
        """
    }
}
