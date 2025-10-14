build this app for me from scratch. GlowUp iOS Technical and Functional Specification v2.3 (SwiftUI Native)
App Name: GlowUp
Tagline: “Don’t just take photos — glow up.”
Platform: iOS 17+
Version: 2.3 (Full Gemini Live Integration)

> **Migration Note (2025-10-13):** Runtime AI functionality now ships with OpenAI GPT-4 Vision for multimodal analysis and coaching. Any remaining references to Gemini in this spec are legacy and should be interpreted as GPT-4 Vision endpoints in the shipping build.

I. Product Overview, Vibe, and Monetization Strategy
A. Core Value Proposition
GlowUp is a personalized, AI-powered photo coach focused on long-term confidence and aesthetic improvement. The app drives retention through continuous, personalized guidance (Short-Term/Long-Term Tips) and the addictive nature of Gemini Live: Real-Time Conversational Coaching.

B. Aesthetic & Design Language (SwiftUI Implementation)
Color Palette: Soft, luminous, and affirming. Use LinearGradient or RadialGradient extensively (e.g., lavender to rose gold, soft mint to light peach) for backgrounds and main elements. Use vibrant, high-contrast colors (e.g., coral or neon green) for critical feedback and action buttons.

Typography: Utilize the native systemFont with custom weights and largeTitle styling for bold impacts.

Visual Elements: Use the shadow, clipShape(RoundedRectangle), and containerBackground modifiers to achieve the signature "glow" effect and rounded corners on all UI elements.

Interface: Built with a TabView for main navigation. All controls must adhere to Apple's Human Interface Guidelines (HIG).

C. Monetization (Mandatory Paid Access)
No Free Tier: Access to all core features (Camera, Tips, Profile) requires an active subscription.

7-Day Free Trial: The paywall must offer a 7-day free trial via StoreKit 2.

II. Technical Architecture: Native iOS Stack
A. Defined Tech Stack
Frontend: SwiftUI (iOS 17+).

Camera/Video: AVFoundation and SwiftUI CameraView.

Data Persistence: Core Data for all structured data storage (Profiles, Sessions, Tips, Streaks, Quiz Results). UserDefaults for simple settings.

Payments: StoreKit 2 for managing the subscription and 7-day free trial.

On-Device AI/ML: Vision Framework and Core ML for low-latency facial landmark detection, pose estimation, and initial lighting analysis.

Generative AI: Gemini API for all generated text (Tips, Summaries), personality creation, and multi-modal input processing (Gemini Live).

B. Data Persistence (Core Data Entities)
Core Data Entity

Purpose

Key Attributes (Swift Types)

UserSettings

General app config & subscription status.

coachPersonaID: String, isProSubscriber: Bool, lastSessionDate: Date, onboardingComplete: Bool

OnboardingQuiz

Stores user's initial self-assessment.

answers: [String: String] (e.g., "knows_palette": "no"), targetGoal: String

GlowProfile

AI's permanent personalized insights.

faceShape: String, colorPalette: String, bestAngleTilt: Double, optimalLightingDesc: String, theme: String

PhotoSession

Log of each attempt.

id: UUID, startTime: Date, sessionType: String, confidenceScore: Double, aiSummary: String (Gemini-generated)

DailyStreak

Tracking user consistency.

currentCount: Int16, lastUpdateDate: Date

TipEntry

Stores generated tips for the Hub.

id: String, type: String ("short" or "long"), title: String, body: String, completed: Bool, createdAt: Date, source: String

ConversationEntry

Stores Gemini Live chat history.

role: String, text: String, timestamp: Date

III. Conversion-First Onboarding and Paywall Flow
The entire app is gated by the subscription. This funnel is mandatory before Tab access.

1. Onboarding Step 1 — Welcome (WelcomeView)
Header: Welcome to GlowUp ✨

Subtext: Are you ready to look and feel like your best self?

Primary CTA: Let’s Find Out (Initiates Quiz).

