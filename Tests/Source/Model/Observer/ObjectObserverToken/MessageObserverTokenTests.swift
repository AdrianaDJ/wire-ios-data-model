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
import ZMCDataModel

class MessageObserverTokenTests : ZMBaseManagedObjectTest {
    
    class TestMessageObserver : NSObject, ZMMessageObserver {
        var receivedChangeInfo : [MessageChangeInfo] = []
        
        func messageDidChange(changes: MessageChangeInfo) {
            receivedChangeInfo.append(changes)
        }
    }
    
    override func setUp() {
        super.setUp()
        self.setUpCaches()

        self.uiMOC.globalManagedObjectContextObserver.syncCompleted(NSNotification(name: "fake", object: nil))
        XCTAssert(waitForAllGroupsToBeEmptyWithTimeout(0.5))
    }

    func checkThatItNotifiesTheObserverOfAChange(message : ZMMessage, modifier: (ZMMessage) -> Void, expectedChangedField : String?, customAffectedKeys: AffectedKeys? = nil) {
        
        // given
        let observer = TestMessageObserver()
        let token = MessageObserverToken(observer: observer, object: message)

        self.uiMOC.saveOrRollback()
        
        // when
        modifier(message)
        self.uiMOC.saveOrRollback()
        self.spinMainQueueWithTimeout(0.5)
        
        // then
        if expectedChangedField != nil {
            XCTAssertEqual(observer.receivedChangeInfo.count, 1)
        } else {
            XCTAssertEqual(observer.receivedChangeInfo.count, 0)
        }
        
        // and when
        self.uiMOC.saveOrRollback()
        
        // then
        XCTAssertTrue(observer.receivedChangeInfo.count <= 1, "Should have changed only once")
            
        let messageInfoKeys = [
            "imageChanged",
            "deliveryStateChanged",
            "senderChanged"
        ]
        
        if let changedField = expectedChangedField {
            if let changes = observer.receivedChangeInfo.first {
                for key in messageInfoKeys {
                    if key == changedField {
                        continue
                    }
                    if let value = changes.valueForKey(key) as? NSNumber {
                        XCTAssertFalse(value.boolValue, "\(key) was supposed to be false")
                    }
                    else {
                        XCTFail("Can't find key or key is not boolean for '\(key)'")
                    }
                }
            }
        }
        token.tearDown()
    }

    func testThatItNotifiesObserverWhenTheDeliveryStateChanges() {
        // given
        let message = ZMMessage.insertNewObjectInManagedObjectContext(self.uiMOC)
        message.serverTimestamp = nil
        message.eventID = nil
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(message,
            modifier: { $0.eventID = self.createEventID()},
            expectedChangedField: "deliveryStateChanged"
        )
    }
    
    func testThatItNotifiesObserverWhenTheSenderNameChanges() {
        // given
        let sender = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)
        sender.name = "Hans"
        
        let message = ZMMessage.insertNewObjectInManagedObjectContext(self.uiMOC)
        message.sender = sender

