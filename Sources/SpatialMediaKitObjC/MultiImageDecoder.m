//
//  MultiImageDecoder.m
//  SpatialMediaKit
//
//  Created by Nicholas Tinsley on 1/21/24.
//

#import "MultiImageDecoder.h"

@implementation MultiImageDecoder

+ (OSStatus) decodeMultiImage:(VTDecompressionSessionRef)session
                 sampleBuffer:(CMSampleBufferRef)sampleBuffer
                  decodeFlags:(VTDecodeFrameFlags)decodeFlags
                 infoFlagsOut:(VTDecodeInfoFlags *)infoFlagsOut
multiImageCapableOutputHandler:(VTDecompressionMultiImageCapableOutputHandler)multiImageCapableOutputHandler {
    // VTDecompressionSessionDecodeFrameWithMultiImageCapableOutputHandler is not accessible by default in Swift
    return VTDecompressionSessionDecodeFrameWithMultiImageCapableOutputHandler(session, sampleBuffer, decodeFlags, infoFlagsOut, multiImageCapableOutputHandler);
    }

@end
