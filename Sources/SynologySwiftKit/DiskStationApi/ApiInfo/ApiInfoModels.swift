//
//
//
//  Created by Steven on 2024/4/27.
//

import Foundation

public struct ApiInfoNode: Codable, Sendable {
    public let path: String
    
    public let minVersion: Int
    public let maxVersion: Int
    
    public let requestFormat: String?
}
