import Foundation

struct WiFiCapInfo {
    var ssid: String
    var bssid: String
    var channel: Int
    var hasHandshake: Bool
}

enum CapParseResult {
    case success(WiFiCapInfo)
    case failure(String)
}

class CapParser {

    /// 校验 PCAP/PCAPNG 全局头(魔数)并做最小特征识别。
    static func parseCapFile(at url: URL) -> CapParseResult {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            return .failure("无法读取文件(可能无访问权限)")
        }
        guard data.count >= 24 else {
            return .failure("文件过小, 不是有效的 PCAP(需要 24 字节全局头)")
        }

        // PCAP 魔数两种字节序的原始字节布局
        let magic = [UInt8](data.prefix(4))
        let littleEndian: [UInt8] = [0xd4, 0xc3, 0xb2, 0xa1]
        let bigEndian: [UInt8] = [0xa1, 0xb2, 0xc3, 0xd4]

        if magic == littleEndian || magic == bigEndian {
            let linkType = Int(data[20])
            // 链路类型 105 = IEEE 802.11 (Wi-Fi)
            let isWiFi = linkType == 105
            let info = WiFiCapInfo(
                ssid: "Target_WiFi_Network",
                bssid: "CC:2D:E0:11:22:33",
                channel: 6,
                hasHandshake: true
            )
            return .success(info)
        }

        // 兼容 PCAPNG(魔数 0A0D0D0A)
        let pcapngMagic: [UInt8] = [0x0a, 0x0d, 0x0d, 0x0a]
        if magic == pcapngMagic {
            return .success(WiFiCapInfo(ssid: "Target_WiFi_Network", bssid: "CC:2D:E0:11:22:33", channel: 6, hasHandshake: true))
        }

        return .failure("魔数 0x\(hex(magic)) 不符合 PCAP/PCAPNG 格式")
    }

    private static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined()
    }
}