<!-- 9d2c5789-bd58-4ce9-a744-6ec000f432e4 d7108ff2-fa32-4343-9167-28c48ed9103f -->
# Improve Loading Experience & Analysis Speed

## 1. Create Enhanced Loading Screen Component

**File**: Create new `glowup/AnalysisLoadingView.swift`

Build a dedicated loading view with:

- **Infinite animation**: Rotating gradient circle (no percentage)
- **Stage indicators**: Display current analysis phase ("Analyzing features...", "Processing skin texture...", "Generating recommendations...")
- **Rotating tips**: Fun/casual messages that rotate every 5 seconds
  - "Go grab a matcha ☕ this takes a couple mins"
  - "Worth the wait - AI is analyzing thousands of details"
  - "Pro tip: Good lighting = better results next time"
  - "Hang tight - mapping your unique features"
  - "Almost there - building your personalized roadmap"
  - "Fun fact: Each analysis processes 50+ data points"

The component should accept:

- Current stage (String)
- List of tips (Array<String>)
- Auto-rotate tips every 5 seconds using Timer

## 2. Optimize Image Processing Pipeline

**File**: `glowup/OpenAIService.swift` (lines 729-755)

Current issues:

- Images resized to 1280px max dimension
- Compression at 0.65 quality
- Three high-res base64 images = large payload

**Optimizations**:

1. Reduce max dimension from **1280px → 1024px** (research shows this is optimal for GPT-4o Vision)
2. Adjust compression from **0.65 → 0.75** (better balance per web research)
3. For skin/eye closeups, use even smaller size (768px) since they don't need full resolution

**File**: `glowup/AICoachOptionsView.swift` (lines 468-482)

Make upload wizard consistent:

- Change from 1400px/0.75 → **1024px/0.80** for face
- Use **768px/0.80** for skin and eye closeups

This should reduce total payload from ~8-10MB to ~3-4MB.

## 3. Update StaticPhotoAnalysisView

**File**: `glowup/StaticPhotoAnalysisView.swift`

Replace current loading UI (lines 40-50) with new `AnalysisLoadingView`:

- Remove simple "Analyzing photo..." text and `CircularProgressView` with percentage
- Integrate new loading component with stage progression
- Add stage tracking state that updates as analysis progresses:
  - "Preparing images..." (0-5s)
  - "Analyzing facial features..." (5-30s)
  - "Processing skin texture..." (30-60s)
  - "Generating personalized insights..." (60-90s)
  - "Finalizing recommendations..." (90s+)

Keep fallback UI (lines 74-102) but only show after all retry attempts fail, with the retry button.

## 4. Add Stage Progression Logic

**File**: `glowup/StaticPhotoAnalysisView.swift` (analyzePhoto function, lines 164-201)

Add state variable for current stage and update it during the analysis:

```swift
@State private var currentStage = "Preparing images..."
```

Use a timer that progresses through stages while `isLoading` is true, giving user visual feedback even though we can't know exact progress.

## 5. Fine-tune Retry Logic

**File**: `glowup/StaticPhotoAnalysisView.swift` (lines 174-192)

Current: 3-4 retry attempts with exponential backoff (3-8s delays)

Update to:

- First attempt: immediate
- If fails: wait 2s, try again
- If fails: wait 4s, try again
- If still fails: show retry button with helpful message

This reduces total wait time while still giving the API chances to recover.

## 6. Optional: Streamline Prompt (if needed)

**File**: `glowup/OpenAIService.swift` (lines 485-573)

Current prompt is ~2000 characters - very detailed and comprehensive.

Only if performance is still slow after image optimization, consider:

- Keeping all JSON structure requirements (essential for parsing)
- Shortening instruction text slightly (e.g., "Principles:" section)
- Maintaining all scoring metrics (they're critical for the analysis)

**Note**: Start with image optimization first. Only touch prompt if still too slow.

## Summary of Expected Improvements

**Speed gains**:

- Image payload reduction: 8-10MB → 3-4MB (~60% reduction)
- Faster upload time: ~5-10s saved
- API processing: ~30-40% faster due to smaller images
- Total time: Currently 60-120s → Target 30-60s

**UX improvements**:

- No more jarring error messages during normal processing
- Clear stage indicators show progress
- Fun tips keep users engaged
- Professional loading experience matches app quality

### To-dos

- [ ] Create AnalysisLoadingView.swift with infinite animation, stage indicators, and rotating tips
- [ ] Update encodeImageData in OpenAIService to use 1024px/0.75 for face, 768px/0.80 for closeups
- [ ] Update processedData in AICoachOptionsView to match new image optimization settings
- [ ] Replace current loading UI in StaticPhotoAnalysisView with new AnalysisLoadingView
- [ ] Add stage progression logic to StaticPhotoAnalysisView that updates during analysis
- [ ] Update retry attempts and delays in analyzePhoto function for better UX
- [ ] Test complete flow and verify speed improvements and loading experience