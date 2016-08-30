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

private enum MessageKey: String {
    case DeliveryState = "deliveryState"
    case MediumData = "mediumData"
    case MediumRemoteIdentifier = "mediumRemoteIdentifier"
    case PreviewGenericMessage = "previewGenericMessage"
    case MediumGenericMessage = "mediumGenericMessage"
    case LinkPreviewState = "linkPreviewState"
    case GenericMessage = "genericMessage"
    case Reactions = "reactions"
}

extension ZMMessage : ObjectInSnapshot {
    
    public var observableKeys : [String] {
        var keys = [MessageKey.DeliveryState.rawValue]
        
        if self is ZMImageMessage {
            keys.append(MessageKey.MediumData.rawValue)
            keys.append(MessageKey.MediumRemoteIdentifier.rawValue)
        }
        if self is ZMAssetClientMessage {
            keys.append(ZMAssetClientMessageTransferStateKey)
            keys.append(MessageKey.PreviewGenericMessage.rawValue)
            keys.append(MessageKey.MediumGenericMessage.rawValue)
            keys.append(ZMAssetClientMessageDownloadedImageKey)
            keys.append(ZMAssetClientMessageDownloadedFileKey)
            keys.append(ZMAssetClientMessageProgressKey)
        }

        if self is ZMClientMessage {
            keys.append(ZMAssetClientMessageDownloadedImageKey)
            keys.append(MessageKey.LinkPreviewState.rawValue)
            keys.append(MessageKey.GenericMessage.rawValue)
        }
        
        if !(self is ZMSystemMessage) {
            keys.append(MessageKey.Reactions.rawValue)
        }

        return keys
    }
}

@objc final public class MessageChangeInfo : ObjectChangeInfo {
    
    public required init(object: NSObject) {
        self.message = object as! ZMMessage
        super.init(object: object)
    }
    public var deliveryStateChanged : Bool {
        return changedKeysAndOldValues.keys.contains(MessageKey.DeliveryState.rawValue)
    }
    
    public var reactionsChanged : Bool {
        return changedKeysAndOldValues.keys.contains(MessageKey.Reactions.rawValue) || reactionChangeInfo != nil
    }

    /// Whether the image data on disk changed
    public var imageChanged : Bool {
        return !Set(arrayLiteral: MessageKey.MediumData.rawValue,
            MessageKey.MediumRemoteIdentifier.rawValue,
            MessageKey.PreviewGenericMessage.rawValue,
            MessageKey.MediumGenericMessage.rawValue,
            ZMAssetClientMessageDownloadedImageKey
        ).isDisjointWith(changedKeysAndOldValues.keys)
    }
    
    /// Whether the file on disk changed
    public var fileAvailabilityChanged: Bool {
        return changedKeysAndOldValues.keys.contains(ZMAssetClientMessageDownloadedFileKey)
    }

    public var usersChanged : Bool {
        return userChangeInfo != nil
    }
    
    private var linkPreviewDataChanged: Bool {
        guard let genericMessage = (message as? ZMClientMessage)?.genericMessage else { return false }
        guard let oldGenericMessage = changedKeysAndOldValues[MessageKey.GenericMessage.rawValue] as? ZMGenericMessage else { return false }
        let oldLinks = oldGenericMessage.linkPreviews
        let newLinks = genericMessage.linkPreviews
        
        return oldLinks != newLinks
    }
    
    public var linkPreviewChanged: Bool {
        return changedKeysAndOldValues.keys.contains(MessageKey.LinkPreviewState.rawValue) || linkPreviewDataChanged
    }

    public var senderChanged : Bool {
        if self.usersChanged && (self.userChangeInfo?.user as? ZMUser ==  self.message.sender){
            return true
        }
        return false
    }
    
    public var userChangeInfo : UserChangeInfo?
    public var reactionChangeInfo : ReactionChangeInfo?
    
    public let message : ZMMessage
}


extension Reaction : ObjectInSnapshot {
    
    public var observableKeys : [String] {
        return ["users"]
    }
}


public final class ReactionChangeInfo : ObjectChangeInfo {
 
    var usersChanged : Bool {
        return changedKeysAndOldValues.keys.contains("users")
    }
}

