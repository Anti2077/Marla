import AppKit
import MarlaCore
import SwiftUI
import UniformTypeIdentifiers

struct SheetWindowCornerConfigurator: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.alphaValue = 0
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configureWindow(for: nsView)
        DispatchQueue.main.async {
            configureWindow(for: nsView)
        }
    }

    private func configureWindow(for view: NSView) {
        guard let window = view.window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = cornerRadius
        window.contentView?.layer?.cornerCurve = .continuous
        window.contentView?.layer?.masksToBounds = true
    }
}

struct SettingsPageShell<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spaceL) {
                VStack(alignment: .leading, spacing: DesignTokens.spaceXS) {
                    Text(title).font(AppFont.title)
                    Text(subtitle).font(AppFont.body).foregroundStyle(DesignTokens.secondaryText)
                }
                content()
            }
            .frame(maxWidth: 650, alignment: .leading)
            .padding(.horizontal, DesignTokens.spaceL)
            .padding(.top, 36)
            .padding(.bottom, DesignTokens.spaceM)
        }
        .scrollIndicators(.never)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spaceM) {
            Label(title, systemImage: systemImage)
                .font(AppFont.bodyEmphasis)
                .foregroundStyle(DesignTokens.primaryText)
            content()
        }
        .padding(DesignTokens.spaceL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .marlaGlassSurface(cornerRadius: DesignTokens.radiusM)
    }
}

struct LanguagePreferenceRow: View {
    let title: String
    let detail: String
    let selection: TranslationLanguage
    let disabledLanguage: TranslationLanguage
    let onSelect: (TranslationLanguage) -> Void

    var body: some View {
        HStack(spacing: DesignTokens.spaceL) {
            VStack(alignment: .leading, spacing: DesignTokens.spaceXS) {
                Text(title)
                    .font(AppFont.bodyEmphasis)
                Text(detail)
                    .font(AppFont.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
            }
            Spacer(minLength: DesignTokens.spaceL)
            Menu {
                ForEach(TranslationLanguage.allCases) { language in
                    Button {
                        onSelect(language)
                    } label: {
                        if language == selection {
                            Label(language.label, systemImage: "checkmark")
                        } else {
                            Text(language.label)
                        }
                    }
                    .disabled(language == disabledLanguage || language == selection)
                }
            } label: {
                Text(selection.label)
                    .font(AppFont.body)
                .frame(minWidth: 112, alignment: .trailing)
                .padding(.horizontal, DesignTokens.spaceM)
                .padding(.vertical, DesignTokens.spaceS)
                .background(DesignTokens.secondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusS))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("\(title)：\(selection.label)")
        }
        .frame(minHeight: 44)
    }
}

struct LanguageRouteSummary: View {
    let nativeLanguage: TranslationLanguage
    let secondaryLanguage: TranslationLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spaceS) {
            route(sourceLabel: nativeLanguage.label, target: secondaryLanguage, emphasis: true)
            route(sourceLabel: secondaryLanguage.label, target: nativeLanguage, emphasis: false)
            route(sourceLabel: "其它语言 / 未知", target: nativeLanguage, emphasis: false)
        }
    }

    private func route(
        sourceLabel: String,
        target: TranslationLanguage,
        emphasis: Bool
    ) -> some View {
        HStack(spacing: DesignTokens.spaceS) {
            Text(sourceLabel)
                .frame(width: 120, alignment: .trailing)
            Image(systemName: "arrow.right")
                .foregroundStyle(DesignTokens.accent)
            Text(target.label)
                .frame(width: 92, alignment: .leading)
            if emphasis {
                Text("原文是母语")
                    .font(AppFont.micro)
                    .foregroundStyle(DesignTokens.secondaryText)
            }
        }
        .font(AppFont.body)
        .accessibilityElement(children: .combine)
    }
}

struct APIProfileSummaryRow: View {
    let profile: TranslationAPIProfile
    let isDefault: Bool
    let onEnabledChange: (Bool) -> Void
    let onOpen: () -> Void
    let onSetDefault: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDrop: (UUID) -> Bool
    let onDelete: () -> Void
    let canMoveUp: Bool
    let canMoveDown: Bool
    @Binding var draggingProfileID: UUID?

    private var isDragging: Bool {
        draggingProfileID == profile.id
    }

