import Foundation
import Testing
@testable import LazyEnvironment

struct ShellRunnerTests {
    private func makeCommand(_ script: String, environment recipeEnvironment: [String: String] = [:]) -> ResolvedCommand {
        var environment = ["PATH": "/usr/bin:/bin"]
        environment.merge(recipeEnvironment) { _, new in new }
        return ResolvedCommand(script: script, environment: environment, recipeEnvironment: recipeEnvironment, interactive: false)
    }

    @Test
    func capturesStdout() async {
        let result = await ShellRunner().capture(makeCommand("echo hello"))
        #expect(result.stdout == "hello")
        #expect(result.stderr.isEmpty)
        #expect(result.exitCode == 0)
    }

    @Test
    func routesStderrOutputToStderr() async {
        let result = await ShellRunner().capture(makeCommand("echo oops >&2"))
        #expect(result.stderr == "oops")
        #expect(result.stdout.isEmpty)
        #expect(result.exitCode == 0)
    }

    @Test
    func propagatesExitCode() async {
        let result = await ShellRunner().capture(makeCommand("exit 7"))
        #expect(result.exitCode == 7)
    }

    @Test
    func exposesRecipeEnvironmentToScript() async {
        let command = makeCommand("echo \"$MY_RECIPE_VAR\"", environment: ["MY_RECIPE_VAR": "recipe-value"])
        let result = await ShellRunner().capture(command)
        #expect(result.stdout == "recipe-value")
        #expect(result.exitCode == 0)
    }

    @Test
    func aggregatesMultiLineOutput() async {
        let result = await ShellRunner().capture(makeCommand("echo a; echo b; echo c"))
        #expect(result.stdout == "a\nb\nc")
        #expect(result.exitCode == 0)
    }

    @Test
    func preservesTrailingOutputWithoutNewline() async {
        let result = await ShellRunner().capture(makeCommand("printf '%s' trailing-no-newline"))
        #expect(result.stdout == "trailing-no-newline")
        #expect(result.exitCode == 0)
    }
}
