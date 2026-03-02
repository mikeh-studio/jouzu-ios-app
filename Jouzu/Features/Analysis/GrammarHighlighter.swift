import SwiftUI

/// Maps POS tags to colors for grammar highlighting
struct GrammarHighlighter {

    static func color(for pos: PartOfSpeech) -> Color {
        switch pos {
        case .verb:
            return .blue
        case .iAdjective, .naAdjective:
            return .green
        case .particle:
            return .orange
        case .auxiliaryVerb:
            return .purple
        case .adverb:
            return .teal
        case .noun:
            return .primary
        default:
            return .primary
        }
    }

    static func color(forDisplayName name: String) -> Color {
        switch name {
        case "Verb": return .blue
        case "i-Adjective", "na-Adjective": return .green
        case "Particle": return .orange
        case "Auxiliary Verb": return .purple
        case "Adverb": return .teal
        default: return .secondary
        }
    }

    static func backgroundColor(for pos: PartOfSpeech) -> Color {
        switch pos {
        case .verb:
            return .blue.opacity(0.12)
        case .iAdjective, .naAdjective:
            return .green.opacity(0.12)
        case .particle:
            return .orange.opacity(0.12)
        case .auxiliaryVerb:
            return .purple.opacity(0.12)
        default:
            return .clear
        }
    }
}

// MARK: - Legend View

struct GrammarLegendView: View {
    let categories: [(String, Color)] = [
        ("Verb", .blue),
        ("Adjective", .green),
        ("Particle", .orange),
        ("Aux. Verb", .purple),
        ("Adverb", .teal),
    ]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(categories, id: \.0) { name, color in
                HStack(spacing: 4) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    GrammarLegendView()
        .padding()
}