    var body: some View {
        HStack(spacing: DesignTokens.spaceM) {
                Toggle(
                    "启用配置",
                    isOn: Binding(
                        get: { profile.isEnabled },
                        set: { isEnabled in onEnabledChange(isEnabled) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .help(profile.isEnabled ? "停用配置" : "启用配置")
                .accessibilityLabel("启用配置")

                Button(action: onOpen) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: DesignTokens.spaceS) {
                            Text(profile.name.isEmpty ? "未命名配置" : profile.name)
                                .font(AppFont.bodyEmphasis)
                            if isDefault {
                                Text("默认")
                                    .font(AppFont.micro)
                                    .foregroundStyle(DesignTokens.accent)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(DesignTokens.accent.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(profile.modelName.isEmpty ? "尚未配置模型" : profile.modelName)
                            .font(AppFont.micro)
                            .foregroundStyle(DesignTokens.secondaryText)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer(minLength: DesignTokens.spaceM)
                Label(profile.isConfigured ? "配置完整" : "需要完善", systemImage: profile.isConfigured ? "checkmark.shield" : "exclamationmark.triangle")
                    .font(AppFont.micro)
                    .foregroundStyle(profile.isConfigured ? DesignTokens.success : DesignTokens.warning)
                Menu {
                    Button("设为默认", action: onSetDefault).disabled(isDefault)
                    Divider()
                    Button("删除配置", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17))
                }
                .menuStyle(.borderlessButton)

                ZStack {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(DesignTokens.tertiaryText)

                    APIProfileDragSource(
                        profile: profile,
                        isDefault: isDefault,
                        draggingProfileID: $draggingProfileID
                    )
                }
                .frame(
                    width: APIProfileDragGeometry.handleSize.width,
                    height: APIProfileDragGeometry.handleSize.height
                )
                .contentShape(Rectangle())
                .help("拖动以排序")
                .accessibilityLabel("拖动以排序 \(profile.name)")
                .accessibilityAction(named: "上移") {
                    if canMoveUp { onMoveUp() }
                }
                .accessibilityAction(named: "下移") {
                    if canMoveDown { onMoveDown() }
                }
        }
        .opacity(isDragging ? 0 : 1)
        .allowsHitTesting(!isDragging)
        .padding(.vertical, DesignTokens.spaceM)
        .animation(.easeOut(duration: 0.12), value: isDragging)
        .onDrop(
            of: [UTType.plainText.identifier],
            delegate: APIProfileDropDelegate(
                targetProfileID: profile.id,
                draggingProfileID: $draggingProfileID,
                onMove: onDrop
            )
        )
    }
}

enum APIProfileDragGeometry {
    static let rowSize = CGSize(width: 580, height: 76)
    static let handleSize = CGSize(width: 32, height: 44)
    static let systemDraggingImageSize = CGSize(width: 1, height: 1)
    static let previewHorizontalPadding: CGFloat = DesignTokens.spaceM
    static let previewVerticalPadding: CGFloat = DesignTokens.spaceM

    static var previewSize: CGSize {
        rowSize
    }

    static var handleOriginInPreview: CGPoint {
        CGPoint(
            x: rowSize.width - previewHorizontalPadding - handleSize.width,
            y: previewVerticalPadding
        )
    }

    static func previewFrame(
        pointerLocation: CGPoint,
        handleLocation: CGPoint
    ) -> CGRect {
        let anchor = CGPoint(
            x: handleOriginInPreview.x + handleLocation.x,
            y: handleOriginInPreview.y + handleLocation.y
        )
        return CGRect(
            x: pointerLocation.x - anchor.x,
            y: pointerLocation.y - anchor.y,
            width: previewSize.width,
            height: previewSize.height
        )
    }
}

private struct APIProfileDragSource: NSViewRepresentable {
    let profile: TranslationAPIProfile
    let isDefault: Bool
    @Binding var draggingProfileID: UUID?

    func makeNSView(context: Context) -> APIProfileDragSourceView {
        let view = APIProfileDragSourceView()
        view.setAccessibilityElement(false)
        return view
    }

    func updateNSView(_ nsView: APIProfileDragSourceView, context: Context) {
        nsView.profile = profile
        nsView.isDefault = isDefault
        nsView.onDragStarted = {
            withAnimation(.easeOut(duration: 0.12)) {
                draggingProfileID = profile.id
            }
        }
        nsView.onDragEnded = {
            withAnimation(.easeOut(duration: 0.14)) {
                draggingProfileID = nil
            }
        }
    }
}

@MainActor
private final class APIProfileDragSourceView: NSView, NSDraggingSource {
    var profile: TranslationAPIProfile?
    var isDefault = false
    var onDragStarted: (() -> Void)?
    var onDragEnded: (() -> Void)?

    private var mouseDownEvent: NSEvent?
    private var mouseDownLocation = CGPoint.zero
    private var startedDragging = false
    private var dragPreviewPanel: NSPanel?

    override var acceptsFirstResponder: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        mouseDownLocation = convert(event.locationInWindow, from: nil)
        startedDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !startedDragging,
              mouseDownEvent != nil,
              let profile else { return }

        let pointerLocation = convert(event.locationInWindow, from: nil)

        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(profile.id.uuidString, forType: .string)
        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        let systemImageSize = APIProfileDragGeometry.systemDraggingImageSize
        draggingItem.setDraggingFrame(
            CGRect(
                x: pointerLocation.x - (systemImageSize.width / 2),
                y: pointerLocation.y - (systemImageSize.height / 2),
                width: systemImageSize.width,
                height: systemImageSize.height
            ),
            contents: transparentDraggingImage
        )

        dragPreviewPanel = makeDragPreviewPanel(profile: profile)
        onDragStarted?()
        startedDragging = true
        let session = beginDraggingSession(
            with: [draggingItem],
            event: event,
            source: self
        )
        session.draggingFormation = .none
        session.draggingLeaderIndex = 0
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownEvent = nil
        startedDragging = false
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .withinApplication ? .move : []
    }

    func draggingSession(
        _ session: NSDraggingSession,
        willBeginAt screenPoint: NSPoint
    ) {
        showDragPreview(at: screenPoint)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        movedTo screenPoint: NSPoint
    ) {
        moveDragPreview(to: screenPoint)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        mouseDownEvent = nil
        startedDragging = false
        hideDragPreview()
        onDragEnded?()
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        true
    }

    private var transparentDraggingImage: NSImage {
        NSImage(size: APIProfileDragGeometry.systemDraggingImageSize, flipped: false) { rect in
            NSColor.clear.setFill()
            rect.fill()
            return true
        }
    }

    private func makeDragPreviewPanel(profile: TranslationAPIProfile) -> NSPanel {
        let colorScheme: ColorScheme = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? .dark
            : .light

        let hostingView = NSHostingView(
            rootView: APIProfileDragPreview(profile: profile, isDefault: isDefault)
                .environment(\.colorScheme, colorScheme)
        )
        hostingView.frame = CGRect(origin: .zero, size: APIProfileDragGeometry.previewSize)
        hostingView.autoresizingMask = [.width, .height]

        let panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: APIProfileDragGeometry.previewSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.transient, .ignoresCycle]
        return panel
    }

    private func showDragPreview(at screenPoint: NSPoint) {
        guard let dragPreviewPanel else { return }
        moveDragPreview(to: screenPoint)
        if let window {
            window.addChildWindow(dragPreviewPanel, ordered: .above)
        }
        dragPreviewPanel.orderFront(nil)
    }

    private func moveDragPreview(to screenPoint: NSPoint) {
        dragPreviewPanel?.setFrame(
            APIProfileDragGeometry.previewFrame(
                pointerLocation: screenPoint,
                handleLocation: mouseDownLocation
            ),
            display: true
        )
    }

    private func hideDragPreview() {
        guard let dragPreviewPanel else { return }
        dragPreviewPanel.parent?.removeChildWindow(dragPreviewPanel)
        dragPreviewPanel.orderOut(nil)
        self.dragPreviewPanel = nil
    }
}

private struct APIProfileDragPreview: View {
    let profile: TranslationAPIProfile
    let isDefault: Bool

    var body: some View {
        HStack(spacing: DesignTokens.spaceM) {
            Toggle("启用配置", isOn: .constant(profile.isEnabled))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: DesignTokens.spaceXS) {
                HStack(spacing: DesignTokens.spaceS) {
                    Text(profile.name.isEmpty ? "未命名配置" : profile.name)
                        .font(AppFont.bodyEmphasis)
                    if isDefault {
                        Text("默认")
                            .font(AppFont.micro)
                            .foregroundStyle(DesignTokens.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(DesignTokens.accent.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Text(profile.modelName.isEmpty ? "尚未配置模型" : profile.modelName)
                    .font(AppFont.micro)
                    .foregroundStyle(DesignTokens.secondaryText)
            }

            Spacer(minLength: DesignTokens.spaceM)

            Label(
                profile.isConfigured ? "配置完整" : "需要完善",
                systemImage: profile.isConfigured ? "checkmark.shield" : "exclamationmark.triangle"
            )
            .font(AppFont.micro)
            .foregroundStyle(profile.isConfigured ? DesignTokens.success : DesignTokens.warning)

            Image(systemName: "ellipsis.circle")
                .font(.system(size: 17))
                .foregroundStyle(DesignTokens.secondaryText)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(DesignTokens.tertiaryText)
                .frame(width: 32, height: 44)
        }
        .padding(.horizontal, APIProfileDragGeometry.previewHorizontalPadding)
        .padding(.vertical, APIProfileDragGeometry.previewVerticalPadding)
        .frame(
            width: APIProfileDragGeometry.rowSize.width,
            height: APIProfileDragGeometry.rowSize.height,
            alignment: .leading
        )
        .background(DesignTokens.surface.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusM, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.radiusM, style: .continuous)
                .stroke(DesignTokens.divider.opacity(0.65), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
        .frame(
            width: APIProfileDragGeometry.previewSize.width,
            height: APIProfileDragGeometry.previewSize.height
        )
    }
}

private struct APIProfileDropDelegate: DropDelegate {
    let targetProfileID: UUID
    @Binding var draggingProfileID: UUID?
    let onMove: (UUID) -> Bool

    func validateDrop(info: DropInfo) -> Bool {
        draggingProfileID != nil
    }

    func dropEntered(info: DropInfo) {
        guard let draggingProfileID,
              draggingProfileID != targetProfileID else { return }
        withAnimation(.snappy(duration: 0.22)) {
            _ = onMove(draggingProfileID)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        return true
    }
}

