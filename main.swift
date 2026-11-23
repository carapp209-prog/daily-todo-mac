import SwiftUI
import AppKit

struct Task: Codable, Identifiable {
    var id = UUID()
    var title: String
    var day: String
    var done = false
    var duration: String?
}
func dayKey(_ offset: Int = 0) -> String {
    let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
    let p = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", p.year ?? 0, p.month ?? 0, p.day ?? 0)
}
final class Store: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var error = ""
    private var readable = true
    let file = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/DailyTodo/tasks.json")
    init() {
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        do { tasks = try JSONDecoder().decode([Task].self, from: Data(contentsOf: file)) }
        catch { readable = false; self.error = "无法读取已保存的待办。" }
    }
    @discardableResult func save(_ next: [Task]) -> Bool {
        guard readable else { return false }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(next).write(to: file, options: .atomic)
            tasks = next
            error = ""
            return true
        } catch {
            self.error = "保存失败，请检查本机存储权限。"
            return false
        }
    }
    func change(_ id: UUID, _ update: (inout Task) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        var next = tasks
        update(&next[index])
        save(next)
    }
}
struct TodoView: View {
    @StateObject private var store = Store()
    @State private var page: Int? = 0
    @State private var todayText = ""
    @State private var tomorrowText = ""
    @State private var clock = Date()
    @AppStorage("todayScratchpad") private var scratchpad = ""
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    let names = ["今天", "明天", "回顾"]
    var body: some View {
        NavigationSplitView {
            List(selection: $page) {
                Section("待办列表") {
                    Label("今天", systemImage: "calendar").tag(0)
                    Label("明天", systemImage: "calendar.badge.plus").tag(1)
                    Label("回顾", systemImage: "clock.arrow.circlepath").tag(2)
                }
            }.listStyle(.sidebar).navigationSplitViewColumnWidth(155)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    let index = page ?? 0
                    let today = dayKey()
                    let tasks = store.tasks.filter { $0.day <= today && (!$0.done || $0.day == today) }
                    let done = tasks.filter(\.done).count
                    HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            if index < 2 {
                                let date = Calendar.current.date(byAdding: .day, value: index, to: clock) ?? clock
                                Text(date.formatted(.dateTime.month().day().weekday().locale(Locale(identifier: "zh_CN"))))
                                    .foregroundStyle(.secondary)
                            }
                            Text(names[index]).font(.system(size: 32, weight: .bold))
                            if index == 0 && !tasks.isEmpty {
                                Text(done == tasks.count ? "今日已收工" : "已完成 \(done) / \(tasks.count)")
                                    .foregroundStyle(.secondary)
                                ProgressView(value: Double(done), total: Double(tasks.count)).frame(maxWidth: 240)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if index == 0 {
                            ZStack(alignment: .topLeading) {
                                if scratchpad.isEmpty {
                                    Text("写点什么…").foregroundStyle(.secondary)
                                        .padding(9).allowsHitTesting(false)
                                }
                                TextEditor(text: $scratchpad).scrollContentBackground(.hidden)
                                    .padding(4).accessibilityLabel("自由书写区")
                            }
                            .frame(maxWidth: .infinity).frame(height: 94)
                            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    if index == 0 {
                        addRow("临时想到一件事？", text: $todayText, offset: 0)
                        ForEach(tasks) { task in
                            HStack(spacing: 10) {
                                Toggle(isOn: Binding(get: { task.done }, set: { value in
                                    store.change(task.id) { $0.done = value; $0.day = dayKey() }
                                })) {
                                    Text(task.title).padding(.horizontal, 3)
                                        .background(alignment: .bottomLeading) {
                                            if task.done {
                                                RoundedRectangle(cornerRadius: 2).fill(.yellow.opacity(0.85))
                                                    .frame(height: 9).rotationEffect(.degrees(-1))
                                            }
                                        }
                                        .foregroundStyle(task.done ? Color.black : Color.primary)
                                        .animation(.easeOut(duration: 0.2), value: task.done)
                                }.toggleStyle(.checkbox)
                                Spacer()
                                if task.done {
                                    DurationControl(value: task.duration) { value in
                                        store.change(task.id) { $0.duration = value }
                                    }
                                } else {
                                    Button("移到明天") { store.change(task.id) { $0.day = dayKey(1) } }
                                        .buttonStyle(.borderless).foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    } else if index == 1 {
                        addRow("明天要做什么？", text: $tomorrowText, offset: 1)
                        ForEach(store.tasks.filter { $0.day == dayKey(1) }) { Text($0.title) }
                    } else {
                        let groups = Dictionary(grouping: store.tasks.filter(\.done), by: \.day)
                        if groups.isEmpty { Text("完成的待办会按日期出现在这里。").foregroundStyle(.secondary) }
                        ForEach(groups.keys.sorted(by: >), id: \.self) { day in
                            let tasks = groups[day] ?? []
                            DisclosureGroup("\(day) · 完成 \(tasks.count) 件") {
                                ForEach(tasks) { task in
                                    HStack {
                                        Label(task.title, systemImage: "checkmark")
                                        Spacer()
                                        if let duration = task.duration {
                                            Text(durationLabel(duration)).foregroundStyle(.secondary)
                                        }
                                    }.padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    if !store.error.isEmpty { Text(store.error).foregroundStyle(.red) }
                }
                .frame(maxWidth: 680, alignment: .leading).padding(28)
                .frame(maxWidth: .infinity)
            }
        }
        .fontWeight(.bold)
        .frame(minWidth: 580, minHeight: 400)
        .onReceive(timer) { clock = $0 }
    }
    func addRow(_ placeholder: String, text: Binding<String>, offset: Int) -> some View {
        HStack {
            TextField(placeholder, text: text).textFieldStyle(.plain)
                .padding(9).background(.quaternary, in: RoundedRectangle(cornerRadius: 9))
                .onSubmit { add(text, offset) }
            Button { add(text, offset) } label: {
                Label("添加", systemImage: "plus")
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))
            }.buttonStyle(.plain).foregroundStyle(Color.accentColor)
        }.padding(.bottom, 4)
    }
    func add(_ text: Binding<String>, _ offset: Int) {
        let title = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        if store.save([Task(title: title, day: dayKey(offset))] + store.tasks) {
            text.wrappedValue = ""
        }
    }
}
func durationLabel(_ value: String) -> String {
    let normalized = value.precomposedStringWithCompatibilityMapping
        .replacingOccurrences(of: #"\s*[:∶;]\s*"#, with: ":", options: .regularExpression)

    let pattern = #"^\s*([01]?[0-9]|2[0-3]):([0-5][0-9])\s*[-–—−~至]\s*([01]?[0-9]|2[0-3]):([0-5][0-9])\s*$"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized))
    else { return "用时 " + value }
    let parts = (1...4).compactMap { index in
        Range(match.range(at: index), in: normalized).flatMap { Int(normalized[$0]) }
    }
    guard parts.count == 4 else { return "用时 " + value }
    let start = parts[0] * 60 + parts[1]
    let end = parts[2] * 60 + parts[3]
    let minutes = (end - start + 1440) % 1440
    return String(format: "%d:%02d-%d:%02d %dmin", parts[0], parts[1], parts[2], parts[3], minutes)
}

struct DurationControl: View {
    var value: String?
    var save: (String?) -> Void
    @State private var editing = false
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        Button(value.map(durationLabel) ?? "＋ 记用时") {
            draft = value ?? ""
            editing = true
        }
        .buttonStyle(.borderless)
        .foregroundStyle(Color.accentColor)
        .popover(isPresented: $editing, arrowEdge: .bottom) {
            HStack {
                TextField("如 9:00-9:30", text: $draft)
                    .accessibilityLabel("任务用时")
                    .focused($focused)
                    .onSubmit(commit)
                Button("保存", action: commit)
            }
            .frame(width: 245).padding()
            .onAppear { focused = true }
        }
    }

    func commit() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"(?<=\d:\d{2})\s+\d+\s*min$"#, with: "", options: .regularExpression)
        save(text.isEmpty ? nil : text)
        editing = false
    }
}

@main struct DailyTodo: App {
    var body: some Scene { WindowGroup("每日待办") { TodoView() } }
}
