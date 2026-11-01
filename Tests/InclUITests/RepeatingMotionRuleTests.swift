import InclUIAnalyzer
import Testing

@Suite("RepeatingMotionRule")
struct RepeatingMotionRuleTests {
    private let analyzer = SwiftSourceAnalyzer(rules: [RepeatingMotionRule()])

    @Test("Detects an applied repeating animation without Reduce Motion")
    func detectsRepeatingAnimation() {
        let source = """
        struct HintView: View {
            var body: some View {
                Text("Swipe")
                    .animation(.easeInOut(duration: 1).repeatForever(), value: pulsing)
            }
        }
        """
        let diagnostics = analyzer.analyze(source: source, filePath: "HintView.swift")
        #expect(diagnostics.map(\.ruleIdentifier) == ["SAC011"])
        #expect(diagnostics.first?.line == 4)
    }

    @Test("Detects a repeating withAnimation call")
    func detectsWithAnimation() {
        let source = """
        withAnimation(.linear(duration: 2).repeatForever()) { phase = 1 }
        """
        #expect(analyzer.analyze(source: source, filePath: "Shimmer.swift").count == 1)
    }

    @Test("Accepts a view that reads the Reduce Motion preference")
    func acceptsReduceMotionRead() {
        let source = """
        struct HintView: View {
            @Environment(\\.accessibilityReduceMotion) private var reduceMotion
            var body: some View {
                Text("Hint")
                    .animation(.linear(duration: 1).repeatForever(), value: pulsing)
            }
        }
        """
        #expect(analyzer.analyze(source: source, filePath: "HintView.swift").isEmpty)
    }

    @Test("A comment does not count as reading Reduce Motion")
    func ignoresCommentMention() {
        let source = """
        struct HintView: View {
            // TODO: accessibilityReduceMotion
            var body: some View {
                Text("Hint").animation(.linear.repeatForever(), value: pulsing)
            }
        }
        """
        #expect(analyzer.analyze(source: source, filePath: "HintView.swift").count == 1)
    }

    @Test("Ignores an animation declaration that is not applied")
    func ignoresUnappliedAnimation() {
        let source = "let unused = Animation.linear.repeatForever()"
        #expect(analyzer.analyze(source: source, filePath: "HintView.swift").isEmpty)
    }
}
