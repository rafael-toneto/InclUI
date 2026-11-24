import AppKit
import Foundation
import SwiftUI
import InclUIAnalyzer
import InclUIReporter

private enum InclUIResources {
    static let bundle: Bundle = {
        if let url = Bundle.main.url(forResource: "InclUI_inclui-gui", withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        return .module
    }()
}

@main
struct InclUIGUIApp: App {
    @StateObject private var model = CheckerViewModel()

    init() {
        // A execução direta pelo SwiftPM não tem o Assets.car do bundle do app.
        guard Bundle.main.object(forInfoDictionaryKey: "CFBundleIconName") == nil,
              let url = InclUIResources.bundle.url(forResource: "AppIcon", withExtension: "png"),
              let icon = NSImage(contentsOf: url) else { return }
        NSApplication.shared.applicationIconImage = icon
    }

    var body: some Scene {
        WindowGroup("InclUI") {
            CheckerView(model: model)
        }
    }
}

/// Visual values shared with the HTML custom properties documented in README.
private enum InclUIStyle {
    static let spacing: CGFloat = 20
    static let radius: CGFloat = 14
    static let accentLight = Color(red: 0.72, green: 0.26, blue: 0.08)
    static let accentDark = Color(red: 1.00, green: 0.62, blue: 0.35)
    static let warningLight = Color(red: 0.52, green: 0.32, blue: 0.04)
    static let warningDark = Color(red: 1.00, green: 0.79, blue: 0.43)

    static func accent(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? accentDark : accentLight
    }

    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.17, green: 0.18, blue: 0.20) : .white
    }

    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.11, green: 0.12, blue: 0.13)
            : Color(red: 0.97, green: 0.97, blue: 0.96)
    }

    static func line(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .white.opacity(0.13) : .black.opacity(0.11)
    }
}

