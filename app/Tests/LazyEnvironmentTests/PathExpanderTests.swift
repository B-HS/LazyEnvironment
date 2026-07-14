import Foundation
import Testing
@testable import LazyEnvironment

struct PathExpanderTests {
    @Test
    func expandsLeadingTilde() {
        let expander = PathExpander(devHome: "/opt/dev")
        #expect(expander.expand("~/development") == NSHomeDirectory() + "/development")
    }

    @Test
    func expandsHomeToken() {
        let expander = PathExpander(devHome: "/opt/dev")
        let home = NSHomeDirectory()
        #expect(expander.expand("$HOME/bin") == home + "/bin")
        #expect(expander.expand("${HOME}/bin") == home + "/bin")
    }

    @Test
    func expandsDevHomeToken() {
        let expander = PathExpander(devHome: "/opt/dev")
        #expect(expander.expand("$DEV_HOME/tools") == "/opt/dev/tools")
        #expect(expander.expand("${DEV_HOME}/tools") == "/opt/dev/tools")
    }

    @Test
    func expandsDevHomeGivenAsTilde() {
        let expander = PathExpander(devHome: "~/workspace")
        let home = NSHomeDirectory()
        #expect(expander.expandedDevHome == home + "/workspace")
        #expect(expander.expand("$DEV_HOME/bin") == home + "/workspace/bin")
        #expect(expander.expand("${DEV_HOME}/bin") == home + "/workspace/bin")
    }

    @Test
    func expandsEnvironmentValues() {
        let expander = PathExpander(devHome: "/opt/dev")
        let home = NSHomeDirectory()
        let expanded = expander.expandEnvironment([
            "TOOLS": "$DEV_HOME/tools",
            "CACHE": "${HOME}/.cache",
            "PLAIN": "static-value",
        ])
        #expect(expanded["TOOLS"] == "/opt/dev/tools")
        #expect(expanded["CACHE"] == home + "/.cache")
        #expect(expanded["PLAIN"] == "static-value")
    }

    @Test
    func leavesPathsWithoutTokensUnchanged() {
        let expander = PathExpander(devHome: "/opt/dev")
        #expect(expander.expand("/usr/local/bin") == "/usr/local/bin")
        #expect(expander.expand("plain-string") == "plain-string")
    }
}
