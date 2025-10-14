# 🔧 OpenAI GPT-4 Vision Troubleshooting Guide

## Error: "We couldn't reach GPT-4 Vision"

This guide will help you fix the connection issue step by step.

---

## ✅ **Step 1: Check Xcode Console Logs**

1. **Run your app** in Xcode
2. **Open Console**: View → Debug Area → Activate Console (or press ⌘⇧Y)
3. **Upload a photo**
4. **Look for these log messages:**

### **Scenario A: Missing API Key**
```
[OpenAIService] ❌ Missing OpenAI API key
[OpenAIService] Check: Secrets.plist, Info.plist overrides, or OPENAI_API_KEY env variable
```

**→ Fix:** Follow Step 2 below to add your API key

---

### **Scenario B: Network Error**
```
[OpenAIService] ❌ Network request failed!
[OpenAIService] Error domain: NSURLErrorDomain
[OpenAIService] Error code: -1009
[OpenAIService] → Device is not connected to the internet
```

**→ Fix:** Follow Step 3 below to enable network access

---

### **Scenario C: API Key Invalid**
```
[OpenAIService] API Key loaded: sk-proj-Go... (length: 164)
[OpenAIService] HTTP Status Code: 401
[OpenAIService] ❌ API Error (401): {"error":{"message":"Incorrect API key..."}}
```

**→ Fix:** Your API key is wrong - get a new one from OpenAI

---

## ✅ **Step 2: Add OpenAI API Key to Secrets.plist**

### **Option A: Add Secrets.plist to Xcode (Recommended)**

1. **In Xcode**, right-click on the `glowup` folder in Project Navigator
2. Select **"Add Files to 'glowup'..."**
3. Navigate to `/Users/nick/Desktop/GlowUp/glowup/Secrets.plist`
4. **Check these boxes:**
   - ✅ "Copy items if needed"
   - ✅ "Add to targets: glowup"
5. Click **"Add"**

6. **Verify it's in Build Phases:**
   - Click on `glowup` project icon (blue, at top)
   - Select `glowup` target
   - Go to **"Build Phases"** tab
   - Expand **"Copy Bundle Resources"**
   - **Secrets.plist should be listed there**

7. **Edit Secrets.plist** and add your OpenAI key:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>OPENAI_API_KEY</key>
    <string>sk-proj-YOUR_ACTUAL_KEY_HERE</string>
