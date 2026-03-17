//
//  NSData+Hex.swift
//  INSCameraSDK
//
//  Created by zeng bin on 5/6/17.
//  Copyright © 2017 insta360. All rights reserved.
//

import Foundation

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
    
    func shortDescription() -> String {
        let length = 64;
        
        if self.count <= 2 * length {
            return "length: \(self.count)\n\(self.hexEncodedString())"
        }
        
        let start = 0;
        let ends = self.count - length
        return ( "length: \(self.count)\n"
            + self.subdata(in: start ..< (start + length)).hexEncodedString()
            + "\n...\n"
            + self.subdata(in: ends ..< (ends + length)).hexEncodedString())
    }
}
