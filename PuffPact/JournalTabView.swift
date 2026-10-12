//
//  JournalTabView.swift
//  PuffPact
//

import SwiftUI

struct JournalTabView: View {
    @EnvironmentObject var state: AppState
    @State private var newEntryText: String = ""
    @State private var isSaving: Bool = false
    @FocusState private var editorFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Journal")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .padding(.horizontal)

                // New entry input
                VStack(alignment: .leading, spacing: 8) {
                    Text("New Entry")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    TextEditor(text: $newEntryText)
                        .focused($editorFocused)
                        .frame(minHeight: 100)
                        .padding(10)
                        .background(Color.cardBackground)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(editorFocused ? Color.blue.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1.5)
                        )
                        .padding(.horizontal)

                    Button(action: saveEntry) {
                        HStack {
                            Image(systemName: isSaving ? "checkmark.circle" : "square.and.arrow.up")
                            Text(isSaving ? "Saved!" : "Save Entry")
                                .font(.subheadline.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(newEntryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.gray.opacity(0.2) : Color.blue)
                        .foregroundColor(newEntryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                         ? .secondary : .white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(newEntryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.horizontal)
                }

                // Saved entries
                if state.journalEntries.isEmpty {
                    VStack(spacing: 8) {
                        Text("📝")
                            .font(.system(size: 40))
                        Text("No journal entries yet.\nWrite your first reflection above.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Past Entries")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(state.journalEntries) { entry in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    let isMe = entry.userId == state.currentUser.id
                                    Text(isMe ? state.currentUser.avatarEmoji : state.friendUser.avatarEmoji)
                                    Text(isMe ? state.currentUser.name : state.friendUser.name)
                                        .font(.caption.bold())
                                    Spacer()
                                    Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Text(entry.text)
                                    .font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding()
                            .background(Color.cardBackground)
                            .cornerRadius(14)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color.pageBackground.ignoresSafeArea())
    }

    private func saveEntry() {
        editorFocused = false
        state.saveJournalEntry(text: newEntryText)
        isSaving = true
        newEntryText = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSaving = false
        }
    }
}
