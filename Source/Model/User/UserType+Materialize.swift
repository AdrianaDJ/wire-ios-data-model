//
// Wire
// Copyright (C) 2020 Wire Swiss GmbH
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

fileprivate extension UserType {
    
    func materialize(in context: NSManagedObjectContext) -> ZMUser? {
        if let user = self as? ZMUser {
            return user
        } else if let searchUser = self as? ZMSearchUser {
            if let user = searchUser.user {
                return user
            } else if let remoteIdentifier = searchUser.remoteIdentifier {
                return ZMUser(remoteID: remoteIdentifier, createIfNeeded: false, in: context)
            }
        }
        
        return nil
    }
    
}

extension Sequence where Element: UserType {
    
    /// Materialize a sequence of UserType into concrete ZMUser instances.
    ///
    /// - parameter context: NSManagedObjectContext on which users should be created.
    ///
    /// - Returns: List of concrete users which could be materialized.
    
    func materialize(in context: NSManagedObjectContext) -> [ZMUser] {
        let nonExistingUsers = self.compactMap({ $0 as? ZMSearchUser }).filter({ $0.user == nil })
        let syncContext = context.zm_sync!
        
        syncContext.performGroupedBlockAndWait {
            nonExistingUsers.forEach { _ = ZMUser(remoteID: $0.remoteIdentifier!, // TODO jacob make remoteIdentifier non optional
                                                  createIfNeeded: true,
                                                  in: syncContext)
            }
            syncContext.saveOrRollback()
        }
        
        return self.compactMap({ $0.materialize(in: context) })
    }
    
}
