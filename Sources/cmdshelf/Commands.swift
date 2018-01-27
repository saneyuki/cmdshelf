//
//  Commands.swift
//  cmdshelfPackageDescription
//
//  Created by Toshihiro Suzuki on 2018/01/27.
//

import Foundation
import Reporter

protocol Command {
    static func run(_ parser: ArgumentParser) throws
}

final class BlobCommand: Command {

    enum SubCommand: String {
        case list, add, remove
    }

    static func run(_ parser: ArgumentParser) throws {
        guard let string = parser.shift(),
            let subCommand = RemoteCommand.SubCommand(rawValue: string) else {
                throw CmdshelfError("Invalid arguments. Pass a correct arguments for `remote`.")
        }

        switch subCommand {
        case .list:
            let config = try Configuration()
            queuedPrintln(config.cmdshelfYml.blobs.map { "\($0.name): \($0.url ?? $0.localPath!)" }.joined(separator: "\n"))

        case .add:
            guard let name = parser.shift(), let url = parser.shift() else {
                throw CmdshelfError("Invalid arguments. Pass a correct arguments for `remote add`.")
            }

            let config = try Configuration()
            if fm.fileExists(atPath: url) {
                var path = url.standardizingPath
                if !url.starts(with: "/") {
                    path = "\(fm.currentDirectoryPath)/\(path)"
                }
                config.cmdshelfYml.blobs.append(Blob(name: name, localPath: path))
            } else {
                config.cmdshelfYml.blobs.append(Blob(name: name, url: url))
            }

        case .remove:
            guard let name = parser.shift() else {
                throw CmdshelfError("Invalid arguments. Pass a correct arguments for `remote remove`.")
            }
            let config = try Configuration()
            config.cmdshelfYml.removeBlob(name: name)

        }
    }
}

final class CatCommand: Command {
    static func run(_ parser: ArgumentParser) throws {
        let aliases = try VaradicAliasArgument().parse(parser)

        if aliases.isEmpty {
            exit(shellOut(to: "cat"))

        } else {

            let config = try Configuration()
            config.cloneRemotesIfNeeded()

            var failure = false

            for alias in aliases {

                // Search in blobs and remote
                guard let context = config.getContexts(for: alias.alias, remoteName: alias.remoteName).first else {
                    queuedPrintlnError(Message.noSuchCommand(alias.originalValue))
                    failure = true
                    continue
                }

                if context.location.hasPrefix("curl ") {
                    if shellOut(to: context.location) > 0 {
                        failure = true
                    }

                } else {
                    if shellOut(to: "cat \(context.location)") > 0 {
                        failure = true
                    }
                }
            }
            if failure {
                throw CmdshelfError()
            }
        }
    }
}

final class HelpCommand: Command {
    static func run(_ parser: ArgumentParser) throws {
        if parser.remainder.isEmpty {
            if spawnPager(cmdString: "man cmdshelf") != 0 {
                queuedPrintln(SubCommand.help.helpMessage)
            }
            return
        }
        let subCommand = try SubCommandArgument().parse(parser)
        if subCommand.possiblyHasManPage {
            if spawnPager(cmdString: "man cmdshelf-\(subCommand.rawValue)") != 0 {
                queuedPrintln(subCommand.helpMessage)
            }
        } else {
            queuedPrintln(subCommand.helpMessage)
        }
    }
}

final class ListCommand: Command {
    static func run(_ parser: ArgumentParser) throws {
        let isPath = parser.shift() == "--path"
        let config = try Configuration()
        try config.printAllCommands(displayType: isPath ? .absolutePath : .alias)
    }
}

final class RunCommand: Command {
    static func run(_ parser: ArgumentParser) throws {
        let aliasParam = try AliasParameterArgument().parse(parser)

        let config = try Configuration()
        let alias = aliasParam.alias.alias
        let remoteName = aliasParam.alias.remoteName
        let parameters = aliasParam.parameters

        // Search in blobs and remote
        guard let context = config.getContexts(for: alias, remoteName: remoteName).first else {
            queuedPrintlnError(Message.noSuchCommand(aliasParam.alias.originalValue))
            throw CmdshelfError()
        }

        let singleQuoted = parameters.map { "\'\($0)\'" }.joined(separator: " ")
        if context.location.hasPrefix("curl ") {
            exit(shellOut(to: "bash <(\(context.location))", argument: singleQuoted))
        } else {
            exit(shellOut(to: context.location, argument: singleQuoted))
        }
    }
}

final class RemoteCommand: Command {

    enum SubCommand: String {
        case list, add, remove
    }

    static func run(_ parser: ArgumentParser) throws {
        guard let string = parser.shift(),
            let subCommand = RemoteCommand.SubCommand(rawValue: string) else {
                throw CmdshelfError("Invalid arguments. Pass a correct arguments for `remote`.")
        }

        switch subCommand {
        case .list:
            let config = try Configuration()
            queuedPrintln(config.cmdshelfYml.remotes.map { "\($0.name): \($0.url)" }.joined(separator: "\n"))

        case .add:
            guard let name = parser.shift(), let url = parser.shift() else {
                throw CmdshelfError("Invalid arguments. Pass a correct arguments for `remote add`.")
            }
            let config = try Configuration()
            config.cmdshelfYml.remotes.append(Repository(name: name, url: url, tag: nil, branch: nil))

        case .remove:
            guard let name = parser.shift() else {
                throw CmdshelfError("Invalid arguments. Pass a correct arguments for `remote remove`.")
            }
            let config = try Configuration()
            config.cmdshelfYml.removeRemote(name: name)

        }
    }
}

final class UpdateCommand: Command {
    static func run(_ parser: ArgumentParser) throws {
        let config = try Configuration()
        config.cloneRemotesIfNeeded()
        config.updateRemotes()
    }
}