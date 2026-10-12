import UIKit

struct DesignRect: Decodable { let box: [CGFloat]; let radius: CGFloat; let color: [CGFloat] }
struct DesignVector: Decodable { let paths: [[[CGFloat]]]; let color: [CGFloat] }
struct DesignImage: Decodable { let name: String; let box: [CGFloat] }
struct DesignText: Decodable { let text: String; let box: [CGFloat]; let fontSize: CGFloat; let bold: Bool; let color: [CGFloat] }
struct DesignScreen: Decodable {
    let id: String, name: String
    let width: CGFloat, height: CGFloat, top: CGFloat, bottom: CGFloat
    let background: [CGFloat]
    let vectors: [DesignVector]
    let rectangles: [DesignRect]
    let images: [DesignImage]
    let texts: [DesignText]
}
final class DesignCatalog {
    let screens: [DesignScreen]
    init() throws {
        guard let url = Bundle.main.url(forResource: "screens", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        screens = try JSONDecoder().decode([DesignScreen].self, from: Data(contentsOf: url))
    }
    subscript(_ id: String) -> DesignScreen? { screens.first { $0.id == id } }
    static func image(_ name: String) -> UIImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Artwork") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
extension UIColor {
    convenience init(rgb: [CGFloat]) { self.init(red: rgb[0]/255, green: rgb[1]/255, blue: rgb[2]/255, alpha: 1) }
    static let roomGreen = UIColor(red: 0.25, green: 0.38, blue: 0.27, alpha: 1)
    static let roomCream = UIColor(red: 0.976, green: 0.973, blue: 0.961, alpha: 1)
}
extension CGRect {
    init(box: [CGFloat]) { self.init(x: box[0], y: box[1], width: box[2], height: box[3]) }
}
/// Native Core Graphics paths keep surface geometry resolution-independent.
/// Artwork is rendered separately; this view never draws text or a screen snapshot.
final class SurfaceView: UIView {
    let screen: DesignScreen
    init(screen: DesignScreen) { self.screen = screen; super.init(frame: .zero); isOpaque = true; backgroundColor = UIColor(rgb: screen.background) }
    required init?(coder: NSCoder) { fatalError("Use init(screen:)") }
    override func draw(_ rect: CGRect) {
        for vector in screen.vectors {
            UIColor(rgb: vector.color).setFill()
            let path = UIBezierPath(); path.usesEvenOddFillRule = true
            for points in vector.paths where !points.isEmpty {
                path.move(to: CGPoint(x: points[0][0], y: points[0][1]))
                for point in points.dropFirst() { path.addLine(to: CGPoint(x: point[0], y: point[1])) }
                path.close()
            }
            path.fill()
        }
        for item in screen.rectangles {
            UIColor(rgb: item.color).setFill()
            UIBezierPath(roundedRect: CGRect(box: item.box), cornerRadius: item.radius).fill()
        }
    }
}
