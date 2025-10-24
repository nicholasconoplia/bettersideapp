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
}
