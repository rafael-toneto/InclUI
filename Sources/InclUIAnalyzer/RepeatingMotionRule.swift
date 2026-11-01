import InclUICore
import SwiftSyntax

/// Finds a repeating SwiftUI animation in a view that does not read Reduce Motion.
public struct RepeatingMotionRule: AccessibilityRule {
    public let definition = AccessibilityRuleDefinitions.repeatingMotion

    public init() {}

    public func analyze(
        syntax: SourceFileSyntax,
        filePath: String,
        locationConverter: SourceLocationConverter
    ) -> [Diagnostic] {
        let visitor = RepeatingMotionVisitor(
            filePath: filePath,
            locationConverter: locationConverter,
            rule: definition
        )
        visitor.walk(syntax)
        return visitor.diagnostics
    }
}

private final class RepeatingMotionVisitor: SyntaxVisitor {
    private let filePath: String
    private let locationConverter: SourceLocationConverter
    private let rule: AccessibilityRuleDefinition

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
            SyntaxInspection.modifierName(of: node) == "repeatForever",
            isAppliedAnimation(node),
            !enclosingViewReadsReduceMotion(node),
            let member = node.calledExpression.as(MemberAccessExprSyntax.self)
        else {
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

    private func isAppliedAnimation(_ node: FunctionCallExprSyntax) -> Bool {
        var ancestor = Syntax(node).parent
        while let current = ancestor {
            if let call = current.as(FunctionCallExprSyntax.self),
               let name = SyntaxInspection.calledName(of: call),
               name == "animation" || name == "withAnimation" {
                return true
            }
            ancestor = current.parent
        }
        return false
    }

    private func enclosingViewReadsReduceMotion(_ node: FunctionCallExprSyntax) -> Bool {
        var ancestor = Syntax(node).parent
        while let current = ancestor {
            if let declaration = current.as(StructDeclSyntax.self) {
                return declaration.tokens(viewMode: .sourceAccurate).contains {
                    $0.text == "accessibilityReduceMotion"
                }
            }
            ancestor = current.parent
        }
        return false
    }
}
