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
// along with this program. If not, see <http://www.gnu.org/licenses/>.
// 


import Foundation
import PINCache

extension PINCache
{
    // configures
    public func configureLimits(bytes: UInt) {
        self.diskCache.byteLimit = bytes;
        self.memoryCache.ageLimit  = 60 * 60; // if we didn't use it in 1 hour, it can go from memory
    }
    
    // disable backup of URL
    public func makeURLSecure() {
        self.diskCache.makeURLSecure()
    }
}

extension PINDiskCache
{
    // disable backup of URL
    public func makeURLSecure() {
        
        let secureBlock : (PINDiskCache) -> Void = { cache in
            // exclude from backup
            do {
                try cache.cacheURL.setResourceValue(true, forKey: NSURLIsExcludedFromBackupKey)
            } catch {
                fatal("Could not exclude \(cache.cacheURL) from backup")
            }
        }
        
        // every time the directory is recreated, make sure we set the property
        self.didRemoveAllObjectsBlock = secureBlock
        
        // just do it once initially
        self.synchronouslyLockFileAccessWhileExecutingBlock(secureBlock)
    }
}

