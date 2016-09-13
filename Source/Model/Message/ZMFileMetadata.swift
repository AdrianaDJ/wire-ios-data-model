// 
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
// 


import Foundation
import MobileCoreServices
import ZMCSystem
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


private let zmLog = ZMSLog(tag: "ZMFileMetadata")


@objc open class ZMFileMetadata : NSObject {
    
    open let fileURL : URL
    open let thumbnail : Data?
    
    required public init(fileURL: URL, thumbnail: Data? = nil) {
        self.fileURL = fileURL
        self.thumbnail = thumbnail?.count > 0 ? thumbnail : nil
        
        super.init()
    }
    
    var asset : ZMAsset {
        get {
            return ZMAsset.asset(withOriginal: .original(withSize: size,
                mimeType: mimeType,
                name: filename)
            )
        }
    }
}


open class ZMAudioMetadata : ZMFileMetadata {
    
    open let duration : TimeInterval
    open let normalizedLoudness : [Float]
    
    required public init(fileURL: URL, duration: TimeInterval, normalizedLoudness: [Float] = [], thumbnail: Data? = nil) {
        self.duration = duration
        self.normalizedLoudness = normalizedLoudness
        
        super.init(fileURL: fileURL, thumbnail: thumbnail)
    }
    
    required public init(fileURL: URL, thumbnail: Data?) {
        self.duration = 0
        self.normalizedLoudness = []
        
        super.init(fileURL: fileURL, thumbnail: thumbnail)
    }
    
    override var asset : ZMAsset {
        get {
            return ZMAsset.asset(withOriginal: .original(withSize: size,
                mimeType: mimeType,
                name: filename,
                audioDurationInMillis: UInt(duration * 1000),
                normalizedLoudness: normalizedLoudness)
            )
        }
    }
    
}

open class ZMVideoMetadata : ZMFileMetadata {
    
    open let duration : TimeInterval
    open let dimensions : CGSize
    
    required public init(fileURL: URL, duration: TimeInterval, dimensions: CGSize, thumbnail: Data? = nil) {
        self.duration = duration
        self.dimensions = dimensions
        
        super.init(fileURL: fileURL, thumbnail: thumbnail)
    }
    
    required public init(fileURL: URL, thumbnail: Data?) {
        self.duration = 0
        self.dimensions = CGSize.zero
        
        super.init(fileURL: fileURL, thumbnail: thumbnail)
    }
    
    override var asset : ZMAsset {
        get {
            return ZMAsset.asset(withOriginal: .original(withSize: size,
                mimeType: mimeType,
                name: filename,
                videoDurationInMillis: UInt(duration * 1000),
                videoDimensions: dimensions)
            )
        }
    }
    
}

extension ZMFileMetadata {
    
    var mimeType : String {
        get {
            let pathExtension = fileURL.pathExtension as CFString
            guard  let UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension, nil)?.takeRetainedValue(),
                  let MIMEType = UTTypeCopyPreferredTagWithClass (UTI, kUTTagClassMIMEType) else {
                    return "application/octet-stream"
            }
            
            return (MIMEType.takeRetainedValue()) as String
        }
    }
    
    public var filename : String {
        get {
            return  fileURL.lastPathComponent
        }
    }
    
    var size : UInt64 {
        get {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                if let fileSize = attributes[FileAttributeKey.size] as? NSNumber {
                    return fileSize.uint64Value
                }
            } catch {
                zmLog.error("Couldn't read file size of \(fileURL)")
                return 0
            }
            
            return 0
        }
    }
    
}
