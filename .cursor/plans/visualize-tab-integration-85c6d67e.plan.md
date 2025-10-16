<!-- 85c6d67e-1ba3-474c-aabc-c33cc9f17143 4c5ede04-ea46-45e6-8b89-3cd341a4eb71 -->
# Add Visualize Tab with Nano Banana AI Integration

## 1. API Setup & Configuration

### Add Gemini API Key to Secrets

- Obtain API key from [Google AI Studio](https://aistudio.google.com/)
- Add `GEMINI_API_KEY` to `Secrets.plist` and `Secrets.swift`
- Follow same pattern as existing OpenAI key management

## 2. Core Data Model Extension

### Create New Entities in `glowup.xcdatamodel/contents`

```xml
<entity name="VisualizationSession" representedClassName="VisualizationSession">
  <attribute name="id" attributeType="UUID"/>
  <attribute name="createdAt" attributeType="Date"/>
  <attribute name="baseImage" attributeType="Binary" allowsExternalBinaryDataStorage="YES"/>
  <attribute name="analysisReference" optional="YES" attributeType="UUID"/> <!-- links to PhotoSession -->
  <relationship name="edits" toMany="YES" destinationEntity="VisualizationEdit"/>
</entity>

<entity name="VisualizationEdit" representedClassName="VisualizationEdit">
  <attribute name="id" attributeType="UUID"/>
  <attribute name="timestamp" attributeType="Date"/>
  <attribute name="prompt" attributeType="String"/>
  <attribute name="resultImage" attributeType="Binary" allowsExternalBinaryDataStorage="YES"/>
  <attribute name="isPreset" attributeType="Boolean"/>
  <attribute name="presetCategory" optional="YES" attributeType="String"/>
</entity>
```

## 3. Create Gemini/Nano Banana Service

### New File: `GeminiService.swift`

- API client for Google Gemini with Nano Banana capabilities
- **CRITICAL**: Use correct MIME types (`text/plain` or `application/json`)
- Image editing with natural language prompts using Gemini Vision
- Multi-image fusion support
- Error handling and retry logic

Key methods:

- `generateImageEdit(baseImage:prompt:) async throws -> UIImage`
- `applyPreset(baseImage:category:style:analysis:) async throws -> UIImage`

**Important Implementation Notes:**
```swift
// CORRECT: For image generation/editing with Gemini 2.5 Flash Image
let request = GenerateContentRequest(
    model: "gemini-2.5-flash-image",
    contents: [prompt, baseImage], // Text prompt + UIImage
    config: GenerateContentConfig(
        responseModalities: ["Image"], // Return only images, no text
        imageConfig: ImageConfig(
            aspectRatio: "1:1" // or "4:3", "16:9", etc.
        )
    )
)

// For multi-turn image editing (conversational editing):
let editingRequest = GenerateContentRequest(
    model: "gemini-2.5-flash-image", 
    contents: [previousImage, newPrompt], // Previous result + new edit prompt
    config: GenerateContentConfig(
        responseModalities: ["Image"]
    )
)
```

**Key Implementation Details:**
- Use model: `"gemini-2.5-flash-image"` for all image generation/editing
- Set `responseModalities: ["Image"]` to get only images (no text responses)
- For MIME type issues: Don't set `responseMimeType` at all for image generation
- Use `aspectRatio` in `imageConfig` to control output dimensions
- Images are returned as `inline_data` in response parts
- Each image costs 1290 tokens (flat rate regardless of size up to 1024x1024)

**Error Fixes:**
- Remove `responseMimeType` from image generation requests entirely
- Use `responseModalities: ["Image"]` instead
- Model automatically handles image output format
- No need for `generationConfig` for basic image generation

**Appearance Editing Prompting Strategies:**
```swift
// For hairstyle changes:
"Using the provided image, change only the hairstyle to [specific style]. Keep the person's face, features, and clothing exactly the same, preserving the original lighting and photo quality."

// For makeup changes:
"Using the provided image, apply [makeup style] makeup while keeping the person's face shape, hair, and clothing unchanged. Maintain the original photo's lighting and quality."

// For clothing changes:
"Using the provided image, change only the clothing to [specific outfit description] while keeping the person's face, hair, and background exactly the same."

// For hair color changes:
"Using the provided image, change only the hair color to [color] while preserving the person's face, features, clothing, and the original photo quality."
```

## 4. Visualization Models

### New File: `VisualizationModels.swift`

Define preset categories based on analysis:

- `VisualizationPreset`: hairstyles, hair colors, makeup looks, clothing styles
- `PresetCategory`: enum for categories
- `PresetOption`: individual style options with AI prompts
- Dynamic preset generation based on `PhotoAnalysisVariables`

## 5. Update Tab Navigation

### Modify `GlowUpTabView.swift`

```swift
enum GlowTab {
    case home
    case coach
    case results
    case visualize  // NEW
}

// Add tab item in TabView:
VisualizeView()
    .tabItem {
        Label("Visualize", systemImage: "wand.and.stars.inverse")
    }
    .tag(GlowTab.visualize)
```

## 6. Create Main Visualize View

### New File: `VisualizeView.swift`

Main visualization interface with:

- **Session List**: Shows saved visualization sessions (like ResultsView)
- **"New Visualization" button**: Start fresh session
- **Empty state**: Prompt to start first visualization
- Navigation to active session detail view

## 7. Create Visualization Session View

### New File: `VisualizationSessionView.swift`

Interactive editing interface:

- **Image Display**: Current visualization result (large, centered)
- **Image Source Options**: 
  - "Use from Analysis" button (if coming from Results)
  - Camera capture button
  - Photo library picker
- **Edit History**: Horizontal scrollable thumbnail gallery showing all edits
- **Preset Grid**: Category-based presets (4-6 categories, 3-4 options each)
  - Hair Styles (based on face shape from analysis)
  - Hair Colors (based on seasonal palette)
  - Makeup Looks (natural, glam, dramatic based on analysis)
  - Clothing Colors (from bestColors array)
  - Accessories suggestions
  - Style variations
- **Text Input Bar**: Bottom fixed bar for custom prompts
- **Loading State**: While Gemini API processes request
- **Undo functionality**: Tap any edit thumbnail to restore that state

## 8. Create Extensions for Core Data

### New File: `VisualizationSession+Helpers.swift`

Extensions for:

- Decode/encode base image as UIImage
- Fetch all edits sorted by timestamp
- Get latest edit result
- Delete session helper

## 9. Integrate with Results Tab

### Modify `ResultsView.swift` (sessionCard)

Add "Visualize This Look" button within each session card:

```swift
Button {
    // Navigate to Visualize tab
    // Pass session image and analysis
} label: {
    Label("Visualize This Look", systemImage: "wand.and.stars")
}
```

Use environment or shared state to pass image/analysis data between tabs.

## 10. Create Preset Generator

### New File: `VisualizationPresetGenerator.swift`

Generates contextual presets based on `PhotoAnalysisVariables`:

- Parse face shape → suggest flattering hairstyles
- Parse seasonal palette → suggest hair colors
- Parse bestColors → suggest clothing/makeup colors
- Parse makeupStyle → suggest makeup intensity variations
- Parse eyeColor → suggest complementary eye makeup

Returns `[VisualizationPreset]` array for UI display.

## 11. State Management

### Create `VisualizationViewModel.swift`

Manages:

- Active session state
- Current image display
- Edit history
- API request queue
- Loading/error states
- Save/load sessions from Core Data
- Image picker presentation

## 12. UI Components

### Create `VisualizationComponents.swift`

Reusable components:

- `PresetCard`: Displays preset option with icon and label
- `EditThumbnail`: Shows edit in history with timestamp
- `PromptInputBar`: Bottom text field with send button
- `ImageSourcePicker`: Sheet for camera/library/analysis options
- `LoadingOverlay`: Shows progress during API calls

## 13. Testing & Polish

- Handle API rate limits and errors gracefully
- Implement image compression before API calls (reduce data transfer)
- Add haptic feedback for interactions
- Ensure smooth animations between edits
- Test with various image sizes and formats
- Add analytics for feature usage
- Implement image caching to avoid redundant API calls

## Files to Create

1. `GeminiService.swift` - API integration
2. `VisualizationModels.swift` - Data models
3. `VisualizeView.swift` - Main tab view
4. `VisualizationSessionView.swift` - Active session interface
5. `VisualizationViewModel.swift` - State management
6. `VisualizationPresetGenerator.swift` - Smart preset generation
7. `VisualizationComponents.swift` - Reusable UI components
8. `VisualizationSession+Helpers.swift` - Core Data helpers

## Files to Modify

1. `GlowUpTabView.swift` - Add visualize tab
2. `ResultsView.swift` - Add "Visualize This Look" button
3. `Secrets.swift` - Add Gemini API key accessor
4. `Secrets.plist` - Store Gemini API key
5. `glowup.xcdatamodel/contents` - Add new entities

## Key Features Summary

✓ Multiple visualization sessions with independent images

✓ Iterative editing on same image with full history

✓ Smart presets based on analysis results

✓ Custom text prompts for any change

✓ Camera/library/analysis image sources

✓ Save and revisit past visualizations

✓ Side-by-side comparison via edit history

✓ Seamless integration with existing Results tab

### To-dos

- [ ] Add Gemini API key to Secrets and create GeminiService for Nano Banana integration
- [ ] Add VisualizationSession and VisualizationEdit entities to Core Data model
- [ ] Create VisualizationModels.swift with preset structures and enums
- [ ] Create VisualizationPresetGenerator that generates smart presets from PhotoAnalysisVariables
- [ ] Create VisualizationViewModel for state management and Core Data operations
- [ ] Build reusable UI components (PresetCard, EditThumbnail, PromptInputBar, etc.)
- [ ] Create VisualizationSessionView with image display, presets, text input, and edit history
- [ ] Create VisualizeView showing saved sessions and new session button
- [ ] Add visualize tab to GlowUpTabView
- [ ] Add 'Visualize This Look' button in ResultsView cards with navigation logic
- [ ] Test full flow, add error handling, optimize image sizes, and polish UI/UX