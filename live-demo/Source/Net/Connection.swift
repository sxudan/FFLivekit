//
//  Connection.swift
//  live-demo
//
//  Created by xkal on 10/3/2024.
//

import Foundation

class Connection {
    
    let fileType: String!
    let baseUrl: String!
    
    init(fileType: String, baseUrl: String) {
        self.fileType = fileType
        self.baseUrl = baseUrl
    }
}
