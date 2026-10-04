#if os(macOS)
import AppKit
import ConnectCore
import ConnectUI
import SwiftUI

@main
struct PreviewMain {
    @MainActor static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let directory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "docs/images", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        func render<V: View>(_ view: V, name: String, width: CGFloat, height: CGFloat, scale: CGFloat = 2) throws {
            // ScrollView is backed by a platform view; ImageRenderer alone omits
            // it. Host the actual hierarchy and capture after layout instead.
            let host = NSHostingView(rootView: view.frame(width: width, height: height)
                .environment(\.colorScheme, .dark))
            let window = NSWindow(contentRect: NSRect(x: -2000, y: 0, width: width, height: height),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = host
            window.orderBack(nil)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date.now.addingTimeInterval(0.3))
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds)
            else { throw CocoaError(.fileWriteUnknown) }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            guard let source = bitmap.cgImage,
                  let context = CGContext(data: nil, width: Int(width * scale), height: Int(height * scale),
                                          bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
            else { throw CocoaError(.fileWriteUnknown) }
            context.draw(source, in: CGRect(x: 0, y: 0, width: width * scale, height: height * scale))
            guard let result = context.makeImage(),
                  let data = NSBitmapImageRep(cgImage: result).representation(using: .png, properties: [:])
            else { throw CocoaError(.fileWriteUnknown) }
            try data.write(to: directory.appendingPathComponent(name))
            window.orderOut(nil)
            print("Rendered \(name)")
        }
        let setup = GameStore(restore: false)
        try render(AppSnapshot(store: setup, playing: false), name: "setup.png", width: 390, height: 844)
        let now = Date.now.timeIntervalSince1970
        var session = Session(boardCount: 4, turnDuration: 12, mode: .local, now: now - 8)
        var rng = SystemRandomNumberGenerator()
        let columns = [[3, 2, 3, 4, 2, 4], [2, 3, 2, 4, 4], [3, 4, 2, 4, 3, 5, 3], [4, 3, 5, 4]]
        for step in 0..<7 {
            for board in 0..<4 where step < columns[board].count {
                _ = session.drop(column: columns[board][step], boardID: board,
                                 at: now - 7 + Double(step) * 0.8 + Double(board) * 0.1, using: &rng)
            }
        }
        let game = GameStore(preview: session)
        try render(AppSnapshot(store: game, playing: true), name: "four-boards.png", width: 390, height: 844)
        try render(AppSnapshot(store: game, playing: true), name: "tablet.png", width: 820, height: 1180)
        try render(AppSnapshot(store: game, playing: true), name: "landscape.png", width: 844, height: 390)
        try render(AppIconView(), name: "app-icon.png", width: 1024, height: 1024, scale: 1)
    }
}
#else
import Foundation
@main struct PreviewMain { static func main() { print("Render previews on macOS.") } }
#endif
