import Commander
import Foundation
import Reporter

class BlobCommand: Group {
    let name: String = "blob"
    let description: String? = "Manage blob commands (type `cmdshelf blob` for usage)"
    override init() {
        super.init()
        addCommand("list", "Show registered blobs.", Commander.command() {
            let config = try Configuration()
            queuedPrintln(config.cmdshelfYml.blobs.map { "\($0.name): \($0.url ?? $0.localPath!)" }.joined(separator: "\n"))
        })
        addCommand("add", "Add a script URL as a blob.", Commander.command(
            Argument<String>("NAME", description: "command name alias"),
            Argument<String>("URL", description: "script URL")
        ) { (name, url) in
            let config = try Configuration()
            if fm.fileExists(atPath: url) {
                var path: String
                if url.starts(with: "/") {
                    path = url.standardizingPath
                } else {
                    path = "\(url)".standardizingPath
                    if !path.starts(with: "/") {
                        path = "\(fm.currentDirectoryPath)/\(path)"
                    }
                }
                config.cmdshelfYml.blobs.append(Blob(name: name, localPath: path))
            } else {
                config.cmdshelfYml.blobs.append(Blob(name: name, url: url))
            }
        })
        addCommand("remove", "Remove a blob.", Commander.command(
            Argument<String>("NAME", description: "command name alias")
            ) { name in
            let config = try Configuration()
            config.cmdshelfYml.removeBlob(name: name)
        })
    }
}