Secondary CTA: Skip (not recommended) — Taps instantly lead to the Paywall (SubscriptionGateView).

2. Onboarding Step 2 — Personalized Quiz (QuizView)
Purpose: To highlight knowledge gaps and collect attributes for the dynamic paywall preview.

Logic: 5 to 8 questions are randomly selected from the bank below. Answers are stored in the OnboardingQuiz Core Data entity upon completion.

ID

Type

Question Text

Options

do_you_know_your_undertone

Radio

Do you know your skin's undertone?

[Yes, No, Not sure]

do_you_know_your_face_shape

Radio

Can you identify your signature face shape?

[Yes, No, Not sure]

how_often_get_compliments

Radio

How often do you get compliments on your photos?

[Often, Sometimes, Rarely]

main_goal

Multi

What's your main goal? (Select all that apply)

[Glow on camera, Boost real-life confidence, Learn what suits me, Total transformation]

color_preferences

Multi-select

Which color family do you usually prefer?

[Warm, Cool, Neutral, No idea]

willing_to_try_hair_color

Radio

Are you open to trying a new hair color?

[Yes, Maybe, No]

upload_sample_photo_now

Optional File

Upload a photo now for the AI to analyze.

[PhotoPicker Component]

3. Onboarding Step 3 — Instant Preview & Paywall Gate (SubscriptionGateView)
Dynamic Preview Generation: The app generates a short, personalized text summary using client-side templating based on quiz answers.

CTA (Leads to Paywall): See My Glow Plan →

Paywall Text: Your Personalized Glow Plan is Ready 🌟

Subtext: Start your 7-day free trial. After trial: $X.XX / month billed monthly. Cancel anytime.

Dynamic Preview Fields:

Predicted Face Shape: (Generated instantly from quiz/AI on final screen).

Best Color Family: (e.g., "Warm Tones").

One Celebrity Match Sample: (Generated by Gemini based on quiz data).

Buttons:

Primary: Start 7-Day Free Trial (Calls StoreKit 2 Product.purchase()).

Secondary: I don’t want to glow — Triggers sign-out/exit flow (or closes app if no signed-in user state).

On Purchase Success (StoreKit 2):

Verify transaction and entitlement via Transaction.currentEntitlement.

Set UserSettings.isProSubscriber = true in Core Data.

Grant access to the main TabView.

IV. Core Features and Tabs
A. Tab 1: Home Screen (HomeView)
Top Greeting: "Hey [User's First Name]!" or "Hey Bestie!"

Hero CTA: Start a Session → (Taps navigate to the Live Coach tab).

Preview Strip: Today's Short-Term Tip (From Tip Engine - Short-Term).

Quick Link: My Glow Profile → (Taps navigate to the Profile tab).

Recent Activity: Small card showing the last session summary (session_date, confidence_score_avg, small saved image thumbnail).

B. Tab 2: Live Coach / Upload Tab (AICoachOptionsView)
Purpose: Single entry point for image analysis. Both Upload Photo and Go Live are functional.

UI Layout:

Top Center: Coach Persona Selector chip (defaults to "Bestie").

Main Area: Shows live camera preview.

Middle Overlay: Small helper text: "Choose Upload Photo or Go Live."

Large Buttons: Two prominent, glowing buttons.

"Upload Photo" (Functional): Initiates PhotoPicker flow and Static Photo Analysis.

"Go Live" (Functional): Opens the GeminiLiveView (new conversational flow).

C. Gemini Live: Real-Time Conversational Coaching
The GeminiLiveView utilizes the multi-modal capabilities of the Gemini API for continuous, conversational coaching.

Camera Stream & Throttling:

AVFoundation captures the video stream.

The app samples the video stream (e.g., 1 frame every 5 seconds). This frame is compressed (e.g., JPEG 80%) and converted to Base64.

Strict Throttling: Image submission to the Gemini API is rate-limited to once every 5 seconds. This is critical for managing network load.

Input Processing:

The app maintains a conversational chat history (stored in the ConversationEntry Core Data entity).

