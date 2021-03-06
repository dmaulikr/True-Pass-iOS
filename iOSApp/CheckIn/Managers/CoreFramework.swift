//
//  CoreFramework.swift
//  True Pass
//
//  Created by Cliff Panos on 4/1/17.
//  Copyright © 2017 Clifford Panos. All rights reserved.
//

import UIKit
import CoreData
import CoreLocation
import WatchConnectivity
import QRCoder


class C: WCActivator {
    
    static var shared = C()
    static var appDelegate: AppDelegate!
    static var storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
    static var session: WCSession?
    
    
    static var nameOfUser: String = "Clifford Panos"
    static var emailOfUser: String = "cliffpanos@gmail.com"
    static var locationName: String = "iOS Club 2017 Demo Day"
    
    
    static var passesActive: Bool = true
    
    static var automaticCheckIn: Bool = true
    
    static var truePassLocations: [TPLocation] = [] /*{
        get {
            let managedContext = C.appDelegate.persistentContainer.viewContext
            let fetchRequest: NSFetchRequest<TPLocation> = TPLocation.fetchRequest()
            
            if let locations = try? managedContext.fetch(fetchRequest) {
                return locations
            }
            return [TPLocation]()
        }
    }*/
    
    static var nearestTruePassLocations: [TPLocation] {
        
        guard (CLLocationManager.authorizationStatus() == .authorizedAlways || CLLocationManager.authorizationStatus() == .authorizedWhenInUse) && CLLocationManager.locationServicesEnabled() else { return truePassLocations }
        
        guard let userLocation = GeoLocationManager.sharedLocationManager.location else { return truePassLocations }
        
        var locationsAndDistances = [TPLocation: Double]()
        for location in truePassLocations {
            let distance = userLocation.distance(from: CLLocation(latitude: location.latitude, longitude: location.longitude))
            locationsAndDistances[location] = distance
        }
        
        let sortedLocations = truePassLocations.sorted { l1, l2 in
            locationsAndDistances[l1]! > locationsAndDistances[l2]!
        }
        return sortedLocations
    }

    static var passes: [Pass] {
        get {
            let managedContext = C.appDelegate.persistentContainer.viewContext
            let fetchRequest: NSFetchRequest<Pass> = Pass.fetchRequest()
            
            if let passes = try? managedContext.fetch(fetchRequest) {
                return passes
            }

            return [Pass]()
        }
    }
    
    
    
    static var userIsLoggedIn: Bool {
        get {
            if let loggedIn = Shared.defaults.value(forKey: "userIsLoggedIn") as? Bool {
                return loggedIn
            }
            return false
        }
        set {
            print("User is logging \(newValue ? "in" : "out")---------------")
            Shared.defaults.setValue(newValue, forKey: "userIsLoggedIn")
            Shared.defaults.synchronize()
            try? C.session?.updateApplicationContext([WCD.signInStatus : newValue])
        }
    }

    
    
    //MARK: - Handle Guest Pass Functionality with Core Data
    
    static func save(pass: Pass?, withName name: String, andEmail email: String, andImage imageData: Data?, from startTime: Date, to endTime: Date) -> Bool {
        
        let managedContext = C.appDelegate.persistentContainer.viewContext
        
        let pass = pass ?? Pass(context: managedContext)
        
        pass.name = name
        pass.email = email
        pass.timeStart = C.format(date: startTime)
        pass.timeEnd = C.format(date: endTime)
        
        if let data = imageData, let image = UIImage(data: data) {
            print("OLD IMAGE SIZE: \(data.count)")
            let resizedImage = image.drawAspectFill(in: CGRect(x: 0, y: 0, width: 240, height: 240))
            let reducedData = UIImagePNGRepresentation(resizedImage)
            print("NEW IMAGE SIZE: \(reducedData!.count)")

            pass.image = data as NSData
        }
        
        defer {
            let passData = C.preparedData(forPass: pass)
            let newPassInfo = [WCD.KEY: WCD.singleNewPass, WCD.passPayload: passData] as [String : Any]
            C.session?.transferUserInfo(newPassInfo)
        }
        
        return C.appDelegate.saveContext()
        
    }
    
    static func delete(pass: Pass, andInformWatchKitApp sendMessage: Bool = true) -> Bool {
        
        let data = C.preparedData(forPass: pass, includingImage: false)   //Do NOT include image
        
        let managedContext = C.appDelegate.persistentContainer.viewContext
        managedContext.delete(pass)
        
        defer {
        if sendMessage {
            let deletePassInfo = [WCD.KEY: WCD.deletePass, WCD.passPayload: data] as [String : Any]
            C.session?.transferUserInfo(deletePassInfo)
        }
        }
        
        if let vc = UIWindow.presented.viewController as? PassDetailViewController {
            vc.navigationController?.popViewController(animated: true)
        }
    
        return C.appDelegate.saveContext()
        
    }
    
    static func preparedData(forPass pass: Pass, includingImage: Bool = true) -> Data {
        
        var dictionary = pass.dictionaryWithValues(forKeys: ["name", "email", "timeStart", "timeEnd"])
        
        if includingImage, let imageData = pass.image as Data?, let image = UIImage(data: imageData) {
            
            let res = 60.0
            let resizedImage = image.drawAspectFill(in: CGRect(x: 0, y: 0, width: res, height: res))
            let reducedData = UIImagePNGRepresentation(resizedImage)
            
            print("Contact Image Message Size: \(reducedData?.count ?? 0)")
            dictionary["image"] = reducedData
            
        } else {
            dictionary["image"] = nil
        }
        
        return NSKeyedArchiver.archivedData(withRootObject: dictionary)   //Binary data
        
    }
    
    static func format(date: Date) -> String {
        
        let stringVersion = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
        
        return stringVersion
        
    }
    
    
    //MARK: - QR Code handling
    
    static func share(image: UIImage, in viewController: UIViewController, popoverSetup: @escaping (UIPopoverPresentationController) -> Void) {
        
        let shareItems: [Any] = [image]
        let activityViewController = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
        activityViewController.excludedActivityTypes = [UIActivityType.print, UIActivityType.postToWeibo, UIActivityType.addToReadingList, UIActivityType.postToVimeo]
        activityViewController.setValue("True Pass", forKey: "Subject")
        //activityViewController.setValue("cliffpanos@gmail.com", forKey: "email")
        
        UIAlert.setupPopoverPresentation(for: activityViewController, popoverSetup: popoverSetup)
        
        viewController.present(activityViewController, animated: true, completion: nil)
        
    }
    
    static func userQRCodePass(forLocation location: TPLocation, withSize size: CGSize?) -> UIImage {
        return C.generateQRCode(forMessage:
            "\(C.nameOfUser)|" +
            "\(C.emailOfUser)|" +
            "\(C.locationName)"
            //Add in things specific to the location
            , withSize: size)
    }
    
    internal static func generateQRCode(forMessage message: String, withSize size: CGSize?) -> UIImage {
        
        let bounds = size ?? CGSize(width: 275, height: 275)
        let generator = QRCodeGenerator()
        let image: QRImage = generator.createImage(value: message, size: bounds)!
        return image as UIImage
    }
    
    
    static func persistUsingUserDefaults(_ value: Any?, for keyString: String) {
        
        let defaults = UserDefaults.standard
        defaults.set(value, forKey: keyString)
        defaults.synchronize()
    
    }
    
    static func getFromUserDefaults(withKey keyString: String) -> Any? {
        
        let defaults = UserDefaults.standard
        if let value = defaults.object(forKey: keyString) {
            return value
        }
        
        return nil
    }
    
    
    
    
    
    
    
    
    
    
    
}
