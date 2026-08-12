//
//  ReportViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 25/07/2026.
//  Copyright © Trakt. All rights reserved.
//

import SwiftUI
import UIKit

enum ReportTarget {
    case comment(Comment)
    case user(User)

    var user: User {
        switch self {
        case .comment(let comment):
            return comment.user
        case .user(let user):
            return user
        }
    }

    fileprivate var title: String {
        switch self {
        case .comment:
            return "Report Comment"
        case .user:
            return "Report User"
        }
    }

    fileprivate var reasons: [ReportReason] {
        switch self {
        case .comment:
            return [.spoilers,
                    .abusive,
                    .spam,
                    .bigotry,
                    .political,
                    .offTopic,
                    .duplicate,
                    .other]
        case .user:
            return [.spam,
                    .adult,
                    .language,
                    .other]
        }
    }

    fileprivate var canOfferBlock: Bool {
        switch self {
        case .comment:
            return false
        case .user(let user):
            return !user.isBlocked
        }
    }

    fileprivate func service(reason: ReportReason, message: String?) -> TraktAPIService {
        switch self {
        case .comment(let comment):
            return .reportComment(id: comment.identifier,
                                  reason: reason,
                                  message: message)
        case .user(let user):
            return .reportUser(slug: user.identifiers.slugOrTraktId,
                               reason: reason,
                               message: message)
        }
    }
}

final class ReportViewController: RipppleHostingController<ReportView> {
    init(target: ReportTarget) {
        super.init(rootView: ReportView(target: target))
        modalPresentationStyle = .formSheet
        preferredContentSize = CGSize(width: 560, height: 700)
    }

    @available(*, unavailable)
    @objc dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct ReportView: View {
    private enum SubmissionResult {
        case sent
        case alreadyReported
        case failed
    }

    private struct ReportAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let shouldDismiss: Bool
        let shouldBlock: Bool
    }

    let target: ReportTarget

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isDetailsFocused: Bool
    @State private var selectedReason: ReportReason?
    @State private var details = ""
    @State private var shouldBlock = false
    @State private var isSubmitting = false
    @State private var alert: ReportAlert?

    var body: some View {
        NavigationStack {
            RipppleForm {
                reassuranceSection
                reasonSection
                detailsSection

                if target.canOfferBlock {
                    blockSection
                }
            }
            .disabled(isSubmitting)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(target.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                            .accessibilityLabel("Sending report")
                    } else {
                        Button("Send") {
                            sendReport()
                        }
                        .disabled(selectedReason == nil)
                    }
                }
            }
            .interactiveDismissDisabled(isSubmitting)
            .alert(item: $alert) { alert in
                Alert(title: Text(alert.title),
                      message: Text(alert.message),
                      dismissButton: .default(Text(alert.shouldDismiss ? "Done" : "Okay")) {
                          guard alert.shouldDismiss else { return }

                          dismiss()
                          if alert.shouldBlock {
                              target.user.block()
                          }
                      })
            }
        }
    }

    private var reassuranceSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("You're in control")
                        .font(.headline)
                    Text("Only Trakt's moderation team can see your report. Share only what you're comfortable providing.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(Color(uiColor: UIColor(asset: .globalTint)))
            }
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
        }
    }

    private var reasonSection: some View {
        Section {
            ForEach(target.reasons, id: \.rawValue) { reason in
                Button {
                    selectedReason = reason
                } label: {
                    HStack {
                        Text(reason.title)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedReason == reason {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color(uiColor: UIColor(asset: .globalTint)))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(selectedReason == reason ? "Selected" : "Not selected")
            }
        } header: {
            Text("What happened?")
        } footer: {
            Text("Choose the reason that most closely matches what you experienced.")
        }
    }

    private var detailsSection: some View {
        Section {
            ZStack(alignment: .topLeading) {
                if details.isEmpty {
                    Text("Add any context that may help the moderators…")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $details)
                    .focused($isDetailsFocused)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .accessibilityLabel("Additional context")
                    .accessibilityHint("Optional details that will be included with your report")
            }
        } header: {
            Text("Additional Context")
        } footer: {
            Text("This is optional. Add any details that may help Trakt's moderation team review your report.")
        }
    }

    private var blockSection: some View {
        Section {
            Toggle("Also block \(target.user.username)", isOn: $shouldBlock)
                .accessibilityHint("Hides this user's comments after the report is sent")
        } footer: {
            Text("Blocking hides this user's comments across Trakt apps, including Rippple. You can unblock them later.")
        }
    }

    private func sendReport() {
        guard let selectedReason = selectedReason,
              !target.user.isCurrentUser else { return }

        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = trimmedDetails.isEmpty ? nil : trimmedDetails
        let shouldBlock = target.canOfferBlock && self.shouldBlock

        isDetailsFocused = false
        isSubmitting = true

        TraktAPIProvider.noRatingProvider.request(target.service(reason: selectedReason,
                                                                 message: message),
                                                  callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
            let submissionResult: SubmissionResult

            switch result {
            case .success(let response):
                if response.statusCode == 409 {
                    submissionResult = .alreadyReported
                } else if (try? response.filterSuccessfulStatusCodes()) != nil {
                    submissionResult = .sent
                } else {
                    submissionResult = .failed
                }
            case .failure:
                submissionResult = .failed
            }

            DispatchQueue.main.async {
                finishSubmission(submissionResult,
                                 shouldBlock: shouldBlock)
            }
        }
    }

    private func finishSubmission(_ result: SubmissionResult, shouldBlock: Bool) {
        isSubmitting = false

        switch result {
        case .sent:
            alert = ReportAlert(title: "Report Sent",
                                message: "Thank you for speaking up. Trakt's moderation team will review your report.",
                                shouldDismiss: true,
                                shouldBlock: shouldBlock)
        case .alreadyReported:
            alert = ReportAlert(title: "Report Already Sent",
                                message: "Trakt already has your report. Thank you for speaking up.",
                                shouldDismiss: true,
                                shouldBlock: shouldBlock)
        case .failed:
            alert = ReportAlert(title: "Couldn't Send Report",
                                message: "Your report wasn't sent and no additional action was taken. Please try again.",
                                shouldDismiss: false,
                                shouldBlock: false)
        }
    }
}

private extension ReportReason {
    var title: String {
        switch self {
        case .spoilers:
            return "Undisclosed spoilers"
        case .language:
            return "Wrong language"
        case .abusive:
            return "Abusive or harassing"
        case .spam:
            return "Spam"
        case .bigotry:
            return "Hate or bigotry"
        case .political:
            return "Political content"
        case .offTopic:
            return "Off topic"
        case .support:
            return "Support request"
        case .duplicate:
            return "Duplicate"
        case .tooShort:
            return "Too short"
        case .adult:
            return "Adult content"
        case .other:
            return "Other"
        }
    }
}
