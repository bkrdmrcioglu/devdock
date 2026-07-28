import SwiftUI
import AppKit

struct WorkspaceEditorView: View {
    @EnvironmentObject private var store: DevDockStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedIDs: Set<UUID> = []
    @State private var openBrowsers = false
    @State private var isMorningRoutine = false
    @State private var editingID: UUID?

    private var isEditing: Bool { editingID != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !store.workspaceSuggestions.isEmpty {
                        suggestionsSection
                    }

                    if !store.workspaceActivityMessage.isEmpty {
                        activityBanner
                    }

                    if !store.settings.workspaces.isEmpty {
                        existingWorkspacesSection
                    }

                    Divider().overlay(DevDockTheme.line)

                    formSection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            Divider().overlay(DevDockTheme.line)

            footerBar
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
        }
        .frame(width: 580, height: 720)
        .background(DevDockTheme.ink)
        .foregroundStyle(DevDockTheme.chalk)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Workspaces")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(GhostButtonStyle())
            }

            Text("Group API + web + mobile and launch them together. Mark one as your morning routine.")
                .font(.system(size: 12))
                .foregroundStyle(DevDockTheme.mist)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var activityBanner: some View {
        HStack(spacing: 8) {
            if store.isLaunchingWorkspace {
                ProgressView()
                    .controlSize(.small)
            }
            Text(store.workspaceActivityMessage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DevDockTheme.accent)
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DevDockTheme.panelElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var existingWorkspacesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your workspaces")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DevDockTheme.mist)

            ForEach(store.settings.workspaces) { workspace in
                workspaceCard(workspace)
            }
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isEditing ? "Edit workspace" : "New workspace")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DevDockTheme.mist)

            TextField("Name (e.g. Morning Stack)", text: $name)
                .textFieldStyle(.plain)
                .padding(10)
                .background(DevDockTheme.panelElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Toggle("Open browsers after start", isOn: $openBrowsers)
                .toggleStyle(.checkbox)
                .foregroundStyle(DevDockTheme.chalk)

            Toggle("Morning routine (sidebar / menu bar)", isOn: $isMorningRoutine)
                .toggleStyle(.checkbox)
                .foregroundStyle(DevDockTheme.chalk)
                .help("Only one workspace can be the morning routine.")

            Text("Projects")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DevDockTheme.mist)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(store.projects) { project in
                    Toggle(isOn: Binding(
                        get: { selectedIDs.contains(project.id) },
                        set: { on in
                            if on { selectedIDs.insert(project.id) } else { selectedIDs.remove(project.id) }
                        }
                    )) {
                        HStack(spacing: 8) {
                            Text(project.name)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                            Text(project.framework.rawValue)
                                .font(.system(size: 11))
                                .foregroundStyle(DevDockTheme.mist)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(project.displayPort)
                                .font(DevDockTheme.mono)
                                .foregroundStyle(DevDockTheme.mist)
                                .lineLimit(1)
                                .layoutPriority(1)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }
        }
    }

    private var footerBar: some View {
        HStack {
            if isEditing {
                Button("Cancel edit") { resetForm() }
                    .buttonStyle(GhostButtonStyle())
            }
            Text("\(selectedIDs.count) selected")
                .font(.system(size: 11))
                .foregroundStyle(DevDockTheme.mist)
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

            ForEach(store.workspaceSuggestions.prefix(8)) { suggestion in
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Text("\(suggestion.roleSummary) · \(suggestion.memberNames.joined(separator: " · "))")
                            .font(.system(size: 11))
                            .foregroundStyle(DevDockTheme.mist)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button("Add") {
                        store.applyWorkspaceSuggestion(suggestion)
                    }
                    .buttonStyle(AccentButtonStyle())
                    .fixedSize()
                    .layoutPriority(1)
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
                    HStack(spacing: 6) {
                        if workspace.isMorningRoutine {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(DevDockTheme.warn)
                        }
                        Text(workspace.name)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                    }
                    Text(names.isEmpty ? "\(total) projects (missing)" : names.joined(separator: " · "))
                        .font(.system(size: 11))
                        .foregroundStyle(DevDockTheme.mist)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(alive)/\(total) up")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(alive > 0 ? DevDockTheme.accent : DevDockTheme.mist)
                    .fixedSize()
                    .layoutPriority(1)
            }

            HStack(spacing: 8) {
                Button(workspace.isMorningRoutine ? "Start morning" : "Start all") {
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

                Spacer(minLength: 0)

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
        isMorningRoutine = workspace.isMorningRoutine
    }

    private func resetForm() {
        editingID = nil
        name = ""
        selectedIDs = []
        openBrowsers = false
        isMorningRoutine = false
    }

    private func saveForm() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !selectedIDs.isEmpty else { return }

        if let editingID,
           var existing = store.settings.workspaces.first(where: { $0.id == editingID }) {
            existing.name = trimmed
            existing.projectIDs = Array(selectedIDs)
            existing.openBrowsers = openBrowsers
            existing.isMorningRoutine = isMorningRoutine
            store.updateWorkspace(existing)
        } else {
            store.addWorkspace(
                name: trimmed,
                projectIDs: Array(selectedIDs),
                openBrowsers: openBrowsers,
                isMorningRoutine: isMorningRoutine
            )
        }
        resetForm()
    }
}
