//
//  main.swift
//  mvhevcsplit
//
//  Created by Nicholas Tinsley on 1/21/24.
//

import Foundation
import AVFoundation
import VideoToolbox

// A function to print the file size for a given file path
func printFileSize(filePath: String) {
    let fileManager = FileManager.default
    do {
        let attributes = try fileManager.attributesOfItem(atPath: filePath)
        if let fileSize = attributes[.size] as? NSNumber {
            print("File: \(filePath), Size: \(fileSize) bytes")
        } else {
            print("Failed to retrieve size for \(filePath)")
        }
    } catch {
        print("Error: \(error.localizedDescription)")
    }
}

func main() {
    
    guard VTIsStereoMVHEVCDecodeSupported() else {
        print("MV-HEVC decoding not supported on this device! Please try again on Apple Silicon and macOS 14+")
        return
    }
    
    let arguments = CommandLine.arguments
    
    guard arguments.count == 4 else {
        print("Usage: \(arguments[0]) <output width> <output height> <MV-HEVC file>")
        return
    }
    
    VTRegisterProfessionalVideoWorkflowVideoDecoders()
    
    guard let width = Int(arguments[1]) else {
        print("parameter 1 is not a valid integer")
        return
    }
    guard let height = Int(arguments[2]) else {
        print("parameter 2 is not a valid integer")
        return
    }
    let path = arguments[3]
    printFileSize(filePath: path)
    print("starting first eye")
    Converter(height: height, width: width).transcodeMovie(filePath: path, firstEye: true)
    print("starting second eye")
    Converter(height: height, width: width).transcodeMovie(filePath: path, firstEye: false)
}

main()
