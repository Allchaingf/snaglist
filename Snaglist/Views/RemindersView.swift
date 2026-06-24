//
//  RemindersView.swift  (Screen 13 — Reminders)
//  Snaglist
//
//  Real local notifications via UNUserNotificationCenter: per-snag fix-due
//  reminders, a daily re-verify digest, and a one-shot handover-day alert.
//  Each toggle schedules/cancels real requests. iOS 14 safe.
//

import SwiftUI

struct RemindersView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var notifications: NotificationManager

    @AppStorage("dueRemindersEnabled") private var dueReminders = false
    @AppStorage("verifyDigestEnabled") private var verifyDigest = false
    @AppStorage("verifyDigestHour") private var verifyHour = 8
    @AppStorage("handoverReminderEnabled") private var handoverReminder = false

    @State private var toast: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                if let t = toast {
                    CardView { HStack { Image(systemName: "checkmark.circle.fill").foregroundColor(Theme.closed)
                        Text(t).font(Theme.body()).foregroundColor(Theme.textPrimary) } }
                }

                CardView {
                    HStack(spacing: 10) {
                        Image(systemName: notifications.isAuthorized ? "bell.fill" : "bell.slash.fill")
                            .foregroundColor(notifications.isAuthorized ? Theme.closed : Theme.review)
                        Text(notifications.isAuthorized ? "Notifications allowed."
                                                        : "Enable a reminder below to grant permission.")
                            .font(Theme.caption()).foregroundColor(Theme.textSecondary)
                        Spacer()
                    }
                }

                // Fix-due reminders
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Fix-due reminders", subtitle: "9am on each snag's due date", systemImage: "calendar.badge.clock")
                        Toggle(isOn: $dueReminders) {
                            Text("Remind me when snags are due").font(Theme.body()).foregroundColor(Theme.textPrimary)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                        .onChange(of: dueReminders) { on in
                            if on { ensureAuth({ rescheduleDue() }, onDeny: { dueReminders = false }) }
                            else { notifications.cancelDueReminders(); flash("Fix-due reminders off") }
                        }
                        if dueReminders {
                            let count = dueItems().count
                            Text("\(count) upcoming due date\(count == 1 ? "" : "s") scheduled.")
                                .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                            ActionButton(title: "Reschedule from current snags", systemImage: "arrow.clockwise", kind: .secondary) {
                                rescheduleDue(); flash("Rescheduled \(dueItems().count) reminder(s)")
                            }
                        }
                    }
                }

                // Re-verify digest
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Re-verify digest", subtitle: "Daily summary of the verify queue", systemImage: "checkmark.circle.badge.questionmark")
                        Toggle(isOn: $verifyDigest) {
                            Text("Daily verify reminder").font(Theme.body()).foregroundColor(Theme.textPrimary)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                        .onChange(of: verifyDigest) { on in
                            if on { ensureAuth({ scheduleDigest(); flash("Digest scheduled for \(timeString)") }, onDeny: { verifyDigest = false }) }
                            else { notifications.cancelVerifyDigest(); flash("Digest off") }
                        }
                        if verifyDigest {
                            Stepper(value: $verifyHour, in: 0...23) {
                                Text("Time: \(timeString)").font(Theme.body()).foregroundColor(Theme.textPrimary)
                            }.onChange(of: verifyHour) { _ in if verifyDigest { scheduleDigest() } }
                        }
                    }
                }

                // Handover reminder
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Handover day", subtitle: Formatters.date(store.project.handoverDate), systemImage: "flag.checkered")
                        Toggle(isOn: $handoverReminder) {
                            Text("Remind me on handover day").font(Theme.body()).foregroundColor(Theme.textPrimary)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                        .onChange(of: handoverReminder) { on in
                            if on { ensureAuth({ scheduleHandover(); flash("Handover reminder set") }, onDeny: { handoverReminder = false }) }
                            else { notifications.cancelHandoverReminder(); flash("Handover reminder off") }
                        }
                    }
                }

                ActionButton(title: "Send Test Notification", systemImage: "paperplane.fill", kind: .secondary) {
                    ensureAuth({ notifications.sendTestNotification(body: "Test — this is how reminders will look."); flash("Test scheduled (3s)") },
                               onDeny: {})
                }
            }
            .padding(Theme.Space.m)
            .padding(.bottom, 40)
        }
        .inspectionScreen(showGlyph: false)
        .navigationBarTitle("Reminders", displayMode: .inline)
        .onAppear { notifications.refreshStatus() }
    }

    // MARK: - Helpers

    private var timeString: String { String(format: "%02d:00", verifyHour) }

    private func dueItems() -> [(id: UUID, title: String, due: Date)] {
        store.snags.filter { $0.status != .verified && $0.dueDate != nil }
            .map { (id: $0.id, title: $0.title.isEmpty ? "Snag due" : $0.title, due: $0.dueDate!) }
    }

    private func rescheduleDue() { notifications.scheduleDueReminders(dueItems()) }

    private func scheduleDigest() {
        let n = store.verifyQueue.count
        notifications.scheduleVerifyDigest(hour: verifyHour, minute: 0,
                                           body: n == 0 ? "No fixes waiting — nice work." : "\(n) fix(es) waiting to be verified.")
    }

    private func scheduleHandover() {
        notifications.scheduleHandoverReminder(on: store.project.handoverDate,
                                               body: "\(store.totalOpen) snag(s) still open · \(Formatters.percent(store.handoverReadiness)) ready.")
    }

    private func ensureAuth(_ then: @escaping () -> Void, onDeny: @escaping () -> Void) {
        if notifications.isAuthorized { then() }
        else {
            notifications.requestAuthorization { granted in
                if granted { then() } else { onDeny(); flash("Permission denied — enable in the Settings app") }
            }
        }
    }

    private func flash(_ msg: String) {
        withAnimation { toast = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { withAnimation { toast = nil } }
    }
}
