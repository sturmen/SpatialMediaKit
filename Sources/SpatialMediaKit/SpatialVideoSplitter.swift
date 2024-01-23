//
//  SpatialVideoSplitter.swift
//  SpatialMediaKit
//
//  Created by Nicholas Tinsley on 1/22/24.
//

import AVFoundation
import Foundation
import VideoToolbox

public class SpatialVideoSplitter {
  let decoderOutputSettings: [String: Any] = [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_422YpCbCr16,
    AVVideoDecompressionPropertiesKey: [
      kVTDecompressionPropertyKey_RequestedMVHEVCVideoLayerIDs: [0, 1] as CFArray
    ],
  ]

  var completedFrames = 0

  public init() {}

  func incrementFrameCountAndLog() {
    completedFrames += 1
    print("encoded \(completedFrames) frames")
  }

  func getCurrentFrameCount() -> Int {
    return completedFrames
  }

  func createOutputUrl(outputFilename: String, outputDir: String?) throws -> URL {
    let outputDir = outputDir ?? FileManager.default.currentDirectoryPath
    print("writing output files to \(outputDir)")
    let outputUrl = URL(fileURLWithPath: outputDir)
      .appendingPathComponent(outputFilename)
    if try !checkFileOverwrite(path: outputUrl.path()) {
      throw MediaError.createOutputError
    }
    return outputUrl
  }

