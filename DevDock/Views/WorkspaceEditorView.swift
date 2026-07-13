import SwiftUI
import AppKit

struct WorkspaceEditorView: View {
    @EnvironmentObject private var store: DevDockStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedIDs: Set<UUID> = []
    @State private var openBrowsers = false
    @State private var editingID: UUID?

    private var isEditing: Bool { editingID != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Workspaces")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(GhostButtonStyle())
            }

            Text("Group API + frontend + admin and start them together.")
                .font(.system(size: 12))
                .foregroundStyle(DevDockTheme.mist)

            if store.canUseWorkspaces {
                proWorkspaceContent
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Workspaces are a Pro feature")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("Free plan covers \(LicenseLimits.freeProjectCap) projects. Upgrade to group stacks and launch them together.")
                        .font(.system(size: 12))
                        .foregroundStyle(DevDockTheme.mist)
                    Button("Buy Pro — $29") {
                        NSWorkspace.shared.open(LicenseLimits.buyURL)
                    }
                    .buttonStyle(AccentButtonStyle())
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DevDockTheme.panel)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer()
            }
        }
        .padding(24)
        .frame(width: 560, height: 680)
        .background(DevDockTheme.ink)
        .foregroundStyle(DevDockTheme.chalk)
    }

    @ViewBuilder
    private var proWorkspaceContent: some View {
            if !store.workspaceSuggestions.isEmpty {
                suggestionsSection
            }

            if !store.workspaceActivityMessage.isEmpty {
                HStack(spacing: 8) {
                    if store.isLaunchingWorkspace {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(store.workspaceActivityMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DevDockTheme.accent)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DevDockTheme.panelElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if !store.settings.workspaces.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(store.settings.workspaces) { workspace in
                            workspaceCard(workspace)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }

            Divider().overlay(DevDockTheme.line)

            Text(isEditing ? "Edit workspace" : "New workspace")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DevDockTheme.mist)

            TextField("Name (e.g. CRM Stack)", text: $name)
                .textFieldStyle(.plain)
                .padding(10)
                .background(DevDockTheme.panelElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Toggle("Open browsers after start", isOn: $openBrowsers)
                .toggleStyle(.checkbox)
                .foregroundStyle(DevDockTheme.chalk)

            Text("Projects")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DevDockTheme.mist)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(store.projects) { project in
                        Toggle(isOn: Binding(
                            get: { selectedIDs.contains(project.id) },
                            set: { on in
                                if on { selectedIDs.insert(project.id) } else { selectedIDs.remove(project.id) }
                            }
                        )) {
                            HStack {
                                Text(project.name)
                                    .font(.system(size: 13, weight: .medium))
                                Text(project.framework.rawValue)
                                    .font(.system(size: 11))
                                    .foregroundStyle(DevDockTheme.mist)
                                Spacer()
                                Text(project.displayPort)
                                    .font(DevDockTheme.mono)
                                    .foregroundStyle(DevDockTheme.mist)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }
            .frame(maxHeight: 200)

            HStack {
                if isEditing {
                    Button("Cancel edit") { resetForm() }
                        .buttonStyle(GhostButtonStyle())
                }
                Spacer()
                Button(isEditing ? "Save changes" : "Create Workspace") {
                    saveForm()
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || selectedIDs.isEmpty)
            }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggested")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DevDockTheme.warn)

            ForEach(store.workspaceSuggestions.prefix(6)) { suggestion in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.name)
                            .font(.system(size: 13, weight: .semibold))
                        Text(suggestion.memberNames.joined(separator: " · "))
                            .font(.system(size: 11))
                            .foregroundStyle(DevDockTheme.mist)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button("Add") {
                        store.applyWorkspaceSuggestion(suggestion)
                    }
                    .buttonStyle(AccentButtonStyle())
                }
                .padding(10)
                .background(DevDockTheme.panel.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(DevDockTheme.warn.opacity(0.35), lineWidth: 1)
                )
            }
        }
    }

    private func workspaceCard(_ workspace: WorkspaceProfile) -> some View {
        let names = store.workspaceMemberNames(workspace)
        let alive = store.workspaceAliveCount(workspace)
        let total = workspace.projectIDs.count

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workspace.name)
                        .font(.system(size: 14, weight: .semibold))
                    Text(names.isEmpty ? "\(total) projects (missing)" : names.joined(separator: " · "))
                        .font(.system(size: 11))
                        .foregroundStyle(DevDockTheme.mist)
                        .lineLimit(2)
                }
                Spacer()
                Text("\(alive)/\(total) up")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(alive > 0 ? DevDockTheme.accent : DevDockTheme.mist)
            }

            HStack(spacing: 8) {
                Button("Start all") {
                    store.startWorkspace(workspace)
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(store.isLaunchingWorkspace)

                Button("Stop all") {
                    store.stopWorkspace(workspace)
                }
                .buttonStyle(GhostButtonStyle())

                Button("Edit") {
                    beginEdit(workspace)
                }
                .buttonStyle(GhostButtonStyle())

                Spacer()

                Button {
                    store.deleteWorkspace(workspace)
                    if editingID == workspace.id { resetForm() }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(DevDockTheme.danger)
            }
        }
        .padding(12)
        .background(DevDockTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(editingID == workspace.id ? DevDockTheme.accent.opacity(0.5) : DevDockTheme.line, lineWidth: 1)
        )
    }

    private func beginEdit(_ workspace: WorkspaceProfile) {
        editingID = workspace.id
        name = workspace.name
        selectedIDs = Set(workspace.projectIDs)
        openBrowsers = workspace.openBrowsers
    }

    private func resetForm() {
        editingID = nil
        name = ""
        selectedIDs = []
        openBrowsers = false
    }

    private func saveForm() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !selectedIDs.isEmpty else { return }

        if let editingID,
           var existing = store.settings.workspaces.first(where: { $0.id == editingID }) {
            existing.name = trimmed
            existing.projectIDs = Array(selectedIDs)
            existing.openBrowsers = openBrowsers
            store.updateWorkspace(existing)
        } else {
            store.addWorkspace(name: trimmed, projectIDs: Array(selectedIDs), openBrowsers: openBrowsers)
        }
        resetForm()
    }
}
