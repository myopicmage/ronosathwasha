// Shape text with CoreText and report glyph ids and absolute positions.
//
// Exists so the test suite can ask Apple's shaper the same question it asks
// HarfBuzz. Everything else in this repo is verified against HarfBuzz, which
// is not the engine that runs when you type on this machine.
//
// Usage: swift coretext_shape.swift <font.ttf> <text-file>
// One input line in, one output line out, matching hb-shape's batch shape.
// Each line is "glyphid:x:y|glyphid:x:y|..." in font units.

import CoreText
import Foundation

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("usage: coretext_shape <font.ttf> <text-file>\n".data(using: .utf8)!)
    exit(2)
}

let url = URL(fileURLWithPath: args[1]) as CFURL
guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url) as? [CTFontDescriptor],
      let descriptor = descriptors.first else {
    FileHandle.standardError.write("could not read font at \(args[1])\n".data(using: .utf8)!)
    exit(1)
}

// Point size equal to units-per-em, so reported positions are font units and
// nothing has to be scaled back on the Python side.
let font = CTFontCreateWithFontDescriptor(descriptor, 1000, nil)
let key = kCTFontAttributeName as NSAttributedString.Key  // `.font` is AppKit

let contents = try String(contentsOf: URL(fileURLWithPath: args[2]), encoding: .utf8)
for line in contents.split(separator: "\n", omittingEmptySubsequences: false).dropLast() {
    let attributed = NSAttributedString(string: String(line), attributes: [key: font])
    let ctLine = CTLineCreateWithAttributedString(attributed)

    var placed: [String] = []
    for run in CTLineGetGlyphRuns(ctLine) as! [CTRun] {
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRangeMake(0, count), &glyphs)
        CTRunGetPositions(run, CFRangeMake(0, count), &positions)

        for i in 0..<count {
            placed.append("\(glyphs[i]):\(Int(positions[i].x.rounded())):\(Int(positions[i].y.rounded()))")
        }
    }
    print(placed.joined(separator: "|"))
}