</dict>
</plist>
```

8. **Clean and rebuild**: Product → Clean Build Folder (⇧⌘K), then build again

### **Option B: Use Environment Variable**

1. In Xcode, click on the **scheme** (top bar, next to your device)
2. Select **"Edit Scheme..."**
3. Go to **"Run"** → **"Arguments"**
4. Under **"Environment Variables"**, click **+**
5. Add:
   - **Name**: `OPENAI_API_KEY`
   - **Value**: `sk-proj-YOUR_ACTUAL_KEY_HERE`
6. Click **"Close"**

---

## ✅ **Step 3: Enable Network Access**

### **For Simulator:**

1. Make sure your Mac has internet
2. **Simulator → I/O → Network Link Conditioner** should be OFF

### **For Physical Device:**

1. Connect device to Wi-Fi
2. In Xcode: **Product → Scheme → Edit Scheme**
3. **Run → Options**
4. Make sure **"Debug executable"** is checked
5. Go to **"Info"** tab
6. Check that network entitlements are enabled

### **Enable Outgoing Connections (if needed):**

If you see **"App Transport Security"** errors:

1. Select your project in Xcode
2. Select the `glowup` target
3. Go to **"Signing & Capabilities"**
4. Click **"+ Capability"**
5. Add **"Outgoing Connections (Client)"** if available

---

## ✅ **Step 4: Verify Your OpenAI API Key**

1. **Get your API key from**: https://platform.openai.com/api-keys
2. **Make sure it starts with**: `sk-proj-` (project key) or `sk-` (old format)
3. **Check it's active**: Go to https://platform.openai.com/usage to see if it's valid
4. **Verify you have credits**: You need billing set up and credits available

---

## ✅ **Step 5: Test with Minimal Code**

Run your app and check the console for:

```
[OpenAIService] Building API request...
[OpenAIService] API Key loaded: sk-proj-Go... (length: 164)  ← Should be ~164 chars
[OpenAIService] Request URL: https://api.openai.com/v1/chat/completions
[OpenAIService] Request headers set: Content-Type, Authorization
[OpenAIService] Request payload size: 328945 bytes
[OpenAIService] Image base64 size: 245821 characters
[OpenAIService] Making API call to OpenAI...
[OpenAIService] Using model: gpt-4o
```

**If you see all these logs**, the request is being sent!

**Then look for:**
```
[OpenAIService] Received response from OpenAI
[OpenAIService] HTTP Status Code: 200  ← SUCCESS!
```

---

## 🐛 **Common Error Codes**

| Code | Meaning | Fix |
|------|---------|-----|
| **-1009** | No internet connection | Connect to Wi-Fi/cellular |
| **-1001** | Request timeout | Internet too slow, try again |
| **-1003** | Cannot find host | DNS issue, check internet |
| **-1200** | SSL/TLS error | Update iOS, check date/time |
| **401** | Invalid API key | Get new key from OpenAI |
| **429** | Rate limit | Wait a few minutes |
| **500** | OpenAI server error | Try again later |

---

## 📊 **Expected Console Output (Success)**

When everything works, you should see:

```
========== [OpenAIService] PHOTO ANALYSIS START ==========
[OpenAIService] Encoded image size: 245821 characters
[OpenAIService] Prompt length: 1523 characters
[OpenAIService] Calling GPT-4 Vision API...
[OpenAIService] Building API request...
[OpenAIService] API Key loaded: sk-proj-Go... (length: 164)
[OpenAIService] Request URL: https://api.openai.com/v1/chat/completions
[OpenAIService] Request headers set: Content-Type, Authorization
[OpenAIService] Request payload size: 328945 bytes
[OpenAIService] Image base64 size: 245821 characters
[OpenAIService] Making API call to OpenAI...
[OpenAIService] Using model: gpt-4o
[OpenAIService] Received response from OpenAI
[OpenAIService] HTTP Status Code: 200
[OpenAIService] ✅ Success! Parsing response...
[OpenAIService] Raw API response:
{"id":"chatcmpl-...","object":"chat.completion","created":1728...
[OpenAIService] ✅ Extracted content from response
[OpenAIService] ✅ GPT-4 Vision response received!
[OpenAIService] Response length: 1245 characters
[OpenAIService] Response preview:
{"faceShape":"Oval","skinUndertone":"Warm"...
[OpenAIService] Parsing analysis response...
[OpenAIService] Extracted JSON from response (found { } markers)
[OpenAIService] Attempting to decode AnalysisResponse struct...
[OpenAIService] ✅ Successfully decoded! Building PhotoAnalysisVariables...
[OpenAIService] ✅ PhotoAnalysisVariables created successfully
[OpenAIService] - Face Shape: Oval
[OpenAIService] - Eye Color: Brown
[OpenAIService] - Lighting Type: Natural
[OpenAIService] - Seasonal Palette: Autumn
[OpenAIService] ✅ Successfully parsed analysis!
[OpenAIService] Glow Score: 8.2/10
[OpenAIService] Confidence: 8.5/10
[OpenAIService] Face Shape: Oval
[OpenAIService] Seasonal Palette: Autumn
[OpenAIService] Eye Color: Brown
[OpenAIService] Lighting Quality: 8.5/10
[OpenAIService] Summary: Your natural warmth shines through...
========== [OpenAIService] ANALYSIS COMPLETE ==========
```

---

## 🚨 **Quick Checklist**

Before asking for help, verify:

- [ ] Secrets.plist exists at `/Users/nick/Desktop/GlowUp/glowup/Secrets.plist`
- [ ] Secrets.plist contains `OPENAI_API_KEY` key
- [ ] API key is valid (starts with `sk-proj-` or `sk-`)
- [ ] Secrets.plist is added to Xcode project
- [ ] Secrets.plist is in "Copy Bundle Resources" build phase
- [ ] Device/simulator has internet connection
- [ ] Cleaned build folder (⇧⌘K)
- [ ] Rebuilt app after adding key
- [ ] Checked Xcode console for error messages
- [ ] OpenAI account has billing set up

---

## 🎯 **Still Not Working?**

**Copy the console output** (everything starting with `[OpenAIService]`) and share it. The logs will tell exactly what's failing!

Look for these key lines:
1. **API Key loaded**: Shows if key is present
2. **Making API call**: Shows request is being sent
3. **HTTP Status Code**: Shows server response
4. **Error domain/code**: Shows network errors

---

## 💡 **Pro Tips**

1. **Use Xcode console filter**: Type `OpenAIService` in the filter box to see only relevant logs
2. **Test internet**: Open Safari on simulator/device and browse a website
3. **Verify API key**: Copy it from https://platform.openai.com/api-keys
4. **Check billing**: https://platform.openai.com/usage - you need credits
5. **Try smaller image**: If request is too large (>20MB), it might fail

---

## ✅ **Success Indicators**

You'll know it's working when:
- ✅ Console shows **"HTTP Status Code: 200"**
- ✅ You see **"✅ Successfully parsed analysis!"**
- ✅ Face shape, eye color, etc. are detected (not "Unknown")
- ✅ Glow score is a real number (not 0.0)
- ✅ Different photos give different results

---

**Updated with comprehensive network debugging** ✨
**Run the app and check console - it will tell you exactly what's wrong!**

