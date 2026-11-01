import SwiftUI
import AppKit

struct PocketPanel: View {
    @ObservedObject var model: PocketModel
    private var listHeight: CGFloat {
        CGFloat(min(max(model.filtered.count, 1), 5)) * 45
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Port Pocket").font(.system(size: 13, weight: .semibold))
                Spacer()
                Button { model.refresh() } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 22, height: 22)
                }.buttonStyle(.plain).foregroundStyle(.secondary)
                    .disabled(model.scanning).help("Refresh ports")
                Menu {
                    Toggle("Launch at login", isOn: Binding(get: { model.login }, set: { _ in model.toggleLogin() }))
                    Toggle("Show system services", isOn: $model.showSystem)
                    Divider()
                    Button("About Port Pocket") { about() }
                    Button("Quit Port Pocket") { NSApp.terminate(nil) }
                } label: { Image(systemName: "ellipsis").frame(width: 20, height: 22) }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .accessibilityLabel("Settings")
            }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 10)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(.secondary)
                TextField("Filter ports or processes", text: $model.query)
                    .textFieldStyle(.plain).font(.system(size: 12)).accessibilityLabel("Search ports")
                if !model.query.isEmpty {
                    Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        .buttonStyle(.plain).accessibilityLabel("Clear search")
                }
            }.padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 16).padding(.bottom, 8)

            if let error = model.error {
                HStack(alignment: .top) {
                    Text(error).font(.system(size: 11)).foregroundStyle(.red)
                    Spacer()
                    Button { model.error = nil } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain).accessibilityLabel("Dismiss error")
                }.padding(.horizontal, 16).padding(.bottom, 10)
            }

            HStack(spacing: 14) {
                Text("Port").frame(width: 48, alignment: .leading)
                Text("Process / Project")
                Spacer()
            }.font(.system(size: 10)).foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.bottom, 8)
            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    if model.filtered.isEmpty {
                        VStack(spacing: 6) {
                            Text(model.scanning ? "Scanning…" : model.query.isEmpty ? "No listening ports" : "No results")
                                .font(.system(size: 12, weight: .medium))
                            Text(model.query.isEmpty ? "Start a server and refresh." : "Try a port number or process name.")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity).frame(height: listHeight)
                    }
                    ForEach(model.filtered) { item in
                        PortRow(item: item, model: model)
                        Divider().padding(.leading, 16)
                    }
                }
            }.frame(height: listHeight)
                .scrollIndicators(.hidden)

            Divider()
            HStack {
                Text("\(model.filtered.count) listening \(model.filtered.count == 1 ? "port" : "ports")")
                Spacer()
                Text(model.scanning ? "Refreshing…" : "TCP")
            }.font(.system(size: 10)).foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.vertical, 8)
        }.frame(width: 360).background(Color(nsColor: .windowBackgroundColor))
            .alert("Stop this process?", isPresented: Binding(get: { model.selected != nil }, set: { if !$0 { model.selected = nil } })) {
                Button("Cancel", role: .cancel) { model.selected = nil }
                Button("Stop process", role: .destructive) { model.stopSelected() }
            } message: {
                if let item = model.selected {
                    Text("Terminate \(item.process) (PID \(item.pid))? This closes all ports owned by the process. A supervisor may restart it.")
                }
            }
    }
    func about() {
        let alert = NSAlert()
        alert.messageText = "Port Pocket"
        alert.informativeText = "Version 0.1.0\n\nLocal TCP port discovery and process management. Stop sends SIGTERM to a verified process owned by your user."
        alert.runModal()
    }
}

private struct PortRow: View {
    let item: Listener
    @ObservedObject var model: PocketModel
    @State private var hovered = false
    var body: some View {
        HStack(spacing: 14) {
            Text(String(item.port)).font(.system(size: 12, weight: .medium, design: .monospaced))
                .frame(width: 48, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.project).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Text("\(item.process) · \(String(item.pid))")
                    .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            Button { NSWorkspace.shared.open(item.url) } label: {
                Image(systemName: "arrow.up.right").font(.system(size: 11)).frame(width: 20, height: 26)
            }.buttonStyle(.plain).foregroundStyle(.secondary)
                .help("Open http://localhost:\(item.port)")
                .accessibilityLabel("Open port \(item.port) in browser")
            Menu {
                Button("Open in browser") { NSWorkspace.shared.open(item.url) }
                Button("Open with HTTPS") { NSWorkspace.shared.open(URL(string: "https://localhost:\(item.port)")!) }
                Button("Copy URL") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.url.absoluteString, forType: .string)
                }
                if !item.directory.isEmpty {
                    Button("Reveal folder") { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: item.directory) }
                }
                Divider()
                Text("Bound to \(item.addresses.joined(separator: ", "))")
                Divider()
                Button("Stop process…", role: .destructive) { model.selected = item }
                    .disabled(!item.canStop || model.stopping)
            } label: { Image(systemName: "ellipsis").frame(width: 16, height: 26) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .accessibilityLabel("Actions for port \(item.port)")
        }.padding(.horizontal, 16).frame(height: 44)
            .background(Color.primary.opacity(hovered ? 0.035 : 0))
            .onHover { value in
                withAnimation(.easeOut(duration: 0.12)) { hovered = value }
            }
            .help(item.directory.isEmpty ? item.process : item.directory)
    }
}
