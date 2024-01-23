//
//  main.swift
//  SpatialMediaKit
//
//  Created by Nicholas Tinsley on 1/21/24.
//

import AVFoundation
import ArgumentParser
import Foundation
import SpatialMediaKit
import VideoToolbox

@main
@available(macOS 14, *)
struct SpatialMediaKitTool: ParsableCommand {

  static var configuration = CommandConfiguration(
    abstract: "A utility for transforming spatial media.",
    version: "0.0.3-alpha",
    subcommands: [Split.self],
    defaultSubcommand: Split.self)
}

extension SpatialMediaKitTool {
  struct Split: ParsableCommand {
    static var configuration =
      CommandConfiguration(
        abstract: "Split a single MV-HEVC input into left and right video files.")

    @Option(name: .shortAndLong, help: "The spatial media file to split.")
    var inputFile: String

    @Option(
      name: .shortAndLong,
      help:
        "The output directory for the resulting files. If not provided, the current directory will be used."
    )
    var outputDir: String?

    func run() {
      guard VTIsStereoMVHEVCDecodeSupported() else {
        print(
          "MV-HEVC decoding not supported on this device! Please try again on Apple Silicon and macOS 14+"
        )
        return
      }
      SpatialVideoSplitter().transcodeMovie(filePath: inputFile, outputDir: outputDir)
    }

  }
}
