//
//  MultiImageDecoder.h
//  SpatialMediaKit
//
//  Created by Nicholas Tinsley on 1/21/24.
//
#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>

@interface MultiImageDecoder : NSObject

// This is a bridge because the underlying method is not exposed in Swift, for some reason.
+ (OSStatus)decodeMultiImage:(VTDecompressionSessionRef)session
                sampleBuffer:(CMSampleBufferRef)sampleBuffer
                 decodeFlags:(VTDecodeFrameFlags)decodeFlags
                infoFlagsOut:(VTDecodeInfoFlags *)infoFlagsOut
multiImageCapableOutputHandler:(VTDecompressionMultiImageCapableOutputHandler)multiImageCapableOutputHandler;

@end
