//
//  ProfileTabView.swift
//  PuffPact
//

import SwiftUI
import FirebaseAuth

public struct ProfileTabView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var authService: FirebaseAuthService
    
    let groupId: String
    
    @State private var smokingProfile: SmokingProfile?
    @State private var isLoadingProfile = true
    @State private var showCopiedAlert = false
    @State private var showSignOutConfirmation = false
    
    public init(groupId: String = "") {
        self.groupId = groupId
    }
    
    private var effectiveGroupId: String {
        groupId.isEmpty ? state.pactConfig.currencySymbol : groupId
    }
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                Text("Profile")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                
                // User Card
                userCard
                    .padding(.horizontal, 22)
                
                // Pact Details Card
                pactCard
                    .padding(.horizontal, 22)
                
                // Smoking Profile Card
                if let profile = smokingProfile {
                    smokingProfileCard(profile)
                        .padding(.horizontal, 22)
                }
                
                // Account Actions
                accountActions
                    .padding(.horizontal, 22)
            }
            .padding(.top, 6)
            .padding(.bottom, 100)
        }
        .background(Color.black.ignoresSafeArea())
        .task {
            do {
                smokingProfile = try await authService.loadSmokingProfile()
            } catch {
                print("Failed to load smoking profile: \(error)")
            }
            isLoadingProfile = false
        }
        .alert("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                do {
                    try authService.signOut()
                } catch {
                    print("Error signing out: \(error)")
                }
            }
        } message: {
            Text("Are you sure you want to sign out of PuffPact?")
        }
    }
    
    // MARK: - User Card
    
    private var userCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "2B2B2E"))
                        .frame(width: 64, height: 64)
                    Text(state.currentUser.avatarEmoji)
                        .font(.system(size: 32))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.currentUser.name)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if let email = Auth.auth().currentUser?.email, !email.isEmpty {
                        Text(email)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.55))
                    }
                }
                
                Spacer()
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "161618"))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 1))
        )
    }
    
    // MARK: - Pact Card
    
    private var pactCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("YOUR PACT")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(Color.white.opacity(0.45))
                Spacer()
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Partner")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.55))
                    HStack(spacing: 6) {
                        Text(state.friendUser.avatarEmoji)
                            .font(.system(size: 16))
                        Text(state.friendUser.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Weekly Limit")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.55))
                    Text("\(state.pactConfig.individualWeeklyLimit) sticks")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "FFD9A8"))
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pact Code")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.45))
                    Text(groupId.isEmpty ? "—" : groupId)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "FDE8CC"))
                }
                
                Spacer()
                
                if !groupId.isEmpty {
                    Button {
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(groupId, forType: .string)
                        #else
                        UIPasteboard.general.string = groupId
                        #endif
                        showCopiedAlert = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCopiedAlert = false
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: showCopiedAlert ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11, weight: .semibold))
                            Text(showCopiedAlert ? "Copied" : "Copy")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: "FFD9A8"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(hex: "2B2B2E"))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "161618"))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 1))
        )
    }
    
    // MARK: - Smoking Profile Card
    
    private func smokingProfileCard(_ profile: SmokingProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("HABITS & GOALS")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Color.white.opacity(0.45))
            
            HStack(spacing: 12) {
                profileBadge(title: "Daily Level", value: profile.dailyLevel.displayLabel, emoji: profile.dailyLevel.emoji)
                profileBadge(title: "Goal", value: profile.goal.displayLabel, emoji: profile.goal.emoji)
            }
            
            if !profile.cravingTriggers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Triggers")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.55))
                    
                    FlowLayout(spacing: 6) {
                        ForEach(profile.cravingTriggers) { trigger in
                            HStack(spacing: 4) {
                                Text(trigger.emoji)
                                    .font(.system(size: 11))
                                Text(trigger.displayLabel)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "242426"))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "161618"))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 1))
        )
    }
    
    private func profileBadge(title: String, value: String, emoji: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.white.opacity(0.45))
            HStack(spacing: 5) {
                Text(emoji)
                    .font(.system(size: 13))
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(hex: "242426"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Account Actions
    
    private var accountActions: some View {
        VStack(spacing: 12) {
            Button {
                showSignOutConfirmation = true
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Sign Out")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(Color(hex: "e5484d"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(hex: "e5484d").opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color(hex: "e5484d").opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }
}

// Simple Flow layout for trigger tags
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                height += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
