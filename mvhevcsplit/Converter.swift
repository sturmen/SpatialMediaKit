//
//  Converter.swift
//  mvhevcsplit
//
//  Created by Nicholas Tinsley on 1/21/24.
//

import Foundation
import AVFoundation
import VideoToolbox

class Converter {
    let outputHeight, outputWidth: Int
    
    init(height: Int, width: Int) {
        self.outputHeight = height
        self.outputWidth = width
    }
    
    let decoderOutputSettings: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_422YpCbCr16,
        AVVideoDecompressionPropertiesKey: [
            kVTDecompressionPropertyKey_RequestedMVHEVCVideoLayerIDs: [0, 1] as CFArray,
        ],
    ]
    
    let semaphore = DispatchSemaphore(value: 0)
    
    var completedFrames = 0
    
    func incrementFrameCount() {
        completedFrames += 1
    }
    
    func getCurrentFrameCount() -> Int {
        return completedFrames
    }
    
    func initWriter(outputUrl: URL) -> (assetWriter: AVAssetWriter, adaptor: AVAssetWriterInputPixelBufferAdaptor) {
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
    
    func transcodeMovie(filePath: String, firstEye: Bool) {
        do {
            
            let chosenEyeLabel =  if (firstEye) {
                "left"
            } else {
                "right"
            }
            print("about to start transcoding \(filePath) for " + chosenEyeLabel + " eye.")
            let outputFilename = "output_" + chosenEyeLabel + ".mov"
            
            let outputUrl = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(outputFilename)
            
            if (FileManager.default.fileExists(atPath: outputUrl.path)) {
                try FileManager.default.removeItem(atPath: outputUrl.path)
            }
            
            let sourceMovieUrl = URL(fileURLWithPath: filePath)
            let sourceMovieAsset = AVAsset(url: sourceMovieUrl)
            
            var tracks: [AVAssetTrack]?
            sourceMovieAsset.loadTracks(withMediaType: .video, completionHandler: { (foundtracks, error) in
                tracks = foundtracks
                self.semaphore.signal()
            })
            
            let loadingTimeoutResult = self.semaphore.wait(timeout: .now() + 60*60*24)
            switch loadingTimeoutResult {
            case .success:
                print("loaded video track")
            case .timedOut:
                print("loading video track exceeded hardcoded limit of 24 hours")
            }
            
            guard let tracks = tracks else {
                print("could not load any tracks!")
                return
            }
            let assetReaderTrackOutput = AVAssetReaderTrackOutput(
                track: tracks.first!,
                outputSettings: decoderOutputSettings
            )
            assetReaderTrackOutput.alwaysCopiesSampleData = false
            let assetReader = try AVAssetReader(asset: sourceMovieAsset)
            assetReader.add(assetReaderTrackOutput)
            
            if (!assetReader.startReading()) {
                print("could not start reading")
                return
            }

            let serialQueue = DispatchQueue(label: "writer")
            
            let (assetWriter, adaptor) = initWriter(outputUrl: outputUrl)
            
            print("about to start writing")
            adaptor.assetWriterInput.requestMediaDataWhenReady(on: serialQueue) { [weak self] in
                print("output stream ready to be written to")
                guard let self = self else {
                    print("self was null, aborting")
                    return
                }
                while adaptor.assetWriterInput.isReadyForMoreMediaData {
                    var presentationTs = CMTime.zero
                    while (assetReader.status == .reading) {
                        guard let nextSampleBuffer = assetReaderTrackOutput.copyNextSampleBuffer() else {
                            if (assetReader.status == .completed) {
                                print("finished reading all of \(filePath)")
                            } else {
                                print("advancing due to null sample, reader status is \(assetReader.status)")
                            }
                            adaptor.assetWriterInput.markAsFinished()
                            self.semaphore.signal()
                            continue
                        }
                        presentationTs = nextSampleBuffer.presentationTimeStamp
                        
                        guard let taggedBuffers = nextSampleBuffer.taggedBuffers else { return }
                        let eyeBuffer =  if (firstEye) {
                            taggedBuffers.first(where: {
                                $0.tags.first(matchingCategory: .stereoView) == .stereoView(.leftEye)
                            })?.buffer
                        } else {
                            taggedBuffers.first(where: {
                                $0.tags.first(matchingCategory: .stereoView) == .stereoView(.rightEye)
                            })?.buffer
                        }
                        
                        
                        if let eyeBuffer,
                           case let .pixelBuffer(eyePixelBuffer) = eyeBuffer {
                            adaptor.append(eyePixelBuffer, withPresentationTime: presentationTs)
                            while(!adaptor.assetWriterInput.isReadyForMoreMediaData) {
                                // waiting...
                            }
                            incrementFrameCount()
                            print("encoded \(getCurrentFrameCount()) frames for \(outputFilename)")
                        }
                    }
                }
            }
            let encodingTimeoutResult = semaphore.wait(timeout: .now() + 60*60*24)
            switch encodingTimeoutResult {
            case .success:
                print("encoding completed for \(outputFilename), flushing to disk... ")
            case .timedOut:
                print("encoding file processing time exceeded hardcoded limit of 24 hours")
            }
            
            assetWriter.finishWriting() {
                self.semaphore.signal()
            }
            let writingTimeoutResult = self.semaphore.wait(timeout: .now() + 60*60*24)
            switch writingTimeoutResult {
            case .success:
                print("writing \(outputFilename) to disk completed")
            case .timedOut:
                print("writing file processing time exceeded hardcoded limit of 24 hours")
            }
        } catch {
            print("Unexpected error: \(error).")
        }
    }
}
