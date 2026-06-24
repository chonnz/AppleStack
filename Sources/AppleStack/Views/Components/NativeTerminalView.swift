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
    @ObservedObject var session: PersistentTerminalSession

    @State private var command = ""
    @State private var commandHistory: [String] = []
    @State private var historyIndex: Int?
    @State private var focusRequestToken = UUID()
    @AppStorage("terminalFontSize") private var terminalFontSize = 12.0
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private let backgroundColor = AppTheme.terminalBackground
    private let borderColor = AppTheme.terminalBorder
    private let foregroundColor = Color.primary
    private let promptColor = Color(nsColor: NSColor.systemGreen)
    private let terminalUserColor = NSColor.systemGreen
    private let terminalHostColor = NSColor.systemBlue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        VStack(spacing: 0) {
            utilityBar
            Divider()
                .overlay(borderColor)

            if isAvailable {
                TerminalConsoleView(
                    attributedText: attributedTranscript,
                    prompt: displayPrompt,
                    command: $command,
                    placeholder: placeholder,
                    fontSize: CGFloat(terminalFontSize),
                    isEnabled: isAvailable && session.isConnected,
                    focusRequestToken: focusRequestToken,
                    onSubmit: submitCurrentCommand,
                    onHistoryUp: showPreviousCommand,
                    onHistoryDown: showNextCommand,
                    onClear: clearTranscript
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                unavailableView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(backgroundColor)
            }

            if let errorMessage = session.lastError, isAvailable {
                Divider()
                    .overlay(borderColor)
                errorBanner(errorMessage)
            }
        }
        .background(backgroundColor)
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

    private var utilityBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 7) {
                Circle()
                    .fill(sessionStatusColor)
                    .frame(width: 7, height: 7)

                Text(sessionSubtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(foregroundColor)
                    .lineLimit(1)
            }

            Text(sessionStatusText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            if session.isLaunching {
                ProgressView()
                    .controlSize(.small)
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
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(backgroundColor)
    }

    private var sessionStatusColor: Color {
        if !isAvailable {
            return .secondary
        }
        if session.isConnected {
            return .green
        }
        if session.isLaunching {
            return .orange
        }
        return .secondary
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

    private var unavailableView: some View {
        VStack(spacing: 12) {
            SwiftUI.Image(systemName: "terminal")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text(unavailableTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
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
        isAvailable && session.isConnected && !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    private var sessionStatusText: String {
        if !isAvailable {
            return "Unavailable"
        }
        if session.isLaunching {
            return "Connecting..."
        }
        if session.isConnected {
            return "Connected"
        }
        return "Disconnected"
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

        do {
            try session.send(command: trimmed)
        } catch {
            session.appendLocalEcho("Error: \(error.localizedDescription)\n\n")
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
                            .foregroundColor: NSColor.labelColor,
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
        var currentColor: NSColor = .labelColor
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
            currentColor = .labelColor
            isBold = false
            return
        }

        for part in parts {
            switch part {
            case 0:
                currentColor = .labelColor
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
                currentColor = .labelColor
            case 39:
                currentColor = .labelColor
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
                currentColor = .labelColor
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

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $command,
            onSubmit: onSubmit,
            onHistoryUp: onHistoryUp,
            onHistoryDown: onHistoryDown
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let transcriptTextView = NSTextView()
        transcriptTextView.isEditable = false
        transcriptTextView.isSelectable = true
        transcriptTextView.drawsBackground = false
        transcriptTextView.textColor = .labelColor
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
        commandField.textColor = .labelColor
        commandField.onSubmit = onSubmit
        commandField.onHistoryUp = onHistoryUp
        commandField.onHistoryDown = onHistoryDown
        commandField.onClear = onClear

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
        commandField.textColor = .labelColor
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
            onHistoryDown: @escaping () -> Void
        ) {
            self._text = text
            self.onSubmit = onSubmit
            self.onHistoryUp = onHistoryUp
            self.onHistoryDown = onHistoryDown
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
