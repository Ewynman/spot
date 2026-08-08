import SwiftUI
import UIKit

struct SpotPhotoEditorView: View {
    enum Tool: String, CaseIterable, Identifiable {
        case crop = "Crop"
        case rotate = "Rotate"
        case adjust = "Adjust"
        var id: Self { self }
    }

    private struct CropOption: Identifiable {
        let title: String
        let ratio: CGFloat?
        var id: String { title }
    }

    let photo: PostComposerPhoto
    let onSave: (PostComposerPhotoEdits) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var edits: PostComposerPhotoEdits
    @State private var preview: UIImage
    @State private var selectedTool: Tool = .crop
    @State private var renderTask: Task<Void, Never>?
    @State private var renderRevision = 0
    @State private var showResetConfirmation = false
    @State private var cropGestureStart: PostComposerPhotoCrop?
    @State private var canvasSize: CGSize = CGSize(width: 400, height: 400)

    private let cropOptions = [
        CropOption(title: "Free", ratio: nil),
        CropOption(title: "Original", ratio: 0),
        CropOption(title: "1:1", ratio: 1),
        CropOption(title: "4:5", ratio: 4 / 5),
        CropOption(title: "5:4", ratio: 5 / 4),
        CropOption(title: "3:4", ratio: 3 / 4),
        CropOption(title: "4:3", ratio: 4 / 3),
        CropOption(title: "16:9", ratio: 16 / 9),
        CropOption(title: "9:16", ratio: 9 / 16)
    ]