        // when
        self.checkThatItNotifiesTheObserverOfAChange(message,
            modifier: { $0.sender!.name = "Horst"},
            expectedChangedField: "senderChanged"
        )
    }
    
    func testThatItNotifiesObserverWhenTheFileTransferStateChanges() {
        // given
        let message = ZMAssetClientMessage.insertNewObjectInManagedObjectContext(self.uiMOC)
        message.transferState = .Uploading
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(message,
            modifier: {
            if let msg = $0 as? ZMAssetClientMessage {
                msg.transferState = .Uploaded
                }
            },
            expectedChangedField: ZMAssetClientMessageTransferStateKey
        )
    }
    
    func testThatItNotifiesObserverWhenTheSenderNameChangesBecauseOfAnotherUserWithTheSameName() {
        // given
        let sender = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)
        sender.name = "Hans A"
        
        let message = ZMMessage.insertNewObjectInManagedObjectContext(self.uiMOC)
        message.sender = sender
        
        self.uiMOC.saveOrRollback()
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(message,
            modifier: { _ in
                let newUser = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)
                newUser.name = "Hans K"
            },
            expectedChangedField: "senderChanged"
        )
    }
    
    func testThatItNotifiesObserverWhenTheSenderAccentColorChanges() {
        // given
        let sender = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)
        sender.accentColorValue = ZMAccentColor.BrightOrange
        
        let message = ZMMessage.insertNewObjectInManagedObjectContext(self.uiMOC)
        message.sender = sender
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(message,
            modifier: { $0.sender!.accentColorValue = ZMAccentColor.SoftPink },
            expectedChangedField: "senderChanged"
        )
    }
    
    func testThatItNotifiesObserverWhenTheSenderSmallProfileImageChanges() {
        // given
        let sender = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)
        sender.remoteIdentifier = NSUUID.createUUID()
        sender.mediumRemoteIdentifier = NSUUID.createUUID()
        let message = ZMMessage.insertNewObjectInManagedObjectContext(self.uiMOC)
        message.sender = sender
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(message,
            modifier: { $0.sender!.imageMediumData = self.verySmallJPEGData()},
            expectedChangedField: "senderChanged"
        )
    }
    
    func testThatItNotifiesObserverWhenTheSenderMediumProfileImageChanges() {
        // given
        let sender = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)
        sender.remoteIdentifier = NSUUID.createUUID()
        let message = ZMMessage.insertNewObjectInManagedObjectContext(self.uiMOC)
        message.sender = sender
        sender.smallProfileRemoteIdentifier = NSUUID.createUUID()
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(message,
            modifier: { $0.sender!.imageSmallProfileData = self.verySmallJPEGData()},
            expectedChangedField: "senderChanged"
        )
    }
    
    func testThatItNotifiesObserverWhenTheMediumImageDataChanges() {
        // given
        let message = ZMImageMessage.insertNewObjectInManagedObjectContext(self.uiMOC)
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(message,
            modifier: { message in
                if let imageMessage = message as? ZMImageMessage {
                    imageMessage.mediumData = self.verySmallJPEGData()}
            },
            expectedChangedField: "imageChanged"
        )
    }
    
    func testThatItNotifiesObserverWhenTheLinkPreviewStateChanges() {
        // when
        checkThatItNotifiesTheObserverOfAChange(
            ZMClientMessage.insertNewObjectInManagedObjectContext(uiMOC),
            modifier: { ($0 as? ZMClientMessage)?.linkPreviewState = .Downloaded },
            expectedChangedField: "linkPreviewChanged"
        )
    }
    
    func testThatItNotifiesObserverWhenTheLinkPreviewStateChanges_NewGenericMessageData() {
        // given
        
        let clientMessage = ZMClientMessage.insertNewObjectInManagedObjectContext(uiMOC)
        let nonce = NSUUID.createUUID()
        clientMessage.addData(ZMGenericMessage(text: name!, nonce: nonce.transportString()).data())
        let preview = ZMLinkPreview.linkPreview(
            withOriginalURL: "www.example.com",
            permanentURL: "www.example.com/permanent",
            offset: 42,
            title: "title",
            summary: "summary",
            imageAsset: nil
        )
        let updateGenericMessage = ZMGenericMessage(text: name!, linkPreview: preview, nonce: nonce.transportString())
        
        // when
        checkThatItNotifiesTheObserverOfAChange(
            clientMessage,
            modifier: { ($0 as? ZMClientMessage)?.addData(updateGenericMessage.data()) },
            expectedChangedField: "linkPreviewChanged"
        )
    }
    
    func testThatItDoesNotNotifiyObserversWhenTheSmallImageDataChanges() {
        // given
        let message = ZMImageMessage.insertNewObjectInManagedObjectContext(self.uiMOC)
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(message,
            modifier: { message in
                if let imageMessage = message as? ZMImageMessage {
                    imageMessage.previewData = self.verySmallJPEGData()}
            },
            expectedChangedField: nil
        )
    }
    
    func testThatItNotifiesWhenAReactionIsAddedOnMessage() {
        let message = ZMTextMessage.insertNewObjectInManagedObjectContext(self.uiMOC)
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(
            message,
            modifier: { message in
                if let textMessage = message as? ZMTextMessage {
                    textMessage.addReaction("LOVE IT, HUH", forUser: ZMUser.selfUserInContext(self.uiMOC))
                }
                
            },
            expectedChangedField: "reactionsChanged"
        )
    }
    
    func testThatItNotifiesWhenAReactionIsAddedOnMessageFromADifferentUser() {
        let message = ZMTextMessage.insertNewObjectInManagedObjectContext(uiMOC)
        let otherUser = ZMUser.insertNewObjectInManagedObjectContext(uiMOC)
        otherUser.name = "Hans"
        otherUser.remoteIdentifier = .createUUID()
        
        // when
        checkThatItNotifiesTheObserverOfAChange(
            message,
            modifier: { ($0 as? ZMTextMessage)?.addReaction("👻", forUser: otherUser) },
            expectedChangedField: "reactionsChanged"
        )
    }
    
    func testThatItNotifiesWhenAReactionIsUpdateForAUserOnMessage() {
        let message = ZMTextMessage.insertNewObjectInManagedObjectContext(self.uiMOC)
        let selfUser = ZMUser.selfUserInContext(self.uiMOC)
        message.addReaction("LOVE IT, HUH", forUser: selfUser)
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(
            message,
            modifier: { message in
                if let textMessage = message as? ZMTextMessage {
                    textMessage.addReaction(nil, forUser: selfUser)
                }
                
            },
            expectedChangedField: "reactionsChanged"
        )
        
    }
    
    func testThatItNotifiesWhenAReactionFromADifferentUserIsAddedOnTopOfSelfReaction() {
        let message = ZMTextMessage.insertNewObjectInManagedObjectContext(uiMOC)
        let otherUser = ZMUser.insertNewObjectInManagedObjectContext(uiMOC)
        otherUser.name = "Hans"
        otherUser.remoteIdentifier = .createUUID()
        
        let selfUser = ZMUser.selfUserInContext(self.uiMOC)
        message.addReaction("👻", forUser: selfUser)
        
        // when
        checkThatItNotifiesTheObserverOfAChange(
            message,
            modifier: { ($0 as? ZMTextMessage)?.addReaction("👻", forUser: otherUser) },
            expectedChangedField: "reactionsChanged"
        )
    }


    
    func testThatItStopsNotifyingAfterUnregisteringTheToken() {
        
        // given
        let message = ZMImageMessage.insertNewObjectInManagedObjectContext(self.uiMOC)
        self.uiMOC.saveOrRollback()
        
        let observer = TestMessageObserver()
        let token = ZMMessageNotification.addMessageObserver(observer, forMessage: message)
        ZMMessageNotification.removeMessageObserverForToken(token)

        
        // when
        message.serverTimestamp = NSDate()
        self.uiMOC.saveOrRollback()
        
        // then
        XCTAssertEqual(observer.receivedChangeInfo.count, 0)
    }
}
