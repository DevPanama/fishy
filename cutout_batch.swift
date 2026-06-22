import Foundation
import Vision
import CoreImage
import AppKit

let args = CommandLine.arguments
guard args.count >= 3 else { print("usage: cutout_batch inDir outDir"); exit(1) }
let inDir = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args[2])
let fm = FileManager.default
try? fm.createDirectory(at: outDir, withIntermediateDirectories: true)

let files = ((try? fm.contentsOfDirectory(at: inDir, includingPropertiesForKeys: nil)) ?? [])
    .filter { $0.pathExtension.lowercased() == "png" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

let ctx = CIContext()
var done = 0
for f in files {
    guard let ci = CIImage(contentsOf: f) else { continue }
    let req = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(ciImage: ci, options: [:])
    let outURL = outDir.appendingPathComponent(f.lastPathComponent)
    do {
        try handler.perform([req])
        var outImage = ci
        if let res = req.results?.first {
            let buf = try res.generateMaskedImage(ofInstances: res.allInstances,
                                                  from: handler,
                                                  croppedToInstancesExtent: false)   // keep full frame -> aligned
            outImage = CIImage(cvPixelBuffer: buf)
        }
        if let cg = ctx.createCGImage(outImage, from: ci.extent) {
            let rep = NSBitmapImageRep(cgImage: cg)
            if let png = rep.representation(using: .png, properties: [:]) {
                try png.write(to: outURL); done += 1
            }
        }
    } catch {
        FileHandle.standardError.write("err \(f.lastPathComponent): \(error)\n".data(using:.utf8)!)
    }
}
print("done \(done)/\(files.count)")
