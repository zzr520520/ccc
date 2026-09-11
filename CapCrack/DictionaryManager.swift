import Foundation
import UIKit
import Zip

class DictionaryManager {
    static let shared = DictionaryManager()

    // 获取沙盒 Document 目录下的本地持久化字典路径
    var dictionaryDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("Dictionaries", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        return dir
    }

    /// 把选中的文件安全地导入到 Document/Dictionaries 沙盒。
    /// 处理 security-scoped 访问, 对 .zip 自动解压并回收其中的 TXT 字典。
    /// 返回 (导入后的目录/文件 URL(统一为目录), 提示文案)。
    @discardableResult
    func importFile(from sourceURL: URL) -> (url: URL?, message: String) {
        let fileExtension = sourceURL.pathExtension.lowercased()

        // 统一目标: 用一个以文件名(去扩展名)命名的目录收纳内容
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let destDir = dictionaryDirectory.appendingPathComponent("\(baseName)/", isDirectory: true)

        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if didAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        do {
            if FileManager.default.fileExists(atPath: destDir.path) {
                try FileManager.default.removeItem(at: destDir)
            }
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true, attributes: nil)

            switch fileExtension {
            case "zip":
                // 真实解压
                try Zip.unzipFile(sourceURL, destination: destDir, overwrite: true, password: nil)
                let txtCount = txtFiles(in: destDir).count
                return (destDir, "ZIP 已解压到沙盒, 含 \(txtCount) 个 TXT 字典")

            case "rar":
                // RAR 需 UnrarKit 等第三方库, 这里先把原始包复制进沙盒
                let target = destDir.appendingPathComponent(sourceURL.lastPathComponent)
                try FileManager.default.copyItem(at: sourceURL, to: target)
                return (destDir, "RAR 已导入沙盒(解压需集成 UnrarKit)")

            default:
                // TXT 及其它文本直接复制
                let target = destDir.appendingPathComponent(sourceURL.lastPathComponent)
                try FileManager.default.copyItem(at: sourceURL, to: target)
                return (destDir, "文件已导入沙盒")
            }
        } catch {
            return (nil, "导入失败: \(error.localizedDescription)")
        }
    }

    /// 在某目录(或其内层目录)里寻找所有 TXT 文件
    func txtFiles(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: dictionaryDirectory,
            includingPropertiesForKeys: nil
        ) else { return [] }
        var result: [URL] = []
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension.lowercased() == "txt" {
                result.append(fileURL)
            }
        }
        return result
    }

    /// 获取沙盒里现有的所有文本字典路径
    func getLocalDictionaryFiles() -> [URL] {
        return txtFiles(in: dictionaryDirectory)
    }

    /// 读取任意目录/文件里的首个可读 TXT 字典(用于装载进引擎)
    func firstUsableDictionaryURL(afterImport url: URL?) -> URL? {
        guard let url = url else { return nil }
        var files: [URL] = []
        if FileManager.default.fileExists(atPath: url.path) {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                files = txtFiles(in: url)
            } else if url.pathExtension.lowercased() == "txt" {
                files = [url]
            }
        }
        return files.first
    }
}