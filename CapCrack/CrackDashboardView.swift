import SwiftUI
import Foundation

// 统计子卡片组件
struct MetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.body, design: .rounded))
                .bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// 完整的跑字典管理及控制视图
struct CrackDashboardView: View {
    @State private var state = CrackProgressState(
        currentPassword: "等待加载字典...",
        processedCount: 0,
        totalCount: 100000,
        speedPerSecond: 0
    )
    @State private var isRunning = false
    @State private var timer: Timer?

    @State private var capInfo: WiFiCapInfo?
    @State private var showingCapPicker = false
    @State private var showingDictPicker = false
    @State private var alertMessage: String?
    @State private var showingAlert = false

    private let engine = CrackEngine()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 顶部核心监控卡片
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Circle()
                            .fill(isRunning ? Color.green : Color.orange)
                            .frame(width: 10, height: 10)
                        Text(isRunning ? "正在本地运行..." : "已暂停 / 就绪")
                            .font(.headline)
                    }

                    if let cap = capInfo {
                        Text("目标: \(cap.ssid)  BSSID: \(cap.bssid)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Text("当前尝试: \(state.currentPassword)")
                        .font(.system(.subheadline, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    ProgressView(value: state.percentage)
                        .tint(.blue)

                    HStack {
                        Text(String(format: "进度: %.2f%%", state.percentage * 100))
                        Spacer()
                        Text("速度: \(state.speedPerSecond) key/s")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)

                // 详细指标网格
                HStack(spacing: 12) {
                    MetricCard(
                        title: "已处理 / 总数",
                        value: "\(state.processedCount) / \(state.totalCount)"
                    )
                    MetricCard(
                        title: "剩余数量",
                        value: "\(max(0, state.totalCount - state.processedCount))"
                    )
                }

                HStack(spacing: 12) {
                    MetricCard(
                        title: "预计剩余时间",
                        value: formatTime(seconds: state.remainingSeconds)
                    )
                    MetricCard(
                        title: "状态评估",
                        value: state.percentage > 0.5 ? "进行过半" : "正常推进"
                    )
                }

                // 文件导入按钮
                HStack(spacing: 12) {
                    Button(action: { showingCapPicker = true }) {
                        Text(capInfo == nil ? "导入 .cap" : "更换 .cap")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    Button(action: { showingDictPicker = true }) {
                        Text("导入字典")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                }

                // 启动 / 暂停控制按钮
                Button(action: {
                    toggleStartPause()
                }) {
                    Text(isRunning ? "暂停任务" : "开始跑字典")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isRunning ? Color.red : Color.blue)
                        .cornerRadius(10)
                }
                .disabled(!isReady)

                Spacer()
            }
            .padding()
            .navigationTitle("Cap 字典跑包控制台")
            // 用 .item(所有文件) 放宽类型过滤, 否则 .cap/.rar/.zip 等自定义扩展名
            // 在系统文件选择器里会显示为灰色不可选, "导入不了"
            .fileImporter(isPresented: $showingCapPicker, allowedContentTypes: [.item]) { result in
                handleCapImport(result)
            }
            .fileImporter(isPresented: $showingDictPicker, allowedContentTypes: [.item]) { result in
                handleDictImport(result)
            }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("提示"), message: Text(alertMessage ?? ""), dismissButton: .default(Text("好")))
            }
        }
    }

    private var isReady: Bool {
        engine.isLoaded
    }

    private func handleCapImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            switch CapParser.parseCapFile(at: url) {
            case .success(let info):
                capInfo = info
                alertMessage = "已解析 .cap 文件 (链路: Wi-Fi)"
            case .failure(let reason):
                alertMessage = "无法解析: \(reason)"
            }
            showingAlert = true
        case .failure(let error):
            alertMessage = "导入失败: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    private func handleDictImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            // 统一导入: 处理 security-scoped 访问, 对 zip 自动解压, rar/txt 复制进沙盒
            let importResult = DictionaryManager.shared.importFile(from: url)

            guard let dirURL = importResult.url,
                  let dictURL = DictionaryManager.shared.firstUsableDictionaryURL(afterImport: dirURL) else {
                alertMessage = importResult.message.isEmpty
                    ? "导入失败"
                    : "\(importResult.message), 但未找到可用的 TXT 字典"
                showingAlert = true
                return
            }

            if engine.loadDictionary(from: dictURL) {
                state = engine.state
                alertMessage = "\(importResult.message) · 已装载 \(state.totalCount) 条字典"
            } else {
                alertMessage = "\(importResult.message), 但文件无法解析为字典文本"
            }
            showingAlert = true
        case .failure(let error):
            alertMessage = "导入失败: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    private func toggleStartPause() {
        isRunning.toggle()
        if isRunning {
            // 握手验证钩子: 真实场景需在此实现 PMK/PTK 推导比对(留空即全部返回 false)
            let verify: (String) -> Bool = { _ in false }
            timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
                switch engine.progressOneStep(verify: verify) {
                case .exhausted:
                    stopTimer()
                    alertMessage = "字典已遍历完毕,未找到命中项(验证钩子当前为空实现)"
                    showingAlert = true
                case .success(let password):
                    stopTimer()
                    alertMessage = "命中密码: \(password)"
                    showingAlert = true
                case .none:
                    break
                }
                state = engine.state
            }
        } else {
            stopTimer()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        state.speedPerSecond = 0
    }

    private func formatTime(seconds: Int) -> String {
        let hours = seconds / 3600
        let mins = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return "\(hours)时 \(mins)分 \(secs)秒"
        } else if mins > 0 {
            return "\(mins)分 \(secs)秒"
        } else {
            return "\(secs)秒"
        }
    }
}