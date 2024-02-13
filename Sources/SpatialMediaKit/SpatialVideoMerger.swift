//
//  SpatialVideoMerger.swift
//  SpatialMediaKit
//
//  Created by Nicholas Tinsley on 1/25/24.
//

import AVFoundation
import Foundation
import VideoToolbox

public class SpatialVideoMerger {
  let decoderOutputSettings: [String: Any] = [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_422YpCbCr16,
    AVVideoDecompressionPropertiesKey: [
      kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder: true
    ],
  ]

  var completedFrames = 0

  public init() {
  }

  func incrementFrameCountAndLog() {
    completedFrames += 1
    print("\rencoded \(completedFrames) frames", terminator: "")
  }

  func getCurrentlyProcessingFrameNumber() -> Int {
    return completedFrames + 1
  }

  func createOutputUrl(outputFilePath: String) throws -> URL {
    let outputUrl = URL(fileURLWithPath: outputFilePath)
    if try !checkFileOverwrite(path: outputUrl.path()) {
      throw MediaError.createOutputError
    }
    print("output file set to \(outputUrl)")
    return outputUrl
  }

  func initWriter(
    outputUrl: URL,
    outputWidth: Int,
    outputHeight: Int,
    videoQuality: Float,
    colorPrimaries: String,
    transferFunction: String,
    colorMatrix: String,
    hFov: Int,
    hDisparityAdj: Int?,
    leftIsPrimary: Bool
  )
    -> (
      AVAssetWriter, AVAssetWriterInputTaggedPixelBufferGroupAdaptor
    )
  {

    let assetWriter = try! AVAssetWriter(
      outputURL: outputUrl,
      fileType: .mov
    )

    let mvHevcViewIds = leftIsPrimary ? [0, 1] : [1, 0]
    let heroEye =
      leftIsPrimary ? kCMFormatDescriptionHeroEye_Left : kCMFormatDescriptionHeroEye_Right

    var outputSettingsDict: [String: Any] = [
      AVVideoWidthKey: outputWidth,
      AVVideoHeightKey: outputHeight,
      AVVideoColorPropertiesKey: [
        AVVideoColorPrimariesKey: colorPrimaries,
        AVVideoTransferFunctionKey: transferFunction,
        AVVideoYCbCrMatrixKey: colorMatrix,
      ],
      AVVideoCompressionPropertiesKey: [
        kVTCompressionPropertyKey_HDRMetadataInsertionMode: kVTHDRMetadataInsertionMode_Auto,
        kVTCompressionPropertyKey_ProfileLevel: kVTProfileLevel_HEVC_Main10_AutoLevel,
        kVTCompressionPropertyKey_Quality: videoQuality,
        kVTCompressionPropertyKey_MVHEVCVideoLayerIDs: [0, 1] as CFArray,
        kVTCompressionPropertyKey_MVHEVCViewIDs: [0, 1] as CFArray,
        kCMFormatDescriptionExtension_HorizontalFieldOfView: hFov,  // asset-specific, in thousandths of a degree
        kVTCompressionPropertyKey_MVHEVCLeftAndRightViewIDs: mvHevcViewIds,  // asset-specific
        kVTCompressionPropertyKey_HeroEye: heroEye,
      ],
      AVVideoCodecKey: AVVideoCodecType.hevc,
    ]

    if let hDisparityAdj = hDisparityAdj {
      if let compressionPropsDict = outputSettingsDict[AVVideoCompressionPropertiesKey] as? [String: Any] {
        let compressionProps = NSMutableDictionary(dictionary: compressionPropsDict)
        compressionProps[kVTCompressionPropertyKey_HorizontalDisparityAdjustment] = hDisparityAdj
        outputSettingsDict[AVVideoCompressionPropertiesKey] = compressionProps
      }
    }

    let assetWriterInput = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: outputSettingsDict
    )

