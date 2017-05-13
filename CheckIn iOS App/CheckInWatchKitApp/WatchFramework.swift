//
//  WatchFramework.swift
//  TruePassWatchKitApp Extension
//
//  Created by Cliff Panos on 4/16/17.
//  Copyright © 2017 Clifford Panos. All rights reserved.
//

import WatchKit
import WatchConnectivity

class WC: NSObject {
    
    static var initialViewController: InterfaceController?
    static var currentlyPresenting: WKInterfaceController?
    static var ext: WKExtensionDelegate?
    
    static var session: WCSession? {
        return ExtensionDelegate.session
    }
    
    static var iPhoneIsAvailable: Bool {
        guard let theSession = WC.session else {
            return false
        }
        return theSession.isReachable && theSession.activationState == .activated
    }
    
    
    static var userIsLoggedIn: Bool {
        get {
            if let loggedIn = Shared.defaults.value(forKey: "userIsLoggedIn") as? Bool {
                return loggedIn
            }
            return false
        }
        set {
            print("WatchOS User is logging \(newValue ? "in" : "out")---------------")
            Shared.defaults.setValue(newValue, forKey: "userIsLoggedIn")
            Shared.defaults.synchronize()
            
            if !newValue { //If not logged in
                WC.currentlyPresenting?.presentController(withName: "signInRequiredController", context: nil)

            } else {
                debugPrint(WC.currentlyPresenting ?? "No currently presenting")
                WC.currentlyPresenting?.dismiss()

            }
        }

    }

    
    
    //MARK: - Handle the QR Code image logic
    static var checkInPassImage: UIImage? {
        
        didSet {
            if let presented = WC.currentlyPresenting as? CheckInPassInterfaceController {
                print("Currently presenting the CheckInPassVC")
                presented.imageView.setImage(checkInPassImage)
                presented.retrievingPassLabel.setHidden(true)
            }
        }
    }
    
    static func getQRCodeImageUsingWC() {
        
        guard WC.checkInPassImage == nil && iPhoneIsAvailable else {
            return
        }
        
        ExtensionDelegate.session?.sendMessage([WCD.KEY : WCD.checkInPassRequest], replyHandler: {
            
            message in
        
            print("Did receive replyhandler for QRImage")
            guard let imageData = message[WCD.checkInPassRequest] as? Data else {
                print("WATCH MESSAGE HANDLER for QR CODE FAIL")
                return
            }
            WC.checkInPassImage = UIImage(data: imageData)
            print("IMAGE SETTING FROM WC SUCCESS")
        
        }, errorHandler: { error in print(error) })
    
    }
    
    
    //MARK: - Handle pass retrieval and storage
    static var passes: [Pass] = []
    static func requestPassesFromiOS(forIndex index: Int) {
        
        guard iPhoneIsAvailable else { return }
        
        ExtensionDelegate.session?.sendMessage([WCD.KEY : WCD.allPassesRequest, WCD.nextPassIndex : index], replyHandler: { message in
            guard let data = message[WCD.passPayload] as? Data else {
                return //Meaning no passes were receieved
            }
            let dictionary = NSKeyedUnarchiver.unarchiveObject(with: data)
            print("RECEIVED PASS REPLY FROM REQUEST from WC.swift")
            WC.addPass(fromMessage: dictionary as! Dictionary<String, Any>)
            
            let nextPassIndex = message[WCD.nextPassIndex] as! Int
            if (nextPassIndex) != -1 {
                WC.requestPassesFromiOS(forIndex: nextPassIndex)
            }

        }, errorHandler: {error in print(error); print("Pass request failed")})
    }
    static func addPass(fromMessage message: Dictionary<String, Any>) {
        
        let pass = constructPass(forDictionaryData: message)
        if !WC.passes.contains(pass) {
            WC.passes.append(pass)
            print("Pass added to Passes!")
            InterfaceController.updatetable()
        }
    }
    
    static func constructPass(forDictionaryData dictionary: [String : Any]) -> Pass {
        let pass = Pass()
        pass.name = dictionary["name"] as! String
        pass.email = dictionary["email"] as! String?
        pass.image = dictionary["image"] as? Data
        pass.timeStart = dictionary["timeStart"] as! String
        pass.timeEnd = dictionary["timeEnd"] as! String
        return pass
    }
    

}
