import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.isOpaque = true
    self.backgroundColor = NSColor(
      calibratedRed: 1.0,
      green: 0.9725,
      blue: 0.9098,
      alpha: 1.0
    )

    if let screen = NSScreen.main {
      let screenRect = screen.visibleFrame
      let aspectRatio: CGFloat = 19.5 / 9.0
      let windowHeight = min(screenRect.height * 0.82, 900)
      let windowWidth = windowHeight / aspectRatio
      let originX = screenRect.midX - (windowWidth / 2)
      let originY = screenRect.midY - (windowHeight / 2)
      let frame = NSRect(x: originX, y: originY, width: windowWidth, height: windowHeight)
      self.setFrame(frame, display: true)
      self.minSize = NSSize(width: windowWidth, height: windowHeight)
      self.maxSize = NSSize(width: windowWidth, height: windowHeight)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
