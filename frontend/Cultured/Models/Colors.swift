//
//  Colors.swift
//  Cultured
//
//  Created by Ishaan Buddharaju on 10/4/25.
//


import SwiftUI

extension Color {
    // MARK: - Brand Colors
    
    /// Primary brand color - Sage green (#4A7C59)
    static let primary = Color(hex: "4A7C59")
    
    /// Main background color - Warm cream (#FFF5E6)
    static let background = Color(hex: "FFF5E6")
    
    /// Secondary background color - Warm beige (#E5DBB7)
    static let secondBackground = Color(hex: "E5DBB7")
    
    /// Text Color
    static let text = Color(hex: "3A3A3A")
    
    // MARK: - Hex Initializer
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