    init(photo: PostComposerPhoto, onSave: @escaping (PostComposerPhotoEdits) -> Void) {
        self.photo = photo
        self.onSave = onSave
        _edits = State(initialValue: photo.edits)
        _preview = State(initialValue: photo.image)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    Color.black.opacity(0.92)
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFit()
                        .overlay {
                            if selectedTool == .crop ||
                                (selectedTool == .rotate && abs(edits.straightenDegrees) > 0.01) {
                                PhotoEditorGrid()
                                    .allowsHitTesting(false)
                            }
                        }
                        .padding(12)
                        .background {
                            GeometryReader { proxy in
                                Color.clear
                                    .onAppear { canvasSize = proxy.size }
                                    .onChange(of: proxy.size) { _, size in canvasSize = size }
                            }
                        }
                        .gesture(cropGesture)
                        .accessibilityLabel("Photo editing preview")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        ForEach(Tool.allCases) { tool in
                            Button {
                                selectedTool = tool
                            } label: {
                                Label(tool.rawValue, systemImage: icon(for: tool))
                                    .font(FontManager.primaryText())
                                    .foregroundColor(
                                        selectedTool == tool
                                            ? Constants.Colors.buttonText
                                            : Constants.Colors.primary
                                    )
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        selectedTool == tool
                                            ? Constants.Colors.primary
                                            : Constants.Colors.accent
                                    )
                                    .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .accessibilityElement(children: .contain)

                    toolControls
                        .frame(minHeight: 108, alignment: .top)
                }
                .padding(16)
                .background(Constants.Colors.background)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        AnalyticsService.shared.logEvent("spot_photo_edit_cancelled", parameters: [:])
                        dismiss()
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .principal) {
                    Text("Edit Photo")
                        .font(FontManager.sectionHeader())
                        .foregroundStyle(Constants.Colors.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        var normalized = edits
                        normalized.normalize()
                        onSave(normalized)
                        AnalyticsService.shared.logEvent("spot_photo_edit_saved", parameters: [
                            "hasCrop": normalized.crop != .fullImage,
                            "hasOrientation": normalized.rotationQuarterTurns != 0 ||
                                normalized.straightenDegrees != 0 ||
                                normalized.flipHorizontal ||
                                normalized.flipVertical,
                            "hasAdjustments": !normalized.adjustments.isNeutral
                        ])
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .buttonStyle(.plain)
                }
            }
            .tint(Constants.Colors.primary)
            .safeAreaInset(edge: .bottom) {
                Button("Reset") {
                    if edits.isNeutral {
                        edits = .neutral
                        schedulePreviewRender()
                    } else {
                        showResetConfirmation = true
                    }
                }
                .font(FontManager.primaryText())
                .foregroundStyle(Constants.Colors.primary)
                .frame(minHeight: 44)
                .accessibilityLabel("Reset photo edits")
                .padding(.bottom, 4)
                .buttonStyle(.plain)
            }
            .alert("Reset all edits to this photo?", isPresented: $showResetConfirmation) {
                Button("Keep Editing", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    edits = .neutral
                    schedulePreviewRender()
                }
            }
            .onDisappear { renderTask?.cancel() }
        }
    }

    @ViewBuilder
    private var toolControls: some View {
        switch selectedTool {
        case .crop:
            Text("Drag to reposition • Pinch to zoom")
                .font(.caption)
                .foregroundStyle(Constants.Colors.primary.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(cropOptions) { option in
                        Button {
                            applyCrop(option)
                        } label: {
                            Text(option.title)
                                .font(FontManager.primaryText())
                                .foregroundColor(
                                    edits.crop.aspectRatio == option.title
                                        ? Constants.Colors.buttonText
                                        : Constants.Colors.primary
                                )
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                                .background(
                                    edits.crop.aspectRatio == option.title
                                        ? Constants.Colors.primary
                                        : Constants.Colors.accent
                                )
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    editorIconButton("Move crop left", icon: "arrow.left") { adjustCrop(dx: -0.03) }
                    editorIconButton("Move crop right", icon: "arrow.right") { adjustCrop(dx: 0.03) }
                    editorIconButton("Move crop up", icon: "arrow.up") { adjustCrop(dy: -0.03) }
                    editorIconButton("Move crop down", icon: "arrow.down") { adjustCrop(dy: 0.03) }
                    editorIconButton("Zoom crop in", icon: "plus.magnifyingglass") { adjustCrop(scale: 0.9) }
                    editorIconButton("Zoom crop out", icon: "minus.magnifyingglass") { adjustCrop(scale: 1.1) }
                }
            }
        case .rotate:
            HStack(spacing: 12) {
                editorIconButton("Rotate photo counterclockwise", icon: "rotate.left") {
                    edits.rotationQuarterTurns -= 1
                    schedulePreviewRender()
                }
                editorIconButton("Rotate photo clockwise", icon: "rotate.right") {
                    edits.rotationQuarterTurns += 1
                    schedulePreviewRender()
                }
                editorIconButton("Flip photo horizontally", icon: "arrow.left.and.right.righttriangle.left.righttriangle.right") {
                    edits.flipHorizontal.toggle()
                    schedulePreviewRender()
                }
                editorIconButton("Flip photo vertically", icon: "arrow.up.and.down.righttriangle.up.righttriangle.down") {
                    edits.flipVertical.toggle()
                    schedulePreviewRender()
                }
            }
            labeledSlider(
                title: "Straighten",
                value: $edits.straightenDegrees,
                range: -15...15,
                valueText: "\(Int(edits.straightenDegrees.rounded()))°"
            )
        case .adjust:
            ScrollView {
                VStack(spacing: 12) {
                    labeledSlider(title: "Brightness", value: $edits.adjustments.brightness, range: -1...1)
                    labeledSlider(title: "Contrast", value: $edits.adjustments.contrast, range: -1...1)
                    labeledSlider(title: "Saturation", value: $edits.adjustments.saturation, range: -1...1)
                    labeledSlider(title: "Warmth", value: $edits.adjustments.warmth, range: -1...1)
                }
            }
        }
    }

    private func icon(for tool: Tool) -> String {
        switch tool {
        case .crop: "crop"
        case .rotate: "rotate.right"
        case .adjust: "slider.horizontal.3"
        }
    }

    private func editorIconButton(
        _ label: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: 46, height: 44)
                .background(Constants.Colors.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.CornerRadius.small))
        }
        .accessibilityLabel(label)
    }

    private func labeledSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        valueText: String? = nil
    ) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(valueText ?? String(format: "%.2f", value.wrappedValue))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                if abs(value.wrappedValue) > 0.001 {
                    Button {
                        value.wrappedValue = 0
                        schedulePreviewRender()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel("Reset \(title)")
                }
            }
            .font(.caption)
            Slider(
                value: Binding(
                    get: { value.wrappedValue },
                    set: {
                        value.wrappedValue = $0
                        schedulePreviewRender()
                    }
                ),
                in: range
            )
            .tint(Constants.Colors.primary)
            .accessibilityLabel(title)
        }
    }

    private func applyCrop(_ option: CropOption) {
        guard let ratio = option.ratio else {
            edits.crop.aspectRatio = option.title
            schedulePreviewRender()
            return
        }
        let sourceRatio = transformedSourceRatio
        let targetRatio = ratio == 0 ? sourceRatio : ratio
        if targetRatio > sourceRatio {
            let height = sourceRatio / targetRatio
            edits.crop = PostComposerPhotoCrop(
                normalizedX: 0,
                normalizedY: (1 - height) / 2,
                normalizedWidth: 1,
                normalizedHeight: height,
                aspectRatio: option.title
            )
        } else {
            let width = targetRatio / sourceRatio
            edits.crop = PostComposerPhotoCrop(
                normalizedX: (1 - width) / 2,
                normalizedY: 0,
                normalizedWidth: width,
                normalizedHeight: 1,
                aspectRatio: option.title
            )
        }
        schedulePreviewRender()
    }

    private var transformedSourceRatio: CGFloat {
        let width = photo.originalImage.size.width
        let height = photo.originalImage.size.height
        let radians = CGFloat(edits.rotationQuarterTurns) * (.pi / 2) +
            CGFloat(edits.straightenDegrees) * (.pi / 180)
        let transformedWidth = abs(width * cos(radians)) + abs(height * sin(radians))
        let transformedHeight = abs(width * sin(radians)) + abs(height * cos(radians))
        return transformedWidth / max(transformedHeight, 1)
    }

    private func adjustCrop(dx: CGFloat = 0, dy: CGFloat = 0, scale: CGFloat = 1) {
        let centerX = edits.crop.normalizedX + edits.crop.normalizedWidth / 2 + dx
        let centerY = edits.crop.normalizedY + edits.crop.normalizedHeight / 2 + dy
        edits.crop.normalizedWidth *= scale
        edits.crop.normalizedHeight *= scale
        edits.crop.normalizedX = centerX - edits.crop.normalizedWidth / 2
        edits.crop.normalizedY = centerY - edits.crop.normalizedHeight / 2
        edits.crop.aspectRatio = "Free"
        edits.normalize()
        schedulePreviewRender()
    }

    private var cropGesture: some Gesture {
        SimultaneousGesture(
            DragGesture()
                .onChanged { value in
                    guard selectedTool == .crop else { return }
                    let start = cropGestureStart ?? edits.crop
                    if cropGestureStart == nil { cropGestureStart = start }
                    edits.crop.normalizedX = start.normalizedX -
                        value.translation.width / max(1, canvasSize.width) * start.normalizedWidth
                    edits.crop.normalizedY = start.normalizedY -
                        value.translation.height / max(1, canvasSize.height) * start.normalizedHeight
                    edits.crop.aspectRatio = "Free"
                    edits.normalize()
                    schedulePreviewRender()
                }
                .onEnded { _ in cropGestureStart = nil },
            MagnificationGesture()
                .onChanged { scale in
                    guard selectedTool == .crop else { return }
                    let start = cropGestureStart ?? edits.crop
                    if cropGestureStart == nil { cropGestureStart = start }
                    let width = start.normalizedWidth / scale
                    let height = start.normalizedHeight / scale
                    let centerX = start.normalizedX + start.normalizedWidth / 2
                    let centerY = start.normalizedY + start.normalizedHeight / 2
                    edits.crop.normalizedWidth = width
                    edits.crop.normalizedHeight = height
                    edits.crop.normalizedX = centerX - width / 2
                    edits.crop.normalizedY = centerY - height / 2
                    edits.crop.aspectRatio = "Free"
                    edits.normalize()
                    schedulePreviewRender()
                }
                .onEnded { _ in cropGestureStart = nil }
        )
    }

    private func schedulePreviewRender() {
        renderTask?.cancel()
        renderRevision += 1
        let revision = renderRevision
        let original = photo.originalImage
        let editsSnapshot = edits
        renderTask = Task {
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            let rendered = await Task.detached(priority: .userInitiated) {
                try? PostPhotoProcessor.renderEditorPreview(original: original, edits: editsSnapshot)
            }.value
            guard !Task.isCancelled, revision == renderRevision, let rendered else { return }
            preview = rendered
        }
    }
}

private struct PhotoEditorGrid: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                for fraction in [CGFloat(1.0 / 3.0), CGFloat(2.0 / 3.0)] {
                    path.move(to: CGPoint(x: geometry.size.width * fraction, y: 0))
                    path.addLine(to: CGPoint(x: geometry.size.width * fraction, y: geometry.size.height))
                    path.move(to: CGPoint(x: 0, y: geometry.size.height * fraction))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height * fraction))
                }
                path.addRect(CGRect(origin: .zero, size: geometry.size))
            }
            .stroke(.white.opacity(0.75), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}
