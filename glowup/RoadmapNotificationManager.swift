//
//  RoadmapNotificationManager.swift
//  glowup
//
//  Created by Codex on 02/11/2025.
//

import Foundation
import UserNotifications

final class RoadmapNotificationManager {
    static let shared = RoadmapNotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let reminderIdentifier = "weekly.glow.roadmap.checkin"
    private let monthlyRescanIdentifier = "monthly.glow.rescan.reminder"
    private let dailyNudgePrefix = "daily.glow.nudge."

    private init() {}

    func requestAuthorizationIfNeeded() {
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error {
                    print("[RoadmapNotificationManager] Authorization request error: \(error)")
                } else {
                    print("[RoadmapNotificationManager] Authorization granted: \(granted)")
                }
            }
        }
    }

    func scheduleWeeklyCheckIn(forWeek weekNumber: Int) {
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                print("[RoadmapNotificationManager] Notifications not authorized; skipping scheduling.")
                return
            }

            self.center.removePendingNotificationRequests(withIdentifiers: [self.reminderIdentifier])

            let content = UNMutableNotificationContent()
            content.title = "How’s your glow journey going? ✨"
            content.body = "You’re on Week \(weekNumber). Tap to check off completed tasks!"
            content.sound = .default

            let nextDate = self.nextCheckInDate()
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(identifier: self.reminderIdentifier, content: content, trigger: trigger)
            self.center.add(request) { error in
                if let error {
                    print("[RoadmapNotificationManager] Failed to schedule notification: \(error)")
                } else {
                    print("[RoadmapNotificationManager] Scheduled weekly check-in for \(nextDate).")
                }
            }
        }
    }

    func scheduleMonthlyRescanReminder() {
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                print("[RoadmapNotificationManager] Notifications not authorized; skipping monthly reminder.")
                return
            }

            self.center.removePendingNotificationRequests(withIdentifiers: [self.monthlyRescanIdentifier])

            let content = UNMutableNotificationContent()
            content.title = "Time for your monthly glow scan! 💫"
            content.body = "Let’s measure your improvements and refresh your Glow Plan."
            content.sound = .default

            let nextDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date().addingTimeInterval(2_592_000)
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(identifier: self.monthlyRescanIdentifier, content: content, trigger: trigger)
            self.center.add(request) { error in
                if let error {
                    print("[RoadmapNotificationManager] Failed to schedule monthly reminder: \(error)")
                } else {
                    print("[RoadmapNotificationManager] Scheduled monthly rescan reminder for \(nextDate).")
                }
            }
        }
    }

    func cancelRoadmapReminders() {
        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
    }

    private func nextCheckInDate(from referenceDate: Date = Date()) -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.weekday = 4 // Wednesday (1 = Sunday)
        components.hour = 18
        components.minute = 0

        if let next = calendar.nextDate(after: referenceDate, matching: components, matchingPolicy: .nextTime) {
            return next
        }

        let fallback = calendar.date(byAdding: .day, value: 7, to: referenceDate) ?? referenceDate.addingTimeInterval(604_800)
        return calendar.date(
            bySettingHour: 18,
            minute: 0,
            second: 0,
            of: fallback
        ) ?? fallback
    }

    // MARK: - Non-subscriber conversion nudges

    func scheduleDailyNonSubscriberNudges(days: Int = 5, atHour hour: Int = 17, minute: Int = 0) {
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                print("[RoadmapNotificationManager] Notifications not authorized; skipping daily nudges.")
                return
            }

            // Clear existing nudges
            self.center.getPendingNotificationRequests { requests in
                let ids = requests
                    .map(\.identifier)
                    .filter { $0.hasPrefix(self.dailyNudgePrefix) }
                if !ids.isEmpty {
                    self.center.removePendingNotificationRequests(withIdentifiers: ids)
                }

                let messages = self.nudgeMessages()
                let calendar = Calendar.current
                let startDate = Date()

                for i in 0..<days {
                    let fireDate = calendar.date(byAdding: .day, value: i, to: startDate) ?? startDate
                    var comps = calendar.dateComponents([.year, .month, .day], from: fireDate)
                    comps.hour = hour
                    comps.minute = minute

                    let content = UNMutableNotificationContent()
                    content.title = "Ready to glow today? ✨"
                    content.body = messages[i % messages.count]
                    content.sound = .default

                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    let id = self.dailyNudgePrefix + String(i)
                    let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                    self.center.add(request) { error in
                        if let error {
                            print("[RoadmapNotificationManager] Failed to schedule daily nudge: \(error)")
                        }
                    }
                }

                print("[RoadmapNotificationManager] Scheduled \(days) daily non-subscriber nudges starting today @ \(hour):\(String(format: "%02d", minute)).")
            }
        }
    }

    func cancelDailyNonSubscriberNudges() {
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(self.dailyNudgePrefix) }
            if !ids.isEmpty {
                self.center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
    }

    private func nudgeMessages() -> [String] {
        [
            "Don’t forget today’s scan — tiny steps, big glow ✨",
            "Feeling like a glow up? Do a 30‑sec scan now",
            "Your best look is closer than you think. Open GlowUp",
            "Quick check-in = more confidence later. Tap to start",
            "Ready for a better mirror moment today? Begin your scan"
        ]
    }
}
