import Foundation

struct PathExpander: Sendable, Hashable {
    let devHomeRaw: String

    init(devHome: String) {
        self.devHomeRaw = devHome
    }

    var expandedDevHome: String {
        Self.expandHomeOnly(devHomeRaw)
    }

    func expand(_ path: String) -> String {
        var result = path
        result = result.replacingOccurrences(of: "${DEV_HOME}", with: expandedDevHome)
        result = result.replacingOccurrences(of: "$DEV_HOME", with: expandedDevHome)
        return Self.expandHomeOnly(result)
    }

    func expandEnvironment(_ envVars: [String: String]) -> [String: String] {
        envVars.mapValues { expand($0) }
    }

    private static func expandHomeOnly(_ path: String) -> String {
        var result = path
        let home = NSHomeDirectory()
        result = result.replacingOccurrences(of: "${HOME}", with: home)
        result = result.replacingOccurrences(of: "$HOME", with: home)
        return (result as NSString).expandingTildeInPath
    }
}