Passive Prompt (Automatic): When a new frame is sent, the app includes a prompt: "Act as [Persona]. Analyze the user's current pose, lighting, and expression based on their stored profile. Provide a concise, 1-sentence coaching tip in chat."

Active Prompt (User Query): If the user types or speaks a question (e.g., "Does this lighting make me look soft?"), the app sends the current frame plus the user's question.

Output & Display (GeminiLiveView):

Full-Screen Camera Feed.

Chat Overlay: A translucent, scrollable container at the bottom displaying the conversational history as chat bubbles (both user queries and Gemini responses).

Input Field: Allows the user to type questions.

Microphone Button: Enables voice input (STT) which converts speech to a text query for Gemini.

Error Handling: If the Gemini API returns an error, the conversational chat logs the fallback message: "[Icon] I'm getting a little dizzy from all this slay. Try that question again, icon."

D. Static Photo Analysis Flow (Upload)
User selects one photo via PhotoPicker.

App displays: "Analyzing the slay..." (with animated shimmer).

On-Device ML: Runs Vision/Core ML for landmarks, pose, lighting, and color segmentation.

Gemini API Call (Summary): The ML results are sent to the Gemini API with the user's Persona System Instruction to generate a 3-5 line summary.

Persistence: A new PhotoSession entity is created in Core Data, storing the summary and scores, and updating the GlowProfile aggregator.

Output: Displays a detailed Analysis Result Screen.

E. Tab 3: Tips Hub (TipsHubView)
Structure: SwiftUI ScrollView with a SegmentedControl at the top to switch between Short-Term Glow and Long-Term Strategy views.

1. Tip Engine — Core Logic (Gemini API Driven)
Inputs: GlowProfile attributes, PhotoSession history, OnboardingQuiz responses.

Gemini Call: The app packages the user's Core Data profile into a structured prompt and sends it to the Gemini API to generate the tip lists using a structured JSON schema.

2. Short-Term Tips (Daily Actions)
Refresh: Reset and generated daily.

Prioritization: Tips are dynamically prioritized based on the last session's weaknesses (e.g., poor lighting in the last session suggests a "face the window" tip).

Content (Gemini-Generated): Micro-actions focused on wellness and immediate posing. User can mark complete; completion is logged to the TipEntry Core Data entity.

3. Long-Term Tips (Aesthetic Strategy)
Persistence: Generated less frequently (e.g., weekly) and stored in the TipEntry Core Data entity.

Content (Gemini-Generated): Profile-driven advice focused on style, color, and permanent change.

4. Celebrity Lookalike Module
Process: The app sends the user's face_shape and theme (e.g., "Dark Academia") to the Gemini API.

Gemini Output: Returns a string (or structured JSON) naming a celebrity with similar features and style.

Persistence: The celebrity match is stored in the user's GlowProfile.

5. Pinterest Search Generator
Mechanism: For each long-term tip or celebrity match, the app generates 3-5 highly specific search queries using the Gemini API.

UI: Queries are presented as a tappable chip with a "Copy" button and an "Open in Pinterest" button.

F. Tab 4: Profile Tab (GlowProfileView)
Purpose: The persistent, aggregated "model" of the user based on AI analysis.

Profile UI Components: Displays Face Shape, Skin Undertone, Seasonal Palette (with color swatches), Best Angles, Lighting Mastery, My Best Photos, and Confidence Score History.

Action: A button to Re-run Analysis (requires subscription and triggers the ML pipeline to update profile data).

V. Critical Implementation Notes
StoreKit Entitlement: The primary point of truth for access MUST be the Transaction.currentEntitlement provided by StoreKit 2.

Privacy: All Vision/Core ML processing MUST be performed entirely on-device.

Gemini Safety & Throttling: Ensure the strict 5-second throttling is enforced for multi-modal Gemini Live calls.

UI/UX: Ensure all screens maintain the "glowing" aesthetic with custom gradients and rounded corners throughout.
