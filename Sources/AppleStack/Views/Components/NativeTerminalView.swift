import AppKit
import SwiftUI

struct NativeTerminalView: View {
    let sessionTitle: String
    let sessionSubtitle: String
    let prompt: String
    let placeholder: String
    let isAvailable: Bool
    let unavailableTitle: String
    let unavailableMessage: String
    var showsMacTerminalButton = false
    @ObservedObject var session: PersistentTerminalSession

    @State private var command = ""
    @State private var commandHistory: [String] = []
    @State private var historyIndex: Int?
    @State private var focusRequestToken = UUID()
    @State private var externalTerminalError: String?
    @AppStorage("terminalFontSize") private var terminalFontSize = 12.0
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private let backgroundColor = AppTheme.terminalBackground
    private let borderColor = AppTheme.terminalBorder
    private let terminalUserColor = NSColor.systemGreen
    private let terminalHostColor = NSColor.systemBlue
    private let terminalForegroundColor = AppTheme.terminalTextNSColor

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        VStack(spacing: 0) {
            if isAvailable {
                terminalStatusBar
                if session.target.usesOneShotCommands {
                    oneShotCommandNotice
                }
            }

            ZStack(alignment: .topTrailing) {
                terminalSurface

                if isAvailable {
                    terminalOverlayControls
                        .padding(.top, 8)
                        .padding(.trailing, 10)
                }
            }

            if let errorMessage = displayedErrorMessage, isAvailable {
                Divider()
                    .overlay(borderColor)
                errorBanner(errorMessage)
            }
        }
        .background(backgroundColor)
        .contextMenu {
            terminalContextMenu
        }
        .task(id: isAvailable) {
            guard isAvailable else {
                session.close()
                return
            }
            session.activateIfNeeded()
        }
        .onAppear {
            if !session.commandHistory.isEmpty {
                commandHistory = session.commandHistory
            }
            requestInputFocus()
        }
        .onChange(of: isAvailable) { _, available in
            if available {
                requestInputFocus()
            }
        }
        .onChange(of: session.commandHistory) { _, updatedHistory in
            commandHistory = updatedHistory
        }
        .onChange(of: session.isConnected) { _, isConnected in
            if isConnected {
                requestInputFocus()
            }
        }
    }

    private var terminalStatusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(session.isConnected ? Color.green : Color.orange)
                .frame(width: 7, height: 7)

            Text(sessionTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)

            Text(sessionSubtitle)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Text(language.localized(session.isConnected ? "Connected" : session.isLaunching ? "Connecting..." : "Disconnected"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(AppTheme.terminalSecondaryBackground)
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(borderColor)
        }
    }

    private var oneShotCommandNotice: some View {
        HStack(alignment: .center, spacing: 8) {
            SwiftUI.Image(systemName: "info.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.accentColor)

            Text(language.localized("This machine terminal runs one command at a time. Use macOS Terminal for a fully interactive shell."))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button {
                openMacTerminal()
            } label: {
                Label(language.localized("Open in macOS Terminal"), systemImage: "macwindow")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderless)
            .disabled(!isAvailable)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(AppTheme.terminalSecondaryBackground.opacity(0.82))
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(borderColor)
        }
    }

    @ViewBuilder
    private var terminalContextMenu: some View {
        Button {
            copyTranscript()
        } label: {
            Label(language.localized("Copy terminal output"), systemImage: "doc.on.doc")
        }
        .disabled(displayedTranscript.isEmpty)

        Button {
            clearTranscript()
        } label: {
            Label(language.localized("Clear terminal"), systemImage: "trash")
        }
        .disabled(session.transcript.isEmpty)

        if isAvailable, !session.isConnected, !session.isLaunching {
            Button {
                session.activateIfNeeded()
            } label: {
                Label(language.localized("Connect"), systemImage: "bolt.horizontal")
            }
        }

        if showsMacTerminalButton {
            Divider()

            Button {
                openMacTerminal()
            } label: {
                Label(language.localized("Open in macOS Terminal"), systemImage: "macwindow")
            }
            .disabled(!isAvailable)
        }
    }

    @ViewBuilder
    private var terminalSurface: some View {
        if isAvailable {
            TerminalConsoleView(
                attributedText: attributedTranscript,
                prompt: displayPrompt,
                command: $command,
                placeholder: placeholder,
                fontSize: CGFloat(terminalFontSize),
                isEnabled: isAvailable && session.isConnected && !session.isExecutingCommand,
                focusRequestToken: focusRequestToken,
                onSubmit: submitCurrentCommand,
                onHistoryUp: showPreviousCommand,
                onHistoryDown: showNextCommand,
                onClear: clearTranscript,
                onCopy: copyTranscript,
                copyLabel: language.localized("Copy terminal output"),
                clearLabel: language.localized("Clear terminal")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            unavailableView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(backgroundColor)
        }
    }

    private var terminalOverlayControls: some View {
        HStack(spacing: 4) {
            if session.isLaunching {
                ProgressView()
                    .controlSize(.small)
                    .padding(.horizontal, 5)
            }

            if showsMacTerminalButton {
                terminalToolbarButton("macwindow", help: language.localized("Open in macOS Terminal")) {
                    openMacTerminal()
                }
                .disabled(!isAvailable)
            }

            if isAvailable, !session.isConnected, !session.isLaunching {
                terminalToolbarButton("bolt.horizontal", help: language.localized("Connect")) {
                    session.activateIfNeeded()
                }
            }

            terminalToolbarButton("trash", help: language.localized("Clear terminal")) {
                clearTranscript()
            }
            .disabled(session.transcript.isEmpty)

            terminalToolbarButton("doc.on.doc", help: language.localized("Copy terminal output")) {
                copyTranscript()
            }
        }
        .padding(3)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(borderColor.opacity(0.8), lineWidth: 0.5)
        )
    }

    private func terminalToolbarButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SwiftUI.Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
    }

    private var displayedErrorMessage: String? {
        externalTerminalError ?? session.lastError
    }

    private var unavailableView: some View {
        VStack(spacing: 12) {
            SwiftUI.Image(systemName: "terminal")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text(unavailableTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isAvailable ? Color(nsColor: terminalForegroundColor) : .primary)
            Text(unavailableMessage)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            SwiftUI.Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.orange)

            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.09))
    }

    private var canSubmit: Bool {
        isAvailable && session.isConnected && !session.isExecutingCommand && !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var displayedTranscript: String {
        session.transcript
    }

    private var attributedTranscript: NSAttributedString {
        highlightedTranscript(
            displayedTranscript,
            sessionTitle: sessionTitle,
            sessionSubtitle: sessionSubtitle,
            prompt: displayPrompt
        )
    }

    private var displayPrompt: String {
        let normalizedName = sessionSubtitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: "")

        let host = normalizedName.isEmpty ? "Shell" : normalizedName
        let user = NSUserName()
        return "\(user)@\(host):~$"
    }

    private func openMacTerminal() {
        do {
            try session.openInMacTerminal()
            externalTerminalError = nil
        } catch {
            externalTerminalError = error.localizedDescription
        }
    }

    private func submitCurrentCommand() {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, isAvailable, session.isConnected else { return }

        command = ""
        if commandHistory.last != trimmed {
            commandHistory.append(trimmed)
        }
        session.recordSubmittedCommand(trimmed)
        historyIndex = nil
        session.appendLocalEcho("\(displayPrompt) \(trimmed)\n")
        requestInputFocus()

        Task {
            do {
                try await session.send(command: trimmed)
            } catch {
                session.appendLocalEcho("Error: \(error.localizedDescription)\n\n")
            }
        }
    }

    private func showPreviousCommand() {
        guard !commandHistory.isEmpty else { return }

        if let historyIndex {
            let nextIndex = max(commandHistory.startIndex, historyIndex - 1)
            self.historyIndex = nextIndex
            command = commandHistory[nextIndex]
        } else {
            let lastIndex = commandHistory.index(before: commandHistory.endIndex)
            historyIndex = lastIndex
            command = commandHistory[lastIndex]
        }
    }

    private func showNextCommand() {
        guard !commandHistory.isEmpty else { return }

        guard let historyIndex else {
            command = ""
            return
        }

        let nextIndex = historyIndex + 1
        if nextIndex < commandHistory.endIndex {
            self.historyIndex = nextIndex
            command = commandHistory[nextIndex]
        } else {
            self.historyIndex = nil
            command = ""
        }
    }

    private func clearTranscript() {
        session.clearTranscript()
    }

    private func copyTranscript() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(displayedTranscript, forType: .string)
    }

    private func requestInputFocus() {
        focusRequestToken = UUID()
    }

    private func highlightedTranscript(
        _ text: String,
        sessionTitle: String,
        sessionSubtitle: String,
        prompt: String
    ) -> NSAttributedString {
        let fontSize = CGFloat(terminalFontSize)
        let semiboldFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
        let attributed = parseANSIAttributedString(text)

        let cleanText = attributed.string
        let lines = cleanText.components(separatedBy: "\n")
        let promptNSString = prompt as NSString
        var currentLocation = 0
        var previousCommand: String?

        for line in lines {
            let lineLength = (line as NSString).length
            let lineRange = NSRange(location: currentLocation, length: lineLength)
            defer { currentLocation += lineLength + 1 }

            guard !line.isEmpty else {
                previousCommand = nil
                continue
            }

            if line == sessionTitle || line == sessionSubtitle || (line.hasPrefix("[") && line.hasSuffix("]")) {
                attributed.addAttributes(
                    [.foregroundColor: NSColor.secondaryLabelColor],
                    range: lineRange
                )
                previousCommand = nil
                continue
            }

            if line.hasPrefix("Error:") || line.contains("[session exited with code") {
                attributed.addAttributes(
                    [.foregroundColor: NSColor.systemRed],
                    range: lineRange
                )
                previousCommand = nil
                continue
            }

            if line.hasPrefix("\(prompt) ") {
                stylePrompt(in: attributed, prompt: prompt, rangeStart: currentLocation)

                let commandStart = currentLocation + promptNSString.length + 1
                let commandLength = max(0, lineLength - promptNSString.length - 1)
                if commandLength > 0 {
                    attributed.addAttributes(
                        [
                            .foregroundColor: terminalForegroundColor,
                            .font: semiboldFont,
                        ],
                        range: NSRange(location: commandStart, length: commandLength)
                    )
                }

                previousCommand = String(line.dropFirst(prompt.count + 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }

            if let previousCommand, shouldHighlightAsDirectoryOutput(line: line, previousCommand: previousCommand) {
                attributed.addAttributes(
                    [
                        .foregroundColor: NSColor.systemBlue,
                        .font: semiboldFont,
                    ],
                    range: lineRange
                )
                continue
            }

            previousCommand = nil
        }

        return attributed
    }

    private func stylePrompt(in attributed: NSMutableAttributedString, prompt: String, rangeStart: Int) {
        let nsPrompt = prompt as NSString
        let promptRange = NSRange(location: rangeStart, length: nsPrompt.length)
        let promptText = prompt

        if let atIndex = promptText.firstIndex(of: "@"),
           let colonIndex = promptText.firstIndex(of: ":") {
            let userLength = promptText.distance(from: promptText.startIndex, to: atIndex)
            let hostStart = promptText.index(after: atIndex)
            let hostLength = promptText.distance(from: hostStart, to: colonIndex)
            let suffixStart = promptText.distance(from: promptText.startIndex, to: colonIndex)

            if userLength > 0 {
                attributed.addAttributes(
                    [
                            .foregroundColor: terminalUserColor,
                            .font: NSFont.monospacedSystemFont(ofSize: CGFloat(terminalFontSize), weight: .semibold),
                        ],
                    range: NSRange(location: rangeStart, length: userLength)
                )
            }

            attributed.addAttributes(
                [
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .font: NSFont.monospacedSystemFont(ofSize: CGFloat(terminalFontSize), weight: .semibold),
                ],
                range: NSRange(location: rangeStart + userLength, length: 1)
            )

            if hostLength > 0 {
                attributed.addAttributes(
                    [
                        .foregroundColor: terminalHostColor,
                        .font: NSFont.monospacedSystemFont(ofSize: CGFloat(terminalFontSize), weight: .semibold),
                    ],
                    range: NSRange(location: rangeStart + userLength + 1, length: hostLength)
                )
            }

            let suffixLength = promptRange.length - suffixStart
            if suffixLength > 0 {
                attributed.addAttributes(
                    [
                        .foregroundColor: terminalUserColor,
                        .font: NSFont.monospacedSystemFont(ofSize: CGFloat(terminalFontSize), weight: .semibold),
                    ],
                    range: NSRange(location: rangeStart + suffixStart, length: suffixLength)
                )
            }
        } else {
            attributed.addAttributes(
                [
                    .foregroundColor: terminalUserColor,
                    .font: NSFont.monospacedSystemFont(ofSize: CGFloat(terminalFontSize), weight: .semibold),
                ],
                range: promptRange
            )
        }
    }

    private func parseANSIAttributedString(_ text: String) -> NSMutableAttributedString {
        let baseFont = NSFont.monospacedSystemFont(ofSize: CGFloat(terminalFontSize), weight: .regular)
        let boldFont = NSFont.monospacedSystemFont(ofSize: CGFloat(terminalFontSize), weight: .semibold)
        var currentColor: NSColor = terminalForegroundColor
        var isBold = false
        let output = NSMutableAttributedString()

        func appendSegment(_ value: String) {
            guard !value.isEmpty else { return }
            output.append(
                NSAttributedString(
                    string: value,
                    attributes: [
                        .font: isBold ? boldFont : baseFont,
                        .foregroundColor: currentColor,
                    ]
                )
            )
        }

        var buffer = ""
        var index = text.startIndex

        while index < text.endIndex {
            if text[index] == "\u{001B}" {
                let nextIndex = text.index(after: index)
                if nextIndex < text.endIndex, text[nextIndex] == "[" {
                    appendSegment(buffer)
                    buffer.removeAll(keepingCapacity: true)

                    var codeIndex = text.index(after: nextIndex)
                    var code = ""
                    while codeIndex < text.endIndex {
                        let character = text[codeIndex]
                        if character == "m" {
                            applyANSICode(code, currentColor: &currentColor, isBold: &isBold)
                            break
                        }
                        code.append(character)
                        codeIndex = text.index(after: codeIndex)
                    }

                    if codeIndex < text.endIndex {
                        index = text.index(after: codeIndex)
                        continue
                    } else {
                        break
                    }
                }
            }

            buffer.append(text[index])
            index = text.index(after: index)
        }

        appendSegment(buffer)
        return output
    }

    private func applyANSICode(_ code: String, currentColor: inout NSColor, isBold: inout Bool) {
        let parts = code.split(separator: ";").compactMap { Int($0) }
        if parts.isEmpty {
            currentColor = terminalForegroundColor
            isBold = false
            return
        }

        for part in parts {
            switch part {
            case 0:
                currentColor = terminalForegroundColor
                isBold = false
            case 1:
                isBold = true
            case 22:
                isBold = false
            case 30:
                currentColor = .black
            case 31:
                currentColor = .systemRed
            case 32:
                currentColor = .systemGreen
            case 33:
                currentColor = .systemOrange
            case 34:
                currentColor = .systemBlue
            case 35:
                currentColor = .systemPurple
            case 36:
                currentColor = .systemTeal
            case 37:
                currentColor = terminalForegroundColor
            case 39:
                currentColor = terminalForegroundColor
            case 90:
                currentColor = .secondaryLabelColor
            case 91:
                currentColor = NSColor.systemRed.blended(withFraction: 0.18, of: .white) ?? .systemRed
            case 92:
                currentColor = NSColor.systemGreen.blended(withFraction: 0.18, of: .white) ?? .systemGreen
            case 93:
                currentColor = NSColor.systemYellow.blended(withFraction: 0.12, of: .white) ?? .systemYellow
            case 94:
                currentColor = NSColor.systemBlue.blended(withFraction: 0.18, of: .white) ?? .systemBlue
            case 95:
                currentColor = NSColor.systemPurple.blended(withFraction: 0.18, of: .white) ?? .systemPurple
            case 96:
                currentColor = NSColor.systemTeal.blended(withFraction: 0.18, of: .white) ?? .systemTeal
            case 97:
                currentColor = terminalForegroundColor
            default:
                continue
            }
        }
    }

    private func shouldHighlightAsDirectoryOutput(line: String, previousCommand: String) -> Bool {
        let normalizedCommand = previousCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedCommand == "ls" || normalizedCommand.hasPrefix("ls ") else {
            return false
        }

        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty else {
            return false
        }

        if trimmedLine.contains(" ") || trimmedLine.contains("/") || trimmedLine.hasPrefix("[") {
            return false
        }

        return true
    }
}

private struct TerminalConsoleView: NSViewRepresentable {
    let attributedText: NSAttributedString
    let prompt: String
    @Binding var command: String
    let placeholder: String
    let fontSize: CGFloat
    let isEnabled: Bool
    let focusRequestToken: UUID
    let onSubmit: () -> Void
    let onHistoryUp: () -> Void
    let onHistoryDown: () -> Void
    let onClear: () -> Void
    let onCopy: () -> Void
    let copyLabel: String
    let clearLabel: String

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $command,
            onSubmit: onSubmit,
            onHistoryUp: onHistoryUp,
            onHistoryDown: onHistoryDown,
            onClear: onClear,
            onCopy: onCopy,
            copyLabel: copyLabel,
            clearLabel: clearLabel
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let transcriptTextView = NSTextView()
        transcriptTextView.isEditable = false
        transcriptTextView.isSelectable = true
        transcriptTextView.drawsBackground = false
        transcriptTextView.textColor = AppTheme.terminalTextNSColor
        transcriptTextView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        transcriptTextView.textContainerInset = NSSize(width: 0, height: 0)
        transcriptTextView.isRichText = false
        transcriptTextView.usesFindBar = true
        transcriptTextView.isVerticallyResizable = true
        transcriptTextView.isHorizontallyResizable = false
        transcriptTextView.autoresizingMask = [.width]
        transcriptTextView.textContainer?.widthTracksTextView = true
        transcriptTextView.textContainer?.lineFragmentPadding = 0
        transcriptTextView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        transcriptTextView.menu = context.coordinator.makeContextMenu()

        let promptLabel = NSTextField(labelWithString: prompt)
        promptLabel.font = .monospacedSystemFont(ofSize: fontSize, weight: .semibold)
        promptLabel.textColor = .systemGreen

        let commandField = TerminalCommandTextField()
        commandField.delegate = context.coordinator
        commandField.isBordered = false
        commandField.isBezeled = false
        commandField.focusRingType = .none
        commandField.drawsBackground = false
        commandField.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        commandField.textColor = AppTheme.terminalTextNSColor
        commandField.onSubmit = onSubmit
        commandField.onHistoryUp = onHistoryUp
        commandField.onHistoryDown = onHistoryDown
        commandField.onClear = onClear
        commandField.menu = context.coordinator.makeContextMenu()

        let promptRow = NSStackView(views: [promptLabel, commandField])
        promptRow.orientation = .horizontal
        promptRow.alignment = .centerY
        promptRow.spacing = 8
        promptRow.setHuggingPriority(.required, for: .vertical)

        let contentView = FlippedContentView()
        let stackView = NSStackView(views: [transcriptTextView, promptRow])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 4
        stackView.setCustomSpacing(6, after: transcriptTextView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)

        let transcriptHeightConstraint = transcriptTextView.heightAnchor.constraint(equalToConstant: 1)
        transcriptHeightConstraint.priority = .defaultHigh
        transcriptHeightConstraint.isActive = true

        let transcriptWidthConstraint = transcriptTextView.widthAnchor.constraint(equalTo: stackView.widthAnchor)
        transcriptWidthConstraint.priority = .required
        transcriptWidthConstraint.isActive = true

        let promptRowWidthConstraint = promptRow.widthAnchor.constraint(equalTo: stackView.widthAnchor)
        promptRowWidthConstraint.priority = .defaultHigh
        promptRowWidthConstraint.isActive = true

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            stackView.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: -28),
            commandField.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
        ])

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = contentView

        contentView.frame = NSRect(x: 0, y: 0, width: 640, height: 120)

        context.coordinator.textView = transcriptTextView
        context.coordinator.textHeightConstraint = transcriptHeightConstraint
        context.coordinator.commandField = commandField
        context.coordinator.promptLabel = promptLabel
        context.coordinator.contentView = contentView
        context.coordinator.stackView = stackView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard
            let textView = context.coordinator.textView,
            let textHeightConstraint = context.coordinator.textHeightConstraint,
            let commandField = context.coordinator.commandField,
            let promptLabel = context.coordinator.promptLabel
        else { return }

        textView.textStorage?.setAttributedString(attributedText)
        textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        promptLabel.font = .monospacedSystemFont(ofSize: fontSize, weight: .semibold)
        commandField.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        if let textContainer = textView.textContainer,
           let layoutManager = textView.layoutManager {
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            textHeightConstraint.constant = max(usedRect.height + 4, attributedText.length > 0 ? 20 : 1)
        }

        promptLabel.stringValue = prompt
        commandField.isEnabled = isEnabled
        commandField.textColor = AppTheme.terminalTextNSColor
        commandField.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: NSColor.secondaryLabelColor]
        )
        if commandField.stringValue != command {
            commandField.stringValue = command
        }
        commandField.onSubmit = onSubmit
        commandField.onHistoryUp = onHistoryUp
        commandField.onHistoryDown = onHistoryDown
        commandField.onClear = onClear

        if let contentView = context.coordinator.contentView,
           let stackView = context.coordinator.stackView {
            contentView.layoutSubtreeIfNeeded()
            let contentWidth = max(scrollView.contentSize.width, 320)
            let contentHeight = max(stackView.fittingSize.height + 20, scrollView.contentSize.height)
            contentView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
            contentView.layoutSubtreeIfNeeded()
        }

        if commandField.focusRequestToken != focusRequestToken {
            commandField.focusRequestToken = focusRequestToken
            if isEnabled {
                DispatchQueue.main.async {
                    commandField.window?.makeFirstResponder(commandField)
                    scrollToBottom(scrollView)
                }
            }
        }

        DispatchQueue.main.async {
            scrollToBottom(scrollView)
        }
    }

    private func scrollToBottom(_ scrollView: NSScrollView) {
        guard let documentView = scrollView.documentView else { return }
        let visibleHeight = scrollView.contentSize.height
        let documentHeight = documentView.bounds.height
        let targetY = max(0, documentHeight - visibleHeight)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: targetY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding private var text: String
        private let onSubmit: () -> Void
        private let onHistoryUp: () -> Void
        private let onHistoryDown: () -> Void
        private let onClear: () -> Void
        private let onCopy: () -> Void
        private let copyLabel: String
        private let clearLabel: String

        weak var textView: NSTextView?
        weak var commandField: TerminalCommandTextField?
        weak var promptLabel: NSTextField?
        weak var contentView: FlippedContentView?
        weak var stackView: NSStackView?
        var textHeightConstraint: NSLayoutConstraint?

        init(
            text: Binding<String>,
            onSubmit: @escaping () -> Void,
            onHistoryUp: @escaping () -> Void,
            onHistoryDown: @escaping () -> Void,
            onClear: @escaping () -> Void,
            onCopy: @escaping () -> Void,
            copyLabel: String,
            clearLabel: String
        ) {
            self._text = text
            self.onSubmit = onSubmit
            self.onHistoryUp = onHistoryUp
            self.onHistoryDown = onHistoryDown
            self.onClear = onClear
            self.onCopy = onCopy
            self.copyLabel = copyLabel
            self.clearLabel = clearLabel
        }

        func makeContextMenu() -> NSMenu {
            let menu = NSMenu()
            let copyItem = NSMenuItem(title: copyLabel, action: #selector(copyTerminalOutput), keyEquivalent: "")
            copyItem.target = self
            menu.addItem(copyItem)

            let clearItem = NSMenuItem(title: clearLabel, action: #selector(clearTerminal), keyEquivalent: "")
            clearItem.target = self
            menu.addItem(clearItem)
            return menu
        }

        @objc private func copyTerminalOutput() {
            onCopy()
        }

        @objc private func clearTerminal() {
            onClear()
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                onSubmit()
                return true
            case #selector(NSResponder.moveUp(_:)):
                onHistoryUp()
                return true
            case #selector(NSResponder.moveDown(_:)):
                onHistoryDown()
                return true
            default:
                return false
            }
        }
    }
}

private final class FlippedContentView: NSView {
    override var isFlipped: Bool { true }
}

private final class TerminalCommandTextField: NSTextField {
    var focusRequestToken: UUID?
    var onSubmit: (() -> Void)?
    var onHistoryUp: (() -> Void)?
    var onHistoryDown: (() -> Void)?
    var onClear: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:
            onSubmit?()
        case 126:
            onHistoryUp?()
        case 125:
            onHistoryDown?()
        default:
            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers?.lowercased() == "k" {
                onClear?()
            } else {
                super.keyDown(with: event)
            }
        }
    }
}
