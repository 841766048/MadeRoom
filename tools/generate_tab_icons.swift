import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Authored curves, not pixel tracing. A single geometry source emits editable SVG and vector PDF.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let svgDirectory = root.deletingLastPathComponent().appendingPathComponent("design/tab-icons")
let catalog = root.appendingPathComponent("MadeRoom/Resources/TabIcons.xcassets")
let previewDirectory = root.appendingPathComponent("docs/tab-icons")
for url in [svgDirectory,catalog,previewDirectory] { try FileManager.default.createDirectory(at:url,withIntermediateDirectories:true) }
struct Shape {
    var path = CGMutablePath()
    var svg = ""
    var filled = false
    mutating func m(_ x:CGFloat,_ y:CGFloat) { path.move(to:.init(x:x,y:y));svg += "M\(x) \(y) " }
    mutating func l(_ x:CGFloat,_ y:CGFloat) { path.addLine(to:.init(x:x,y:y));svg += "L\(x) \(y) " }
    mutating func c(_ x1:CGFloat,_ y1:CGFloat,_ x2:CGFloat,_ y2:CGFloat,_ x:CGFloat,_ y:CGFloat) { path.addCurve(to:.init(x:x,y:y),control1:.init(x:x1,y:y1),control2:.init(x:x2,y:y2));svg += "C\(x1) \(y1) \(x2) \(y2) \(x) \(y) " }
    mutating func close() { path.closeSubpath();svg += "Z " }
}
func path(_ filled:Bool = false,_ draw:(inout Shape)->Void)->Shape { var s=Shape();s.filled=filled;draw(&s);return s }
func circle(_ x:CGFloat,_ y:CGFloat,_ r:CGFloat,_ filled:Bool)->Shape {
    let k:CGFloat=0.5522847498
    return path(filled) { p in
        p.m(x+r,y);p.c(x+r,y+r*k,x+r*k,y+r,x,y+r);p.c(x-r*k,y+r,x-r,y+r*k,x-r,y)
        p.c(x-r,y-r*k,x-r*k,y-r,x,y-r);p.c(x+r*k,y-r,x+r,y-r*k,x+r,y);p.close()
    }
}
func icon(_ name:String,_ selected:Bool)->[Shape] {
    switch name {
    case "discover": return [
        path { p in p.m(4.6,18.8);p.c(1.8,9.3,8.3,4.0,20.8,2.6);p.c(19.6,15.2,14.1,22.0,4.6,18.8);p.close() },
        path { p in p.m(2.8,21.2);p.c(8.1,15.6,13.1,10.6,18.0,5.3);p.m(9.0,14.9);p.l(8.8,9.7) }
    ]
    case "make": return [
        // Brush: tapered handle and a soft, pointed tuft.
        path(selected) { p in p.m(8.8,13.0);p.l(17.7,3.2);p.c(18.4,2.5,19.6,2.5,20.3,3.2);p.c(21.0,3.9,21.0,5.0,20.3,5.7);p.l(10.6,14.8);p.close() },
        path { p in p.m(8.8,13.0);p.c(6.5,11.9,4.6,13.0,4.4,15.3);p.c(4.3,17.4,3.1,18.6,2.8,18.8);p.c(6.2,20.1,10.1,18.7,10.6,14.8);p.close();p.m(11.3,10.4);p.l(13.2,12.3) },
        // Pencil crossing behind the brush, split at the crossing to remain legible at 24 pt.
        path { p in p.m(10.0,9.2);p.l(5.5,4.7);p.l(2.8,3.5);p.l(4.0,6.2);p.l(8.5,10.7);p.m(14.1,13.3);p.l(20.2,19.4);p.c(20.6,19.8,20.6,20.3,20.2,20.7);p.c(19.8,21.1,19.3,21.1,18.9,20.7);p.l(12.6,14.8) }
    ]
    case "spaces": return [
        path(selected) { p in p.m(2.8,10.3);p.l(12,2.8);p.l(21.2,10.3);p.l(19.1,10.3);p.l(19.1,21.0);p.l(14.6,21.0);p.l(14.6,14.2);p.l(9.4,14.2);p.l(9.4,21.0);p.l(4.9,21.0);p.l(4.9,10.3);p.close() }
    ]
    case "community": return [
        circle(12,6.6,2.7,selected),circle(5.2,8.0,2.1,selected),circle(18.8,8.0,2.1,selected),
        path(selected) { p in p.m(6.9,20.6);p.l(6.9,17.5);p.c(6.9,13.1,17.1,13.1,17.1,17.5);p.l(17.1,20.6);if selected {p.close()} },
        path(selected) { p in p.m(4.8,19.6);p.l(2.2,19.6);p.l(2.2,16.6);p.c(2.2,13.3,4.3,12.3,6.5,13.0);if selected {p.l(4.8,15.8);p.close()} },
        path(selected) { p in p.m(19.2,19.6);p.l(21.8,19.6);p.l(21.8,16.6);p.c(21.8,13.3,19.7,12.3,17.5,13.0);if selected {p.l(19.2,15.8);p.close()} }
    ]
    default: return [
        circle(12,6.6,3.5,selected),
        path(selected) { p in p.m(4.5,21);p.c(4.5,11.9,19.5,11.9,19.5,21);p.close() }
    ]
}
}
func draw(_ shapes:[Shape],_ context:CGContext,_ selected:Bool) {
    context.setStrokeColor(CGColor(gray:0,alpha:1));context.setFillColor(CGColor(gray:0,alpha:1))
    context.setLineWidth(selected ? 1.85 : 1.45);context.setLineCap(.round);context.setLineJoin(.round)
    for s in shapes {context.addPath(s.path);context.drawPath(using:s.filled ? .fillStroke : .stroke)}
}
let info:[String:Any] = ["info":["author":"xcode","version":1]]
try JSONSerialization.data(withJSONObject:info,options:.prettyPrinted).write(to:catalog.appendingPathComponent("Contents.json"))
for name in ["discover","make","spaces","community","profile"] {
    for selected in [false,true] {
        let key="tab-\(name)"+(selected ? "-selected" : "")
        let shapes=icon(name,selected)
        let paths=shapes.map { "<path d=\"\($0.svg)\" fill=\"\($0.filled ? "currentColor" : "none")\"/>" }.joined()
        let svg="<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"\(selected ? 1.85 : 1.45)\" stroke-linecap=\"round\" stroke-linejoin=\"round\">\(paths)</svg>"
        try svg.write(to:svgDirectory.appendingPathComponent(key+".svg"),atomically:true,encoding:.utf8)
        let imageset=catalog.appendingPathComponent(key+".imageset")
        try FileManager.default.createDirectory(at:imageset,withIntermediateDirectories:true)
        var box=CGRect(x:0,y:0,width:24,height:24)
        let pdf=CGContext(imageset.appendingPathComponent(key+".pdf") as CFURL,mediaBox:&box,nil)!
        pdf.beginPDFPage(nil);pdf.translateBy(x:0,y:24);pdf.scaleBy(x:1,y:-1);draw(shapes,pdf,selected);pdf.endPDFPage();pdf.closePDF()
        let meta:[String:Any] = ["images":[["filename":key+".pdf","idiom":"universal"]],"info":["author":"xcode","version":1],"properties":["preserves-vector-representation":true,"template-rendering-intent":"template"]]
        try JSONSerialization.data(withJSONObject:meta,options:[.prettyPrinted,.sortedKeys]).write(to:imageset.appendingPathComponent("Contents.json"))
        let bitmap=CGContext(data:nil,width:144,height:144,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        bitmap.translateBy(x:0,y:144);bitmap.scaleBy(x:6,y:-6);draw(shapes,bitmap,selected)
        let destination=CGImageDestinationCreateWithURL(previewDirectory.appendingPathComponent(key+".png") as CFURL,UTType.png.identifier as CFString,1,nil)!
        CGImageDestinationAddImage(destination,bitmap.makeImage()!,nil);CGImageDestinationFinalize(destination)
    }
}
print("Generated 10 editable SVGs and 10 template vector PDF image sets.")
