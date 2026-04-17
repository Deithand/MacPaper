import Foundation

/// Rotates through Library items on a timer.
final class Playlist {
    static let shared = Playlist()

    var onAdvance: ((URL) -> Void)?
    private var timer: Timer?
    private var order: [URL] = []
    private var index: Int = 0

    func start() {
        stop()
        guard Preferences.shared.playlistEnabled else { return }
        rebuildOrder()
        guard !order.isEmpty else { return }
        let interval = max(10, TimeInterval(Preferences.shared.playlistIntervalSec))
        let t = Timer(timeInterval: interval, target: self, selector: #selector(tick),
                      userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate(); timer = nil
    }

    func next() {
        rebuildOrder()
        guard !order.isEmpty else { return }
        index = (index + 1) % order.count
        onAdvance?(order[index])
    }

    private func rebuildOrder() {
        let items = Library.shared.items()
        if Preferences.shared.playlistShuffle {
            order = items.shuffled()
        } else {
            order = items
        }
        if index >= order.count { index = 0 }
    }

    @objc private func tick() { next() }
}
