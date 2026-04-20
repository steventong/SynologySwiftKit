//

//  SynologySwiftKit
//
//  Created by Steven on 2024/10/4.
//

import Foundation

public struct FileDeletionTask: Sendable {
    public let taskID: String

    public init(taskID: String) {
        self.taskID = taskID
    }
}

extension FileStationClient {
    struct DeleteTask: Decodable {
        var taskid: String?
    }
}
