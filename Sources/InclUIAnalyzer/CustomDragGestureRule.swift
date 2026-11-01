import InclUICore
import SwiftSyntax

/// Flags an attached, state-changing DragGesture with no alternative on the same view.
public struct CustomDragGestureRule: AccessibilityRule {
    public let definition = AccessibilityRuleDefinitions.customDragGesture

    public init() {}

    public func analyze(
        syntax: SourceFileSyntax,
        filePath: String,
        locationConverter: SourceLocationConverter
    ) -> [Diagnostic] {
        let visitor = CustomDragGestureVisitor(
            filePath: filePath,
            locationConverter: locationConverter,
            rule: definition
        )
        visitor.walk(syntax)
        return visitor.diagnostics
    }
}

private final class CustomDragGestureVisitor: SyntaxVisitor {
    private let filePath: String
    private let locationConverter: SourceLocationConverter
    private let rule: AccessibilityRuleDefinition
    private var diagnosedExpressionOffsets: Set<Int> = []

    private(set) var diagnostics: [Diagnostic] = []

    init(
        filePath: String,
        locationConverter: SourceLocationConverter,
        rule: AccessibilityRuleDefinition
    ) {
        self.filePath = filePath
        self.locationConverter = locationConverter
        self.rule = rule
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard
            let modifierName = SyntaxInspection.modifierName(of: node),
            ["gesture", "highPriorityGesture", "simultaneousGesture"].contains(modifierName),
            let gestureArgument = node.arguments.first?.expression,
            let resolvedGesture = resolveLocalGesture(gestureArgument, at: node),
            containsCustomDrag(in: resolvedGesture),
            containsGestureCallback(in: resolvedGesture),
            let expression = SyntaxInspection.outermostChainedExpression(containing: node),
            !hasAccessibleAlternative(in: expression),
            let member = node.calledExpression.as(MemberAccessExprSyntax.self)
        else {
            return .visitChildren
        }

        let offset = expression.positionAfterSkippingLeadingTrivia.utf8Offset
        guard diagnosedExpressionOffsets.insert(offset).inserted else {
            return .visitChildren
        }

        let location = locationConverter.location(
            for: member.period.positionAfterSkippingLeadingTrivia
        )
        diagnostics.append(
            Diagnostic(
                rule: rule,
                filePath: filePath,
                line: location.line,
                column: location.column
            )
        )
        return .visitChildren
    }

    private func resolveLocalGesture(
        _ expression: ExprSyntax,
        at node: FunctionCallExprSyntax
    ) -> ExprSyntax? {
        guard let reference = expression.as(DeclReferenceExprSyntax.self) else {
            return expression
        }

        var ancestor = Syntax(node).parent
        while let current = ancestor {
            if current.is(CodeBlockSyntax.self) || current.is(AccessorBlockSyntax.self)
                || current.is(ClosureExprSyntax.self) {
                let finder = LocalGestureBindingVisitor(
                    name: reference.baseName.text,
                    scopeOffset: current.position.utf8Offset,
                    beforeOffset: node.position.utf8Offset
                )
                finder.walk(current)
                return finder.initializer
            }
            ancestor = current.parent
        }
        return nil
    }

    private func containsCustomDrag(in expression: ExprSyntax) -> Bool {
        let visitor = DragGesturePresenceVisitor()
        visitor.walk(expression)
        return visitor.foundDragGesture
    }

    private func containsGestureCallback(in expression: ExprSyntax) -> Bool {
        ["onChanged", "onEnded", "updating"].contains {
            SyntaxInspection.containsFunctionCall(named: $0, in: expression)
        }
    }

    private func hasAccessibleAlternative(in expression: ExprSyntax) -> Bool {
        let names: Set<String> = [
            "accessibilityAction", "accessibilityActions",
            "accessibilityAdjustableAction", "accessibilityRepresentation",
            "draggable", "onDrag"
        ]
        return SyntaxInspection.modifierCalls(in: expression).contains { call in
            guard let name = SyntaxInspection.modifierName(of: call) else { return false }
            return names.contains(name) && SyntaxInspection.isModifierEnabled(call)
        }
    }
}

private final class LocalGestureBindingVisitor: SyntaxVisitor {
    private let name: String
    private let scopeOffset: Int
    private let beforeOffset: Int
    private(set) var initializer: ExprSyntax?

    init(name: String, scopeOffset: Int, beforeOffset: Int) {
        self.name = name
        self.scopeOffset = scopeOffset
        self.beforeOffset = beforeOffset
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        node.position.utf8Offset == scopeOffset ? .visitChildren : .skipChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.position.utf8Offset < beforeOffset else { return .skipChildren }
        for binding in node.bindings {
            guard binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == name,
                  let value = binding.initializer?.value else {
                continue
            }
            initializer = value
            return .skipChildren
        }
        return .visitChildren
    }
}

private final class DragGesturePresenceVisitor: SyntaxVisitor {
    private(set) var foundDragGesture = false

    init() {
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        if SyntaxInspection.isSwiftUIConstructor(node, named: "DragGesture") {
            foundDragGesture = true
            return .skipChildren
        }
        return .visitChildren
    }
}
