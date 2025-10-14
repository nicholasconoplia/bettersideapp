//
//  PaywallPreviewBuilder.swift
//  glowup
//
//  Created by Codex on 13/10/2025.
//

import Foundation

enum PaywallPreviewBuilder {
    static func makePreview(
        from result: QuizResult?
    ) -> PaywallPreview {
        return PaywallPreview(
            headline: headline(from: result),
            insightBullets: insightBullets(from: result),
            solutionBullets: solutionBullets(from: result)
        )
    }

    private static func headline(from result: QuizResult?) -> String {
        guard let goal = result?.primaryGoal else {
            return "We heard where you’re feeling stuck."
        }
        switch goal {
        case "photos":
            return "You deserve photos you actually want to post."
        case "confidence":
            return "Daily confidence shouldn’t feel like a guessing game."
        case "clarity":
            return "Clarity is coming—no more styling roulette."
        case "reinvention":
            return "Ready to shock them? We mapped your reinvention."
        default:
            return "We heard where you’re feeling stuck."
        }
    }

    private static func insightBullets(from result: QuizResult?) -> [String] {
        guard let result else {
            return [
                "You want better guidance, less guesswork, and more glow."
            ]
        }

        var bullets: [String] = []

        if let mirrorFocus = result.answers["mirror_focus"]?.first {
            switch mirrorFocus {
            case "skin_texture":
                bullets.append("You instantly clock every texture shift the second you face the mirror.")
            case "dark_circles":
                bullets.append("Those dark-circle shadows steal your attention before anything else does.")
            case "jawline_focus":
                bullets.append("You’re sizing up your angles and jawline before you even blink.")
            case "glow_check":
                bullets.append("You’re chasing consistency—your glow looks different every single day.")
            default:
                break
            }
        }

        if let candid = result.answers["candid_reaction"]?.first {
            switch candid {
            case "hide_photo":
                bullets.append("Tagged candids go straight to the archive because you don’t feel ready for them.")
            case "ask_retake":
                bullets.append("You’re coaching every retake, hoping the next one finally lands.")
            case "share_proud":
                bullets.append("You love sharing wins and want even more of them.")
            case "shrug_off":
                bullets.append("You shrug off candids in public but replay them quietly later.")
            default:
                break
            }
        }

        if let moment = result.answers["moment_avoid"]?.first {
            switch moment {
            case "night_out":
                bullets.append("Night-out selfies feel like a high-stakes performance.")
            case "family_event":
                bullets.append("Family photos feel permanent, and that pressure hits hard.")
            case "first_dates":
                bullets.append("You want first impressions to match how you feel inside.")
            case "work_calls":
                bullets.append("Always-on cameras at work drain your energy before meetings start.")
            default:
                break
            }
        }

        if let hype = result.answers["hype_circle"]?.first {
            switch hype {
            case "best_friend":
                bullets.append("You lean on your inner circle for glow hype—and you deserve even more support.")
            case "partner":
                bullets.append("Your partner notices every shift, and you want to meet that energy daily.")
            case "self":
                bullets.append("You’re your own hype squad, but it’s exhausting to do it alone.")
            case "quiet":
                bullets.append("It’s been quiet lately—you’ve been motivating yourself without backup.")
            default:
                break
            }
        }

        if bullets.isEmpty {
            bullets.append("You want better guidance, less guesswork, and more glow.")
        }
        return bullets
    }

    private static func solutionBullets(from result: QuizResult?) -> [String] {
        guard let result else {
            return [
                "GlowUp maps your routines, palettes, and poses so you always know what works.",
                "Live coaching and daily rituals keep you accountable when motivation dips."
            ]
        }

        var bullets: [String] = []

        if let styleBlock = result.answers["style_block"]?.first {
            switch styleBlock {
            case "no_guidance":
                bullets.append("We’ll build a guided palette, posing library, and outfit map so you never guess alone again.")
            case "budget":
                bullets.append("We’ll recommend high-impact upgrades that respect your budget and your time.")
            case "time":
                bullets.append("We’ll automate quick daily rituals so progress fits into your real schedule.")
            case "confidence_block":
                bullets.append("We’ll give you repeatable wins that rebuild confidence before every camera moment.")
            default:
                break
            }
        }

        if let motivation = result.answers["glow_motivation"]?.first {
            switch motivation {
            case "photos":
                bullets.append("Expect camera-ready drills, lighting cues, and posing reminders tailored to you.")
            case "confidence":
                bullets.append("We’ll mix mindset resets with small daily glow victories that actually stick.")
            case "clarity":
                bullets.append("Your dashboard will translate palettes, textures, and silhouettes into clear yes/no moves.")
            case "reinvention":
                bullets.append("We’ll pace out a full reinvention plan—from mood board to execution—so it feels doable.")
            default:
                break
            }
        }

        if let palette = result.answers["dream_palette"]?.first {
            switch palette {
            case "warm":
                bullets.append("We’ll curate warm, sun-lit looks and lighting formulas that keep your glow consistent.")
            case "cool":
                bullets.append("We’ll script icy, luminous tones and lighting guidance to make them pop.")
            case "neutral":
                bullets.append("We’ll balance soft neutrals with contrast moments so you never feel washed out.")
            case "no_clue":
                bullets.append("We’ll test palettes with guided feedback until your signature colors feel obvious.")
            default:
                break
            }
        }

        if bullets.isEmpty {
            bullets.append("GlowUp maps your routines, palettes, and poses so you always know what works.")
            bullets.append("Live coaching and daily rituals keep you accountable when motivation dips.")
        }
        return bullets
    }
}
