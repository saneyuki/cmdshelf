import Commander
import Foundation
import Reporter

struct Alias {
    let alias: String
    let remoteName: String?
    let originalValue: String
}

private class AliasParser {
    static func parse(_ string: String) -> Alias? {
        guard !string.isEmpty else {
            return nil
        }
        // Get "remote:my/script" part.
        // `"".components(separatedBy: " ").count` is 1, so force unwrap.
        let _alias  = string.components(separatedBy: " ").first!
        let alias: String
        let remoteName: String?
        if _alias.contains(":") {
            remoteName = _alias.components(separatedBy: ":").first!
            alias = _alias.components(separatedBy: ":").dropFirst().joined()
        } else {
            alias = _alias
            remoteName = nil
        }
        return Alias(alias: alias, remoteName: remoteName, originalValue: _alias)
    }
}

struct VaradicAliasArgument: ArgumentDescriptor {
    typealias ValueType = [Alias]
    let name: String = "[\(Message.COMMAND) ...]"
    let description: String? = nil
    let type: ArgumentType = .argument
    func parse(_ parser: ArgumentParser) throws -> ValueType {
        return parser.shiftAll().flatMap(AliasParser.parse)
    }
}

struct AliasParameterArgument: ArgumentDescriptor {
    typealias ValueType = (alias: Alias, parameter: String?)
    let name: String = "\"\(Message.COMMAND) [parameter ...]\""
    let description: String? = nil
    let type: ArgumentType = .argument
    func parse(_ parser: ArgumentParser) throws -> ValueType {
        guard let string = parser.shiftArgument() else {
            throw ArgumentError.missingValue(argument: name)
        }
        let splitted = string.split(separator: " ")
        guard let alias = AliasParser.parse(String(splitted.first!)) else {
            throw ArgumentError.missingValue(argument: "COMMAND")
        }
        return (alias, (splitted.dropFirst().map(String.init) + parser.shiftAll()).joined(separator: " "))
    }
}

struct SubCommandArgument: ArgumentDescriptor {

    typealias ValueType = SubCommand?

    let name: String = "\"[subcommand]\""
    let description: String? = "A SubCommand of cmdshelf e.g. \"run\""
    let type: ArgumentType = .argument

    func parse(_ parser: ArgumentParser) throws -> ValueType {
        if let string = parser.shiftArgument() {
            if let subCommand = SubCommand(rawValue: string) {
                return subCommand
            } else {
                throw ArgumentError.invalidType(value: string, type: "SubCommand", argument: nil)
            }
        } else {
            return nil
        }
    }
}

enum SubCommand: String {
    case run, list, remote, blob, cat, update, help
}

struct SubCommandConvertibleArgument: ArgumentDescriptor {

    typealias ValueType = (SubCommand, parser: ArgumentParser)?

    let name: String = "\"\(Message.COMMAND) [parameter ...]\""
    let description: String? = nil
    let type: ArgumentType = .argument

    func parse(_ parser: ArgumentParser) throws -> ValueType {
        if let string = parser.shift() {
            if let subCommand = SubCommand(rawValue: string) {
                return (subCommand, parser)
            } else {
                throw ArgumentError.invalidType(value: string, type: "SubCommand", argument: nil)
            }
        } else {
            return nil
        }
    }
}

// MARK: - Commander extension
extension ArgumentParser {
    func shiftAll() -> [String] {
        let _remainder = remainder
        for _ in remainder {
            _ = shift()
        }
        return _remainder
    }
}
