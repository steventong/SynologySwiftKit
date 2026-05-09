import Foundation

struct ResolvedApiEndpoint {
    let name: String
    let method: String
    let version: Int
    let parameters: ApiParameters
    let apiPath: String
    let requireAuthCookie: Bool
    let requireAuthQuery: Bool
}
