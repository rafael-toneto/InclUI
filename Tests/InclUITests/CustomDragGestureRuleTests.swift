import InclUIAnalyzer
import Testing

@Suite("CustomDragGestureRule")
struct CustomDragGestureRuleTests {
    private let analyzer = SwiftSourceAnalyzer(rules: [CustomDragGestureRule()])

    @Test("Detects a state-changing custom drag attached to a view")
    func detectsAttachedDrag() {
        let source = """
        Rectangle()
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in complete() }
            )
        """
        let diagnostics = analyzer.analyze(source: source, filePath: "Splash.swift")
        #expect(diagnostics.map(\.ruleIdentifier) == ["SAC010"])
        #expect(diagnostics.first?.line == 2)
    }

    @Test("Detects a sequenced drag used for an action")
    func detectsSequencedDrag() {
        let source = """
        poster
            .simultaneousGesture(
                LongPressGesture().sequenced(before: DragGesture())
                    .onEnded { _ in dismiss() }
            )
        """
        #expect(analyzer.analyze(source: source, filePath: "Poster.swift").count == 1)
    }

    @Test("Detects a drag stored in a local gesture binding")
    func detectsLocalBinding() {
        let source = """
        struct Poster: View {
            var body: some View {
                let swipe = LongPressGesture().sequenced(before: DragGesture())
                    .onEnded { _ in addToWishlist() }
                return Image("poster").gesture(swipe)
            }
        }
        """
        let diagnostics = analyzer.analyze(source: source, filePath: "Poster.swift")
        #expect(diagnostics.map(\.ruleIdentifier) == ["SAC010"])
        #expect(diagnostics.first?.line == 5)
    }

    @Test("Does not resolve a gesture binding in another scope")
    func respectsLocalScope() {
        let source = """
        struct Poster: View {
            func unused() {
                let swipe = DragGesture().onEnded { _ in addToWishlist() }
            }
            var body: some View {
                return Image("poster").gesture(swipe)
            }
        }
        """
        #expect(analyzer.analyze(source: source, filePath: "Poster.swift").isEmpty)
    }

    @Test("Does not borrow a gesture binding from a nested closure")
    func ignoresNestedBinding() {
        let source = """
        struct Poster: View {
            var body: some View {
                let unrelated = Button("Other") {
                    let swipe = DragGesture().onEnded { _ in addToWishlist() }
                }
                return Image("poster").gesture(swipe)
            }
        }
        """
        #expect(analyzer.analyze(source: source, filePath: "Poster.swift").isEmpty)
    }

    @Test("Accepts an accessibility action on the same view")
    func acceptsAction() {
        let source = """
        Rectangle()
            .gesture(DragGesture().onEnded { _ in complete() })
            .accessibilityAction(named: "Complete") { complete() }
        """
        #expect(analyzer.analyze(source: source, filePath: "Splash.swift").isEmpty)
    }

    @Test("Ignores native drag and a gesture declaration not attached to a view")
    func avoidsUnattachedGesture() {
        let source = """
        let unused = DragGesture().onEnded { _ in complete() }
        Text("Item").draggable(item)
        """
        #expect(analyzer.analyze(source: source, filePath: "Item.swift").isEmpty)
    }

    @Test("Does not accept an accessibility action on a child of the dragged view")
    func doesNotUseChildAction() {
        let source = """
        VStack { Text("Child").accessibilityAction(named: "Open") { open() } }
            .gesture(DragGesture().onEnded { _ in complete() })
        """
        #expect(analyzer.analyze(source: source, filePath: "Container.swift").count == 1)
    }
}
