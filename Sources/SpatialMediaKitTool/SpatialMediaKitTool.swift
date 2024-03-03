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
    version: "0.0.5-alpha",
    subcommands: [Split.self, Merge.self],
    defaultSubcommand: Split.self)
}

extension SpatialMediaKitTool {
  struct Split: ParsableCommand {
    static var configuration =
      CommandConfiguration(
        abstract: "Split a single MV-HEVC input into left and right video files.")

    @Flag(help: "Pause execution at start to allow for time to attach a debugger.") var debug =
      false

    @Option(name: .shortAndLong, help: "The spatial media file to split.")
    var inputFile: String

    @Option(
      name: .shortAndLong,
      help:
        "The output directory for the resulting files. If not provided, the current directory will be used."
    )
    var outputDir: String?

    func run() {
      if debug {
        print("Pausing to allow attaching a debugger. Press Enter to continue...")
        let _ = readLine()
      }

      guard VTIsStereoMVHEVCDecodeSupported() else {
        print(
          "MV-HEVC decoding not supported on this device! Please try again on Apple Silicon and macOS 14+"
        )
        return
      }
      SpatialVideoSplitter().transcodeMovie(filePath: inputFile, outputDir: outputDir)
    }
  }

  struct Merge: ParsableCommand {
    static var configuration =
      CommandConfiguration(
        abstract: "Merge two video files into a single MV-HEVC file.")

    @Flag(help: "Optional. Pause execution at start to allow for time to attach a debugger.")
    var debug =
      false

    @Option(name: .shortAndLong, help: "The left eye media file to merge.")
    var leftFile: String

    @Option(name: .shortAndLong, help: "The right eye media file to merge.")
    var rightFile: String

    @Option(name: .shortAndLong, help: "Output video quality [0-100]. 50 is a good default value.")
    var quality: Int

    @Flag(help: "Set the left file as the \"hero\" stream that is displayed when viewing in 2D.")
    var leftIsPrimary: Bool = false
    @Flag(help: "Set the right file as the \"hero\" stream that is displayed when viewing in 2D.")
    var rightIsPrimary: Bool = false

    @Option(
      name: .long,
      help:
        "The field of view of the output video, in degrees. Output will be rounded to the nearest thousandth of a degree. 65.200 is a good default value."
    )
    var horizontalFieldOfView: Float

    @Option(
      name: .long,
      help:
        "Optional. The horizontal disparity adjustment. The value is a 32-bit integer, measured over the range of -10000 to 10000. Only specify a disparity adjustment, including 0, when you know the specific value."
    )
    var horizontalDisparityAdjustment: Int?

    @Option(
      name: .shortAndLong,
      help:
        "The output file to write to. Expects a .MOV extension."
    )
    var outputFile: String

    func run() {
      if debug {
        print("Pausing to allow attaching a debugger. Press Enter to continue...")
        let _ = readLine()
      }

      guard VTIsStereoMVHEVCEncodeSupported() else {
        print(
          "MV-HEVC encoding not supported on this device! Please try again on Apple Silicon and macOS 14+"
        )
        return
      }

      if leftIsPrimary == rightIsPrimary {
        print("You must select one and only one eye as the primary, or \"hero\", eye.")
        return
      }

      if quality < 0 || quality > 100 {
        print("invalid quality value provided")
        return
      }

      let qualityFloat = Float(quality) / 100.0

      SpatialVideoMerger().transcodeMovie(
        leftFilePath: leftFile,
        rightFilePath: rightFile,
        outputFilePath: outputFile,
        quality: qualityFloat,
        horizontalFieldOfView: Int(horizontalFieldOfView * 1000),
        horizontalDisparityAdjustment: horizontalDisparityAdjustment,
        leftIsPrimary: leftIsPrimary)
    }
  }
}
