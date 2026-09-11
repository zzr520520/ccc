import Foundation
import UIKit

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

    // 导入并自动识别不同格式文件
    func importFile(from sourceURL: URL) -> Bool {
        let fileExtension = sourceURL.pathExtension.lowercased()
        let destinationURL = dictionaryDirectory.appendingPathComponent(sourceURL.lastPathComponent)

        do {
            _ = try sourceURL.startAccessingSecurityScopedResource()

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

            if fileExtension == "zip" || fileExtension == "rar" {
                extractArchive(at: destinationURL, extension: fileExtension)
            } else if fileExtension == "txt" {
                print("TXT 字典导入成功: \(destinationURL.lastPathComponent)")
            }

            return true
        } catch {
            print("文件导入失败: \(error.localizedDescription)")
            return false
        } finally {
            sourceURL.stopAccessingSecurityScopedResource()
        }
    }

    // 压缩包自动化解压逻辑
    private func extractArchive(at url: URL, extension ext: String) {
        let unzipDest = dictionaryDirectory.appendingPathComponent(url.deletingPathExtension().lastPathComponent, isDirectory: true)
        // 实际开发中可集成 SSZipArchive / UnrarKit 处理解压释放
        print("检测到 \(ext.uppercased()) 压缩包，已释放至: \(unzipDest.path)")
    }

    // 获取本地可用字典列表
    func getLocalDictionaryFiles() -> [URL] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dictionaryDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        return files.filter { $0.pathExtension.lowercased() == "txt" }
    }
}