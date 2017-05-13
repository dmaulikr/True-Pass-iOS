//
//  Pass.swift
//  True Pass
//
//  Created by Cliff Panos on 5/12/17.
//  Copyright © 2017 Clifford Panos. All rights reserved.
//

import Foundation

class Pass: Equatable {
    var name: String!
    var email: String?
    var image: Data!
    var timeEnd: String!
    var timeStart: String!
    
    static func == (p1: Pass, p2: Pass) -> Bool {
        
        //== cannot compare the image data because the WCD.deletePass does not send the image data
        let condition = p1.name == p2.name && p1.email == p2.email && p1.timeStart == p2.timeStart && p1.timeEnd == p2.timeEnd
        return condition
    }
    
}
