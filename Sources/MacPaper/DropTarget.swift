import AppKit
import UniformTypeIdentifiers

/// Overlay view placed on top of the status-bar button to accept file drops
/// while still passing clicks through to the button.
final class DropTargetView: NSView {
    var onDrop: (([URL]) -> Void)?
    weak var button: NSButton?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent)  { button?.performClick(nil) }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return isAcceptable(sender) ? .copy : []
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isAcceptable(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let items = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                                                options: nil) as? [URL],
              !items.isEmpty else { return false }
        let videoExts: Set<String> = ["mp4", "mov", "m4v", "mkv", "avi", "webm", "mpg", "mpeg"]
        let filtered = items.filter { videoExts.contains($0.pathExtension.lowercased()) }
        guard !filtered.isEmpty else { return false }
        onDrop?(filtered)
        return true
    }

    private func isAcceptable(_ sender: NSDraggingInfo) -> Bool {
        guard let items = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                                                options: nil) as? [URL] else { return false }
        let videoExts: Set<String> = ["mp4", "mov", "m4v", "mkv", "avi", "webm", "mpg", "mpeg"]
        return items.contains { videoExts.contains($0.pathExtension.lowercased()) }
    }

}
