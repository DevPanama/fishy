import Foundation
import Vision
import CoreImage
import AppKit

let args = CommandLine.arguments
guard args.count >= 3 else { FileHandle.standardError.write("usage: cutout input output\n".data(using:.utf8)!); exit(1) }
let inputURL = URL(fileURLWithPath: args[1])
let outputURL = URL(fileURLWithPath: args[2])

guard let ci = CIImage(contentsOf: inputURL) else { print("cannot load image"); exit(1) }

let request = VNGenerateForegroundInstanceMaskRequest()
let handler = VNImageRequestHandler(ciImage: ci, options: [:])
do {
    try handler.perform([request])
    guard let result = request.results?.first else { print("no foreground found"); exit(1) }
    let buffer = try result.generateMaskedImage(ofInstances: result.allInstances,
                                                 from: handler,
                                                 croppedToInstancesExtent: true)
    let out = CIImage(cvPixelBuffer: buffer)
    let ctx = CIContext()
    guard let cg = ctx.createCGImage(out, from: out.extent) else { print("cgimage failed"); exit(1) }
    let rep = NSBitmapImageRep(cgImage: cg)
    guard let png = rep.representation(using: .png, properties: [:]) else { print("png failed"); exit(1) }
    try png.write(to: outputURL)
    print("OK \(cg.width)x\(cg.height)")
} catch {
    print("error: \(error)"); exit(1)
}
