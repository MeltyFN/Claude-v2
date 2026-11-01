# Sermon Notes for iPhone: Live Activity and locked-screen dictation

This folder turns the Sermon Notes web app into a native iPhone app. The native version adds three things a web app can't do:

- **A Live Activity**: a lock-screen card and the Dynamic Island showing **"Listening · 12:31"**, the latest words heard, and a **Stop** button.
- **Dictation that keeps going while the phone is locked**, using Apple's own speech recognition.
- Everything else (design, notes, auto-fill, summaries) is the same app, running inside the native shell.

The website on Netlify is not affected by anything in this folder.

---

## What you need

| | |
|---|---|
| **A Mac** with **Xcode** (free in the Mac App Store) | Required. iPhone apps can only be built on a Mac. |
| **Node.js 20 or newer** | From [nodejs.org](https://nodejs.org) |
| **An iPhone on iOS 17 or newer** | Live Activities need iOS 16.2+. The Stop button on the lock screen needs iOS 17+. |
| **An Apple ID** | A free Apple ID works for testing, but the app stops opening after **7 days** and must be run from Xcode again. The **Apple Developer Program ($99/year)** removes that limit and lets you publish on the App Store. |

---

## One-time setup (about 20 minutes)

### 1. Get the code and install
In Terminal:
```bash
git clone https://github.com/MeltyFN/Claude-v2.git
cd Claude-v2/native
npm install
npm run build
npx cap add ios
npx cap open ios
```
Xcode opens with the **App** project.

> Want a different app ID? Edit `appId` in `native/capacitor.config.json` **before** `npx cap add ios`. It must be unique, like `com.yourname.sermonnotes`.

### 2. Add the app's Swift files
1. In Xcode's left sidebar, right-click the yellow **App** folder (inside the blue **App** project), then choose **Add Files to "App"…**.
2. Go to `Claude-v2/native/ios-src/` and select **both** the `App` and `Shared` folders.
3. In the options:
   - **untick** "Copy items if needed", so future updates apply automatically
   - choose **Create groups**
   - tick the **App** target
4. Click **Add**.

### 3. Let the app use the microphone and keep listening when locked
Click the blue **App** project, then the **App** target.
1. **Info** tab: hover any row, click **+**, and add these three keys:

   | Key | Type | Value |
   |---|---|---|
   | Privacy - Microphone Usage Description | String | `Sermon Notes listens to the sermon so it can write your notes.` |
   | Privacy - Speech Recognition Usage Description | String | `Sermon Notes turns the sermon into text for your notes.` |
   | Supports Live Activities | Boolean | `YES` |

2. **Signing & Capabilities** tab: click **+ Capability** and add **Background Modes**. Then tick **Audio, AirPlay, and Picture in Picture**. This is what keeps dictation running while the phone is locked.

### 4. Add the Live Activity
1. **File, then New, then Target…**, choose **Widget Extension**, and click **Next**.
2. Set Product Name to `SermonLiveActivity`.
   - tick **Include Live Activity**
   - untick "Include Control" and "Include Configuration App Intent" if they're shown
3. Click **Finish**. If Xcode asks to activate the new scheme, click **Don't Activate**.
4. In the sidebar, open the new **SermonLiveActivity** folder.
   - Delete every `.swift` file in it, choosing **Move to Trash**. Keep `Info.plist` and `Assets`.
   - Right-click the folder, then **Add Files to "App"…**, and pick `native/ios-src/Widget/SermonLiveActivity.swift`.
   - In the options, untick "Copy items if needed" and tick **only** the **SermonLiveActivityExtension** target.
5. Select both files in **Shared** (`DictationAttributes.swift` and `StopDictationIntent.swift`). In the right panel's **File inspector**, under **Target Membership**, tick **both App and SermonLiveActivityExtension**.
6. Click the **SermonLiveActivityExtension** target. On the **General** tab, set **Minimum Deployments** to **iOS 17.0**.

### 5. Connect the dictation bridge
1. In the sidebar, open **App, then App, then Main.storyboard**, and click the **Bridge View Controller**.
2. In the right panel's **Identity inspector**, set **Class** to `MainViewController`.

### 6. Sign and run on your iPhone
1. For **both** the **App** and **SermonLiveActivityExtension** targets, go to **Signing & Capabilities** and pick your Apple ID under **Team**.
   - If it isn't listed: Xcode, then Settings, then Accounts, then **+**.
2. On the iPhone, turn on **Developer Mode** (Settings, then Privacy & Security, then Developer Mode) and restart when asked.
3. Plug in the iPhone, choose it at the top of Xcode, and press **▶ Run**.
4. The first time only: on the iPhone, go to Settings, then General, then **VPN & Device Management**, tap your Apple ID, and tap **Trust**.

---

## Using it
1. Open **Sermon Notes**, start a note, and tap **Start dictation**. Allow the microphone and speech recognition.
2. **Lock the phone.** The lock screen shows the Live Activity: "Listening · 0:42", the sermon title, the latest words, and **Stop**.
3. On iPhones with a Dynamic Island, the island shows a red waveform and the timer. Press and hold it to see the words and the Stop button.
4. Tap **Stop** on the lock screen, or in the app. Your transcript, summary and auto-filled sections are all there when you open the app.

Pocket mode still works, but you don't need it in the native app: just lock the phone.

## After updating the web app
Whenever the app changes (for example after merging a pull request):
```bash
cd Claude-v2 && git pull
cd native && npm run build && npx cap sync ios
```
Then press **▶ Run** in Xcode again.

---

## Troubleshooting
| Problem | Fix |
|---|---|
| No Live Activity on the lock screen | Settings, then **Sermon Notes**, then turn **Live Activities** on. Also check "Supports Live Activities = YES" (step 3). |
| Dictation stops when the phone locks | Step 3: Background Modes, then **Audio** must be ticked. |
| Build error "Cannot find type 'DictationAttributes'" or "'StopDictationIntent'" | Step 4.5: the two **Shared** files must be in **both** targets. |
| The app opens but dictation uses the old web version | Step 5: the storyboard class must be `MainViewController`. |
| "Permission was denied" | Settings, then Sermon Notes, then turn on **Microphone** and **Speech Recognition**. |
| No Stop button on the lock screen | It needs iOS 17 or newer. On iOS 16, tap the card to open the app and stop there. |
| App won't open after a week | Free Apple IDs expire apps after 7 days. Run it from Xcode again, or join the Apple Developer Program. |

## Good to know
- **Internet:** Apple's speech recognition may send audio to Apple to turn it into text, like Siri dictation. It works best with a connection.
- **Usage limits:** Apple doesn't publish exact limits for continuous dictation. Very long sessions could occasionally be cut short. If that happens, the app keeps everything heard up to that point.
- **Battery:** listening for a full sermon uses some battery, similar to recording a voice memo.
- **The Live Activity** ends about 10 seconds after you stop.

## What's in this folder
| File | What it does |
|---|---|
| `ios-src/App/DictationManager.swift` | Native dictation: listens while locked and runs the Live Activity |
| `ios-src/App/SermonDictationPlugin.swift` | Lets the web app start, stop and collect dictation |
| `ios-src/App/MainViewController.swift` | Loads the plugin when the app starts |
| `ios-src/Shared/DictationAttributes.swift` | What the Live Activity shows |
| `ios-src/Shared/StopDictationIntent.swift` | The lock-screen **Stop** button |
| `ios-src/Widget/SermonLiveActivity.swift` | The lock-screen card and Dynamic Island design |
| `capacitor.config.json`, `package.json`, `scripts/build-web.mjs` | Native app setup; copies the web app into the iPhone build |