    let adaptor = AVAssetWriterInputTaggedPixelBufferGroupAdaptor(
      assetWriterInput: assetWriterInput)

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
    leftSampleBuffer: CMSampleBuffer, rightSampleBuffer: CMSampleBuffer,
    adaptor: AVAssetWriterInputTaggedPixelBufferGroupAdaptor, leftIsPrimary: Bool
  ) throws {

    let leftPresentationTs = leftSampleBuffer.presentationTimeStamp
    let rightPresentationTs = rightSampleBuffer.presentationTimeStamp

    if leftPresentationTs != rightPresentationTs {
      print(
        "mismatched presentation timestamps on frame \(getCurrentlyProcessingFrameNumber())! left: \(leftPresentationTs) right: \(rightPresentationTs)"
      )
      throw MediaError.inputTimestampMismatch
    }

    while leftSampleBuffer.dataReadiness != .ready {
      print("left input sample buffer not ready!")
    }

    while rightSampleBuffer.dataReadiness != .ready {
      print("right input sample buffer not ready!")
    }

    if let leftEyeBuffer = leftSampleBuffer.imageBuffer,
      let rightEyeBuffer = rightSampleBuffer.imageBuffer
    {

      let leftEyeLayerIndex: Int64 = leftIsPrimary ? 0 : 1
      let rightEyeLayerIndex: Int64 = leftIsPrimary ? 1 : 0

      let left = CMTaggedBuffer(
        tags: [.stereoView(.leftEye), .videoLayerID(leftEyeLayerIndex)], pixelBuffer: leftEyeBuffer)
      let right = CMTaggedBuffer(
        tags: [.stereoView(.rightEye), .videoLayerID(rightEyeLayerIndex)],
        pixelBuffer: rightEyeBuffer)
      while !adaptor.assetWriterInput.isReadyForMoreMediaData {
        // waiting
      }

      let result = adaptor.appendTaggedBuffers(
        [left, right], withPresentationTime: leftPresentationTs)

      if result {
        incrementFrameCountAndLog()
      } else {
        print(
          "appending tag buffer for frame \(getCurrentlyProcessingFrameNumber()) not successful!")
        throw MediaError.appendTaggedBufferError
      }
    }
  }

  func checkFileOverwrite(path: String) throws -> Bool {

    if !FileManager.default.fileExists(atPath: path) {
      return true
    }

    print("File already exists: \(path)")
    print("Overwrite existing file? [y/N]: ", terminator: "")

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

  public func transcodeMovie(
    leftFilePath: String,
    rightFilePath: String,
    outputFilePath: String,
    quality: Float,
    horizontalFieldOfView: Int,
    horizontalDisparityAdjustment: Int?,
    leftIsPrimary: Bool
  ) {
    do {
      let leftSourceMovieUrl = URL(fileURLWithPath: leftFilePath)
      let rightSourceMovieUrl = URL(fileURLWithPath: rightFilePath)

      let (leftAssetReader, leftAssetReaderTrackOutput) = try initReader(
        sourceUrl: leftSourceMovieUrl)

      if !leftAssetReader.startReading() {
        print("could not start reading left input file")
        return
      }
      let (rightAssetReader, rightAssetReaderTrackOutput) = try initReader(
        sourceUrl: rightSourceMovieUrl)

      if !rightAssetReader.startReading() {
        print("could not start reading right input file")
        return
      }

      var colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
      var transferFunction = AVVideoTransferFunction_ITU_R_709_2
      var colorMatrix = AVVideoYCbCrMatrix_ITU_R_709_2

      let videoFormatDescription =
        (leftIsPrimary
        ? leftAssetReaderTrackOutput.track.formatDescriptions[0]
        : rightAssetReaderTrackOutput.track.formatDescriptions[0]) as! CMFormatDescription
      if let formatExtensions = CMFormatDescriptionGetExtensions(videoFormatDescription)
        as? [String: Any]
      {
        if let extractedColorPrimaries = formatExtensions[kCVImageBufferColorPrimariesKey as String]
          as? String
        {
          colorPrimaries = extractedColorPrimaries
        }
        if let extractedTransferFunction = formatExtensions[
          kCVImageBufferTransferFunctionKey as String] as? String
        {
          transferFunction = extractedTransferFunction
        }
        if let extractedColorMatrix = formatExtensions[kCVImageBufferYCbCrMatrixKey as String]
          as? String
        {
          colorMatrix = extractedColorMatrix
        }
      }

      let leftInputSize = leftAssetReaderTrackOutput.track.naturalSize
      let rightInputSize = rightAssetReaderTrackOutput.track.naturalSize

      if leftInputSize != rightInputSize {
        print("left and right input resolutions do not match. aborting!")
        return
      }

      let width = Int(leftInputSize.width)
      let height = Int(leftInputSize.height)

      let leftUrl = try createOutputUrl(outputFilePath: outputFilePath)

      let (leftWriter, adaptor) = initWriter(
        outputUrl: leftUrl, outputWidth: width, outputHeight: height, videoQuality: quality,
        colorPrimaries: colorPrimaries, transferFunction: transferFunction,
        colorMatrix: colorMatrix, hFov: horizontalFieldOfView,
        hDisparityAdj: horizontalDisparityAdjustment, leftIsPrimary: leftIsPrimary)

      let semaphore = DispatchSemaphore(value: 0)

      while leftAssetReader.status == .reading && rightAssetReader.status == .reading {
        let nextLeftSampleBuffer = leftAssetReaderTrackOutput.copyNextSampleBuffer()
        let nextRightSampleBuffer = rightAssetReaderTrackOutput.copyNextSampleBuffer()
        guard let nextLeftSampleBuffer, let nextRightSampleBuffer
        else {
          if leftAssetReader.status == .completed && rightAssetReader.status == .completed {
            print("\nfinished reading both input files")
          } else {
            print(
              "\nnull sample, ending process. left reader status: \(leftAssetReader.status) right reader status: \(rightAssetReader.status)"
            )
          }
          adaptor.assetWriterInput.markAsFinished()
          semaphore.signal()
          continue
        }
        try processSample(
          leftSampleBuffer: nextLeftSampleBuffer, rightSampleBuffer: nextRightSampleBuffer,
          adaptor: adaptor, leftIsPrimary: leftIsPrimary)
      }

      let encodingTimeoutResult = semaphore.wait(timeout: .now() + 60 * 60 * 24)
      switch encodingTimeoutResult {
      case .success:
        print("finished encoding, flushing bytes to disk... ")
      case .timedOut:
        print("encoding file processing time exceeded hardcoded limit of 24 hours")
      }

      leftWriter.finishWriting {
        semaphore.signal()
      }
      let writingTimeoutResult = semaphore.wait(timeout: .now() + 60 * 60 * 24)
      switch writingTimeoutResult {
      case .success:
        print("finished writing output file")
      case .timedOut:
        print("writing file processing time exceeded hardcoded limit of 24 hours")
        throw MediaError.timeoutError
      }
    } catch {
      print("Unexpected error: \(error).")
    }
  }
}
