# Demo Recording Guide

## File
`demo.html` - Interactive HTML demo (3-5 minutes)

## How to Record

### Option 1: macOS (QuickTime)
1. Open `demo.html` in Chrome/Safari (full screen: Cmd+Shift+F)
2. Open QuickTime Player
3. File → New Screen Recording
4. Click record, select the browser window
5. Follow the script below
6. Stop recording (Cmd+Control+Esc)
7. Export as MP4

### Option 2: macOS (Built-in)
1. Press Cmd+Shift+5
2. Select "Record Selected Portion" or "Record Entire Screen"
3. Click Options → Show Mouse Clicks
4. Click Record
5. Follow the script below
6. Click Stop in menu bar
7. Video saved to Desktop

### Option 3: OBS Studio (Free, Cross-platform)
1. Download OBS Studio (https://obsproject.com)
2. Add Browser Source → Point to `demo.html`
3. Set resolution to 1920x1080
4. Click "Start Recording"
5. Follow the script below
6. Click "Stop Recording"

## Recording Script (3-5 minutes)

### Slide 1: Title (10 seconds)
**Say:** "Welcome to the SQL to Redshift Converter - an AI-powered tool that accelerates data warehouse migrations using Generative AI."
**Action:** Pause 3 seconds, press → or Space

### Slide 2: The Challenge (20 seconds)
**Say:** "Traditional SQL conversion is painful. Manual work takes 2 to 5 hours per stored procedure. For enterprise migrations with over 1,000 procedures, this means months of delays and high consultant costs. AWS Schema Conversion Tool is rule-based and doesn't leverage the latest Redshift features."
**Action:** Press →

### Slide 3: The Solution (20 seconds)
**Say:** "Our GenAI-powered solution changes the game. It's context-aware, always up-to-date with the latest Redshift features, and supports 6 major databases. Conversion time drops from hours to just 2-5 minutes. The AI even explains what changed and why."
**Action:** Press →

### Slide 4: Live Demo - Input (15 seconds)
**Say:** "Let's see it in action. Here's a typical Oracle SQL query with functions like NVL, DECODE, SYSDATE, and ROWNUM. Watch how the AI converts this to modern Redshift SQL."
**Action:** Hover over the SQL code, then click "Convert to Redshift" button

### Slide 5: Live Demo - Output (30 seconds)
**Say:** "In seconds, we have clean Redshift SQL. Notice the intelligent conversions: NVL became COALESCE, DECODE became a CASE statement for better readability, SYSDATE became GETDATE, and ROWNUM was converted to a modern ROW_NUMBER window function. The AI explains each change, helping teams learn Redshift best practices."
**Action:** Scroll through the output, highlight the changes, pause 5 seconds, press →

### Slide 6: Architecture (20 seconds)
**Say:** "The architecture is fully serverless. CloudFront and S3 serve the frontend, API Gateway and Lambda handle requests, and Amazon Bedrock provides the AI intelligence using Nova Pro or Claude models. DynamoDB caches the latest Redshift features. It costs just 0.006 dollars per conversion and scales automatically."
**Action:** Press →

### Slide 7: Success Metrics (25 seconds)
**Say:** "The results speak for themselves. We're seeing 60 to 90 percent time reduction, up to 750,000 dollars in cost savings per 1,000 procedures, and conversion times of just 2 to 5 minutes. Teams learn Redshift through the AI's explanations, building internal expertise and reducing dependency on consultants."
**Action:** Pause 3 seconds, press →

### Slide 8: Call to Action (15 seconds)
**Say:** "Ready to try it? Visit the URL on screen. No installation required, free to use, with instant results. Choose from multiple AI models based on your needs. Start accelerating your migration today."
**Action:** Pause 5 seconds, fade out

## Tips for Best Results

1. **Resolution:** Record at 1920x1080 (Full HD)
2. **Audio:** Use a good microphone, quiet room
3. **Pace:** Speak clearly, not too fast
4. **Mouse:** Enable "Show mouse clicks" in recording settings
5. **Practice:** Do a test run first
6. **Editing:** Use iMovie (Mac) or DaVinci Resolve (Free) to add:
   - Intro/outro slides
   - Background music (low volume)
   - Zoom effects on important parts
   - Fade transitions

## Auto-Play Mode

For hands-free recording:
1. Open `demo.html`
2. Click "Auto Play" button (advances every 5 seconds)
3. Narrate as slides advance automatically
4. Pause with spacebar if needed

## Export Settings

- Format: MP4 (H.264)
- Resolution: 1920x1080
- Frame rate: 30 fps
- Bitrate: 5-10 Mbps
- Audio: AAC, 128 kbps

## Final Video Length

- Target: 3-5 minutes
- With intro/outro: 4-6 minutes
- Keep it concise and engaging!
