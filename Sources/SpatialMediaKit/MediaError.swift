//
//  MediaError.swift
//  SpatialMediaKit
//
//  Created by Nicholas Tinsley on 1/22/24.
//

import Foundation

enum MediaError: Error {
  case invalidMediaInput
  case noVideoTracksFound
  case couldNotReadSample
  case couldNotParse
  case timeoutError
  case createOutputError
  case inputTimestampMismatch
  case appendTaggedBufferError
}
