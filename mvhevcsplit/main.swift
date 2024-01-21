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
    
    guard arguments.count > 1 else {
        print("Usage: \(arguments[0]) <MV-HEVC file>")
        return
    }
    
    VTRegisterProfessionalVideoWorkflowVideoDecoders()
    
    let path = arguments[1]
    printFileSize(filePath: path)
    print("starting first eye")
    Converter().transcodeMovie(filePath: path, firstEye: true)
    print("starting second eye")
    Converter().transcodeMovie(filePath: path, firstEye: false)
}

main()
