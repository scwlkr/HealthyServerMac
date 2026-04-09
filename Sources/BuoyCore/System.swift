import Foundation

public protocol CommandRunning {
    func run(
        executable: String,
        arguments: [String],
        environment: [String: String]?,
        interactive: Bool,
        allowNonZeroExit: Bool
    ) throws -> CommandOutput

    func runDetached(
        executable: String,
        arguments: [String],
        environment: [String: String]?
    ) throws -> Int32
}

public extension CommandRunning {
    func run(
        executable: String,
        arguments: [String],
        environment: [String: String]? = nil,
        interactive: Bool = false,
        allowNonZeroExit: Bool = false
    ) throws -> CommandOutput {
        try run(
            executable: executable,
            arguments: arguments,
            environment: environment,
            interactive: interactive,
            allowNonZeroExit: allowNonZeroExit
        )
    }
}

public final class SystemCommandRunner: CommandRunning {
    public init() {}

    public func run(
        executable: String,
        arguments: [String],
        environment: [String: String]?,
        interactive: Bool,
        allowNonZeroExit: Bool
    ) throws -> CommandOutput {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        if let environment {
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        if interactive {
            process.standardInput = FileHandle.standardInput
            process.standardOutput = FileHandle.standardOutput
            process.standardError = FileHandle.standardError
        } else {
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
        }

        do {
            try process.run()
        } catch {
            throw BuoyError.missingExecutable("Unable to run \(executable): \(error.localizedDescription)")
        }

        process.waitUntilExit()

        let stdout: String
        let stderr: String

        if interactive {
            stdout = ""
            stderr = ""
        } else {
            stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        }

        if process.terminationStatus != 0 && !allowNonZeroExit {
            let details = stderr.isEmpty ? stdout : stderr
            throw BuoyError.commandFailed(details.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return CommandOutput(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus)
    }

    public func runDetached(
        executable: String,
        arguments: [String],
        environment: [String: String]?
    ) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        if let environment {
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        }

        do {
            try process.run()
        } catch {
            throw BuoyError.missingExecutable("Unable to run \(executable): \(error.localizedDescription)")
        }

        return process.processIdentifier
    }
}

public enum ShellProfiles {
    public static func rcFile(shellPath: String = ProcessInfo.processInfo.environment["SHELL"] ?? "") -> URL {
        let shellName = URL(fileURLWithPath: shellPath).lastPathComponent
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)

        switch shellName {
        case "zsh":
            let zdotdir = ProcessInfo.processInfo.environment["ZDOTDIR"] ?? NSHomeDirectory()
            return URL(fileURLWithPath: zdotdir, isDirectory: true).appendingPathComponent(".zshrc")
        case "bash":
            let bashrc = home.appendingPathComponent(".bashrc")
            if FileManager.default.fileExists(atPath: bashrc.path) {
                return bashrc
            }
            return home.appendingPathComponent(".bash_profile")
        default:
            return home.appendingPathComponent(".profile")
        }
    }
}