private struct CheckerView: View {
    @ObservedObject var model: CheckerViewModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InclUIStyle.spacing) {
                header
                sourceCard
                reportsCard
                runControls
                if model.isRunning {
                    Label("Analisando os arquivos Swift…", systemImage: "magnifyingglass")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                if let result = model.lastRun {
                    resultCard(result)
                } else if !model.isRunning && model.sourcePath.isEmpty {
                    emptyCard
                }
                Text("Os avisos indicam pontos para revisão. Confirme a experiência no app em execução.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .frame(maxWidth: 800, alignment: .leading)
            .padding(28)
            .frame(maxWidth: .infinity)
        }
        .background(InclUIStyle.background(scheme))
        .tint(InclUIStyle.accent(scheme))
        .frame(minWidth: 520, idealWidth: 760, minHeight: 520, idealHeight: 650)
        .alert("Não foi possível concluir a operação", isPresented: $model.showsError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            if let url = InclUIResources.bundle.url(forResource: "AppIcon", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 58, height: 58)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("InclUI")
                    .font(.system(.largeTitle, design: .default, weight: .bold))
                Text("Inspecione fontes SwiftUI e revise riscos de acessibilidade.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 4)
    }

    private var sourceCard: some View {
        sectionCard(number: "1", title: "Pasta de fontes", symbol: "folder") {
            pathText(model.sourcePath, placeholder: "Nenhuma pasta selecionada")
            HStack(spacing: 10) {
                Button("Escolher pasta…") { model.chooseSource() }
                    .disabled(model.isRunning)
                    .accessibilityHint("Escolha a pasta que contém os arquivos Swift do app.")
                if !model.recentSources.isEmpty {
                    Menu("Recentes") {
                        ForEach(model.recentSources, id: \.self) { path in
                            Button(path) { model.useRecentSource(path) }
                        }
                    }
                    .disabled(model.isRunning)
                    .fixedSize()
                }
            }
            Text("A análise percorre os arquivos .swift da pasta escolhida.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var reportsCard: some View {
        sectionCard(number: "2", title: "Destino dos relatórios", symbol: "doc.text") {
            pathText(model.reportsRootPath, placeholder: "")
            Button("Alterar destino…") { model.chooseReportsRoot() }
                .disabled(model.isRunning)
            Text("Cada execução cria uma pasta própria com HTML, Markdown, texto, JSON e warnings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var runControls: some View {
        HStack(spacing: 14) {
            Button {
                model.runAnalysis()
            } label: {
                Label("Gerar relatórios", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(InclUIStyle.accent(scheme))
            .disabled(model.sourcePath.isEmpty || model.isRunning)
            if model.isRunning {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Análise em andamento")
                Text("Análise em andamento")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "checklist")
                .font(.title2)
                .foregroundStyle(InclUIStyle.accent(scheme))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text("Comece pela pasta do app")
                    .font(.headline)
                Text("Escolha os fontes SwiftUI para gerar uma revisão. O código analisado não é alterado.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(scheme)
    }

    private func resultCard(_ result: GUIRunSummary) -> some View {
        sectionCard(number: nil, title: "Resultado da última análise", symbol: result.coverageIssueCount > 0 ? "exclamationmark.triangle" : "checkmark.circle") {
            pathText(result.sourcePath, placeholder: "")
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                metric(result.fileCount, label: "arquivos")
                metric(result.findingCount, label: "avisos")
                if result.coverageIssueCount > 0 {
                    metric(result.coverageIssueCount, label: "problemas de leitura")
                }
            }
            .padding(.vertical, 4)
            if result.coverageIssueCount > 0 {
                Label("Análise incompleta. Resolva os problemas de leitura e execute novamente.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(scheme == .dark ? InclUIStyle.warningDark : InclUIStyle.warningLight)
                    .fixedSize(horizontal: false, vertical: true)
            } else if result.findingCount == 0 {
                Text("Sem avisos nas regras verificadas. Valide a interface em execução.")
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 12) {
                    priorityCount(result.highCount, "Alta")
                    priorityCount(result.mediumCount, "Média")
                    priorityCount(result.lowCount, "Baixa")
                }
                .font(.footnote)
            }
            HStack(spacing: 10) {
                Button("Abrir relatório HTML") { model.openReport() }
                Button("Mostrar no Finder") { model.showReportsInFinder() }
            }
            .padding(.top, 4)
        }
    }

    private func metric(_ value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.formatted())
                .font(.system(.title, design: .rounded, weight: .semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func priorityCount(_ value: Int, _ label: String) -> some View {
        Text("\(label): \(value)")
            .foregroundStyle(.secondary)
    }

    private func pathText(_ path: String, placeholder: String) -> some View {
        Text(path.isEmpty ? placeholder : path)
            .font(.system(.callout, design: .monospaced))
            .foregroundStyle(path.isEmpty ? .secondary : .primary)
            .lineLimit(2)
            .truncationMode(.middle)
            .textSelection(.enabled)
            .help(path.isEmpty ? placeholder : path)
            .accessibilityLabel(path.isEmpty ? placeholder : path)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionCard<Content: View>(
        number: String?, title: String, symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .foregroundStyle(InclUIStyle.accent(scheme))
                    .accessibilityHidden(true)
                Text(number.map { "\($0). \(title)" } ?? title)
                    .font(.headline)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(scheme)
    }
}

private extension View {
    func cardSurface(_ scheme: ColorScheme) -> some View {
        padding(20)
            .background(InclUIStyle.surface(scheme), in: RoundedRectangle(cornerRadius: InclUIStyle.radius))
            .overlay {
                RoundedRectangle(cornerRadius: InclUIStyle.radius)
                    .strokeBorder(InclUIStyle.line(scheme), lineWidth: 1)
            }
    }
}

@MainActor
private final class CheckerViewModel: ObservableObject {
    @Published private(set) var sourcePath: String
    @Published private(set) var recentSources: [String]
    @Published private(set) var reportsRootPath: String
    @Published private(set) var lastRun: GUIRunSummary?
    @Published private(set) var isRunning = false
    @Published var showsError = false
    @Published private(set) var errorMessage = ""

    private enum PreferenceKey {
        static let recentSources = "InclUIGUI.recentSources"
        static let reportsRoot = "InclUIGUI.reportsRoot"
    }

    init() {
        let defaults = UserDefaults.standard
        let recent = (defaults.stringArray(forKey: PreferenceKey.recentSources) ?? [])
            .filter { FileManager.default.fileExists(atPath: $0) }
        recentSources = recent
        sourcePath = recent.first ?? ""
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
        reportsRootPath = defaults.string(forKey: PreferenceKey.reportsRoot)
            ?? documents.appendingPathComponent("InclUI-Relatorios").path
    }

    func chooseSource() {
        guard !isRunning else { return }
        let panel = NSOpenPanel()
        panel.message = "Escolha a pasta com os arquivos Swift do app"
        panel.prompt = "Usar esta pasta"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if !sourcePath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: sourcePath)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        useRecentSource(url.standardizedFileURL.path)
    }

    func useRecentSource(_ path: String) {
        guard !isRunning else { return }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            showError("A pasta não existe mais. Escolha outra pasta de fontes.")
            return
        }
        sourcePath = path
        lastRun = nil
        recentSources.removeAll { $0 == path }
        recentSources.insert(path, at: 0)
        recentSources = Array(recentSources.prefix(8))
        UserDefaults.standard.set(recentSources, forKey: PreferenceKey.recentSources)
    }

    func chooseReportsRoot() {
        guard !isRunning else { return }
        let panel = NSOpenPanel()
        panel.message = "Escolha onde guardar as pastas dos relatórios"
        panel.prompt = "Salvar aqui"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        let current = URL(fileURLWithPath: reportsRootPath)
        panel.directoryURL = FileManager.default.fileExists(atPath: current.path)
            ? current : current.deletingLastPathComponent()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        reportsRootPath = url.standardizedFileURL.path
        UserDefaults.standard.set(reportsRootPath, forKey: PreferenceKey.reportsRoot)
    }

    func runAnalysis() {
        guard !sourcePath.isEmpty, !isRunning else { return }
        let input = sourcePath
        let reportsRoot = reportsRootPath
        isRunning = true
        lastRun = nil

        Task {
            do {
                let summary = try await Task.detached(priority: .userInitiated) {
                    try GUIAnalysis.perform(inputPath: input, reportsRootPath: reportsRoot)
                }.value
                lastRun = summary
                isRunning = false
                openReport()
            } catch {
                isRunning = false
                if let analysisError = error as? GUIAnalysisError {
                    showError(analysisError.localizedDescription)
                } else {
                    showError("Não foi possível gerar os relatórios: \(error.localizedDescription)")
                }
            }
        }
    }

    func openReport() {
        guard let lastRun else { return }
        guard FileManager.default.fileExists(atPath: lastRun.reportPath) else {
            showError("O relatório não está mais no destino. Execute a análise novamente.")
            return
        }
        if !NSWorkspace.shared.open(URL(fileURLWithPath: lastRun.reportPath)) {
            showError("O relatório foi salvo, mas não abriu no navegador. Use “Mostrar no Finder”.")
        }
    }

    func showReportsInFinder() {
        guard let lastRun else { return }
        guard FileManager.default.fileExists(atPath: lastRun.reportPath) else {
            showError("Os arquivos não estão mais no destino. Execute a análise novamente.")
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: lastRun.reportPath)])
    }

    private func showError(_ message: String) {
        errorMessage = message
        showsError = true
    }
}

private struct GUIRunSummary: Sendable {
    let sourcePath: String
    let reportPath: String
    let fileCount: Int
    let findingCount: Int
    let coverageIssueCount: Int
    let highCount: Int
    let mediumCount: Int
    let lowCount: Int
}

private enum GUIAnalysis {
    static func perform(inputPath: String, reportsRootPath: String) throws -> GUIRunSummary {
        let run = ProjectAnalysisRunner().run(inputPaths: [inputPath])
        let result = run.result
        guard run.invalidInputPaths.isEmpty else {
            throw GUIAnalysisError.invalidInput
        }
        guard !result.analyzedFiles.isEmpty || !(result.analysisIssues ?? []).isEmpty else {
            throw GUIAnalysisError.noSwiftFiles
        }

        let sourceURL = URL(fileURLWithPath: inputPath)
        let sourceName = sourceURL.lastPathComponent
        let projectName = ["Sources", "Shared"].contains(sourceName)
            ? sourceURL.deletingLastPathComponent().lastPathComponent : sourceName
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let folderName = "\(projectName)-\(dateFormatter.string(from: Date()))"
        let root = URL(fileURLWithPath: reportsRootPath).standardizedFileURL
        var directory = root.appendingPathComponent(folderName, isDirectory: true)
        var suffix = 2
        while FileManager.default.fileExists(atPath: directory.path) {
            directory = root.appendingPathComponent("\(folderName)-\(suffix)", isDirectory: true)
            suffix += 1
        }

        let report = try ReportBundleWriter().write(result, to: directory)
        return GUIRunSummary(
            sourcePath: inputPath,
            reportPath: report.path,
            fileCount: result.analyzedFiles.count,
            findingCount: result.summary.totalIssues,
            coverageIssueCount: result.analysisIssues?.count ?? 0,
            highCount: result.summary.bySeverity["high", default: 0],
            mediumCount: result.summary.bySeverity["medium", default: 0],
            lowCount: result.summary.bySeverity["low", default: 0]
        )
    }
}

private enum GUIAnalysisError: LocalizedError {
    case invalidInput
    case noSwiftFiles

    var errorDescription: String? {
        switch self {
        case .invalidInput: "A pasta não existe ou não pôde ser lida. Escolha outra pasta."
        case .noSwiftFiles: "Nenhum arquivo Swift foi encontrado. Escolha a pasta com os fontes do app."
        }
    }
}