  func initWriter(outputUrl: URL, outputWidth: Int, outputHeight: Int) -> (
    AVAssetWriter, AVAssetWriterInputPixelBufferAdaptor
  ) {

    let assetWriter = try! AVAssetWriter(
      outputURL: outputUrl,
      fileType: .mov
    )

    let assetWriterInput = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoWidthKey: outputWidth,
        AVVideoHeightKey: outputHeight,
        AVVideoCodecKey: AVVideoCodecType.proRes422HQ,
      ]
    )

    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput)

    assetWriter.add(assetWriterInput)
    assetWriter.startWriting()
    assetWriter.startSession(atSourceTime: .zero)
    return (assetWriter, adaptor)
  }

  func extractDimensions(sampleBuffer: CMSampleBuffer) throws -> (Int, Int) {
    guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else {
      // Handle error: format description not available
      throw MediaError.couldNotParse
    }
    let dimensions = CMVideoFormatDescriptionGetDimensions(formatDesc)
    let width = dimensions.width
    let height = dimensions.height

    return (Int(width), Int(height))
  }

  func processSample(
    sampleBuffer: CMSampleBuffer, leftAdaptor: AVAssetWriterInputPixelBufferAdaptor,
    rightAdaptor: AVAssetWriterInputPixelBufferAdaptor
  ) {
    let presentationTs = sampleBuffer.presentationTimeStamp

    guard let taggedBuffers = sampleBuffer.taggedBuffers else { return }
    let leftEyeBuffer = taggedBuffers.first(where: {
      $0.tags.first(matchingCategory: .stereoView) == .stereoView(.leftEye)
    })?.buffer
    let rightEyeBuffer =
      taggedBuffers.first(where: {
        $0.tags.first(matchingCategory: .stereoView) == .stereoView(.rightEye)
      })?.buffer

    if let leftEyeBuffer,
      let rightEyeBuffer,
      case let .pixelBuffer(leftEyePixelBuffer) = leftEyeBuffer,
      case let .pixelBuffer(rightEyePixelBuffer) = rightEyeBuffer
    {
      while !leftAdaptor.assetWriterInput.isReadyForMoreMediaData {
        // waiting
      }
      leftAdaptor.append(leftEyePixelBuffer, withPresentationTime: presentationTs)
      while !rightAdaptor.assetWriterInput.isReadyForMoreMediaData {
        // waiting...
      }
      rightAdaptor.append(rightEyePixelBuffer, withPresentationTime: presentationTs)
      incrementFrameCountAndLog()
    }
  }

  func checkFileOverwrite(path: String) throws -> Bool {

    if !FileManager.default.fileExists(atPath: path) {
      return true
    }

    print("Overwrite existing file? [y/N]: ")

    guard let userInput = readLine() else {
      print("aborting!")
      return false
    }

    if userInput.caseInsensitiveCompare("y") == .orderedSame {
      try FileManager.default.removeItem(atPath: path)
      return true
    } else {
      print("aborting!")
      return false
    }
  }

  func initReader(sourceUrl: URL) throws -> (AVAssetReader, AVAssetReaderTrackOutput) {
    let semaphore = DispatchSemaphore(value: 0)
    let sourceMovieAsset = AVAsset(url: sourceUrl)

    var tracks: [AVAssetTrack]?
    sourceMovieAsset.loadTracks(
      withMediaType: .video,
      completionHandler: { (foundtracks, error) in
        tracks = foundtracks
        semaphore.signal()
      })

    let loadingTimeoutResult = semaphore.wait(timeout: .now() + 60 * 60 * 24)
    switch loadingTimeoutResult {
    case .success:
      print("loaded video track")
    case .timedOut:
      print("loading video track exceeded hardcoded limit of 24 hours")
    }

    guard let tracks = tracks else {
      print("could not load any tracks!")
      throw MediaError.noVideoTracksFound
    }
    let assetReaderTrackOutput = AVAssetReaderTrackOutput(
      track: tracks.first!,
      outputSettings: decoderOutputSettings
    )
    assetReaderTrackOutput.alwaysCopiesSampleData = false
    let assetReader = try AVAssetReader(asset: sourceMovieAsset)
    assetReader.add(assetReaderTrackOutput)
    return (assetReader, assetReaderTrackOutput)
  }

  public func transcodeMovie(filePath: String, outputDir: String?) {
    do {
      let sourceMovieUrl = URL(fileURLWithPath: filePath)
      let inputFileExtension = sourceMovieUrl.pathExtension
      let inputFilename = sourceMovieUrl.lastPathComponent
      let basename = inputFilename.dropLast(inputFileExtension.count + 1)

      let (assetReader, assetReaderTrackOutput) = try initReader(sourceUrl: sourceMovieUrl)

      if !assetReader.startReading() {
        print("could not start reading")
        return
      }

      let inputSize = assetReaderTrackOutput.track.naturalSize
      let width = Int(inputSize.width)
      let height = Int(inputSize.height)

      let leftUrl = try createOutputUrl(
        outputFilename: basename + "_LEFT.mov", outputDir: outputDir)
      let rightUrl = try createOutputUrl(
        outputFilename: basename + "_RIGHT.mov", outputDir: outputDir)

      let (leftWriter, leftAdaptor) = initWriter(
        outputUrl: leftUrl, outputWidth: width, outputHeight: height)
      let (rightWiter, rightAdaptor) = initWriter(
        outputUrl: rightUrl, outputWidth: width, outputHeight: height)

      let semaphore = DispatchSemaphore(value: 0)

      while assetReader.status == .reading {
        guard let nextSampleBuffer = assetReaderTrackOutput.copyNextSampleBuffer() else {
          if assetReader.status == .completed {
            print("finished reading all of \(filePath)")
          } else {
            print("advancing due to null sample, reader status is \(assetReader.status)")
          }
          leftAdaptor.assetWriterInput.markAsFinished()
          rightAdaptor.assetWriterInput.markAsFinished()
          semaphore.signal()
          continue
        }
        processSample(
          sampleBuffer: nextSampleBuffer, leftAdaptor: leftAdaptor, rightAdaptor: rightAdaptor)
      }

      let encodingTimeoutResult = semaphore.wait(timeout: .now() + 60 * 60 * 24)
      switch encodingTimeoutResult {
      case .success:
        print("encoding completed, flushing to disk... ")
      case .timedOut:
        print("encoding file processing time exceeded hardcoded limit of 24 hours")
      }

      leftWriter.finishWriting {
        semaphore.signal()
      }
      rightWiter.finishWriting {
        semaphore.signal()
      }
      var writingTimeoutResult = semaphore.wait(timeout: .now() + 60 * 60 * 24)
      switch writingTimeoutResult {
      case .success:
        print("finished writing one file")
      case .timedOut:
        print("writing file processing time exceeded hardcoded limit of 24 hours")
        throw MediaError.timeoutError
      }

      writingTimeoutResult = semaphore.wait(timeout: .now() + 60 * 60 * 24)
      switch writingTimeoutResult {
      case .success:
        print("finished writing both files")
      case .timedOut:
        print("writing second file processing time exceeded hardcoded limit of 24 hours")
        throw MediaError.timeoutError
      }
    } catch {
      print("Unexpected error: \(error).")
    }
  }
}
