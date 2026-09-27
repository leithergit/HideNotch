import Foundation
import HideNotchCore

/// One entry of the standard 10-file .iconset layout `iconutil` expects.
private struct IconSpec {
    let filename: String
    let pixels: Int
}

private let specs: [IconSpec] = [
    IconSpec(filename: "icon_16x16.png", pixels: 16),
    IconSpec(filename: "icon_16x16@2x.png", pixels: 32),
    IconSpec(filename: "icon_32x32.png", pixels: 32),
    IconSpec(filename: "icon_32x32@2x.png", pixels: 64),
    IconSpec(filename: "icon_128x128.png", pixels: 128),
    IconSpec(filename: "icon_128x128@2x.png", pixels: 256),
    IconSpec(filename: "icon_256x256.png", pixels: 256),
    IconSpec(filename: "icon_256x256@2x.png", pixels: 512),
    IconSpec(filename: "icon_512x512.png", pixels: 512),
    IconSpec(filename: "icon_512x512@2x.png", pixels: 1024),
]

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("IconGen: \(message)\n".utf8))
    exit(1)
}

guard CommandLine.arguments.count == 2 else {
    fail("usage: IconGen <output.iconset dir>")
}

let outputDir = URL(fileURLWithPath: CommandLine.arguments[1])

do {
    try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
} catch {
    fail("could not create \(outputDir.path): \(error.localizedDescription)")
}

for spec in specs {
    let data = NotchIcon.appIconPNG(pixels: spec.pixels)
    let url = outputDir.appendingPathComponent(spec.filename)
    do {
        try data.write(to: url)
    } catch {
        fail("could not write \(url.path): \(error.localizedDescription)")
    }
}

print("IconGen: wrote \(specs.count) files to \(outputDir.path)")