@objc protocol ReactionObserver {
    func reactionDidChange(reactionInfo: ReactionChangeInfo)
}


final class ReactionObserverToken : ObjectObserverTokenContainer {
    typealias ReactionTokenType = ObjectObserverToken<ReactionChangeInfo, ReactionObserverToken>
    
    private let observedReaction : Reaction
    private weak var observer : ReactionObserver?
    
    init (observer: ReactionObserver, observedObject: Reaction) {
        
        self.observer = observer
        self.observedReaction = observedObject
        
        var changeHandler: (ReactionObserverToken, ReactionChangeInfo) -> () = { _ in  }
        
        let innerToken = ReactionTokenType.token(observedObject,
                                                 observableKeys: ["users"],
                                                 managedObjectContextObserver: observedObject.managedObjectContext!.globalManagedObjectContextObserver,
                                                 changeHandler: { changeHandler($0, $1) })
        super.init(object: observedObject, token: innerToken)

        changeHandler = { (_, changeInfo) in self.observer?.reactionDidChange(changeInfo) }
        
    }
    
    override func tearDown() {
        if let t = self.token as? ReactionTokenType {
            t.tearDown()
        }
        
        super.tearDown()
    }
}


public final class MessageObserverToken: ObjectObserverTokenContainer, ZMUserObserver, ReactionObserver {
    
    typealias InnerTokenType = ObjectObserverToken<MessageChangeInfo,MessageObserverToken>


    private let observedMessage: ZMMessage
    private weak var observer : ZMMessageObserver?
    private var userTokens: [UserCollectionObserverToken] = []
    
    private var reactionTokens : [Reaction : ReactionObserverToken] = [:]
    
    public init(observer: ZMMessageObserver, object: ZMMessage) {
        self.observedMessage = object
        self.observer = observer
        
        var changeHandler : (MessageObserverToken, MessageChangeInfo) -> () = { _ in return }
        let innerToken = InnerTokenType.token(
            object,
            observableKeys: object.observableKeys,
            managedObjectContextObserver : object.managedObjectContext!.globalManagedObjectContextObserver,
            changeHandler: { changeHandler($0, $1) }
        )
        
        super.init(object:object, token: innerToken)
        
        innerToken.addContainer(self)
        
        changeHandler = {
            [weak self] (_, changeInfo) in
            if changeInfo.reactionsChanged {
                // add a new the new reaction observer
            }
            self?.observer?.messageDidChange(changeInfo)
        }
        
        if let sender = object.sender {
            self.userTokens.append(self.createTokenForUser(sender))
        }
        if let systemMessage = object as? ZMSystemMessage {
            for user in systemMessage.users {
                userTokens.append(self.createTokenForUser(user))
            }
        }
    }
    
    private func createTokenForUser(user: ZMUser) -> UserCollectionObserverToken {
        let token = ZMUser.addUserObserver(self, forUsers: [user], managedObjectContext: user.managedObjectContext!)
        return token as! UserCollectionObserverToken
    }
    
    public func userDidChange(changes: UserChangeInfo){
        if (changes.nameChanged || changes.accentColorValueChanged || changes.imageMediumDataChanged || changes.imageSmallProfileDataChanged) {
            let changeInfo = MessageChangeInfo(object: self.observedMessage)
            changeInfo.userChangeInfo = changes
            self.observer?.messageDidChange(changeInfo)
        }
    }
    
    func reactionDidChange(reactionInfo: ReactionChangeInfo) {
        let changeInfo = MessageChangeInfo(object: self.observedMessage)
        changeInfo.reactionChangeInfo = reactionInfo
        self.observer?.messageDidChange(changeInfo)
    }
    
    override public func tearDown() {

        for token in self.userTokens {
            token.tearDown()
        }
        
        for token in self.reactionTokens.values {
            token.tearDown()
        }
        
        self.userTokens = []
        
        if let t = self.token as? InnerTokenType {
            t.removeContainer(self)
            if t.hasNoContainers {
                t.tearDown()
            }
        }
        super.tearDown()
    }
    
    deinit {
        self.tearDown()
    }
    
}

