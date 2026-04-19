from claude. case for getting rid of sandbox?

# NSDockTilePlugIn & Dock Menu Notes

## Can NSDockTilePlugIn be used in a sandboxed app?

No. `NSDockTilePlugIn` cannot run in a sandboxed app — it runs as a separate plug-in process loaded by the Dock, which operates outside your app's sandbox container. Apple's sandbox prevents the Dock from loading plug-ins from sandboxed apps.

### Alternatives within sandbox:

**`NSDockTile` directly** — update badge or image from within your running app:
```swift
NSApp.dockTile.badgeLabel = "5"
NSApp.dockTile.display()
```

**Dock menu from running app:**
```swift
func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
    let menu = NSMenu()
    menu.addItem(NSMenuItem(title: "My Action", action: #selector(myAction), keyEquivalent: ""))
    return menu
}
```

---

## Building a Dock Menu from current data

Use `applicationDockMenu` in `NSApplicationDelegate` — fires every time the user right-clicks or holds the Dock icon:

```swift
func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
    let menu = NSMenu()
    
    for item in myDataArray {
        let menuItem = NSMenuItem(
            title: item.name,
            action: #selector(dockItemSelected(_:)),
            keyEquivalent: ""
        )
        menuItem.representedObject = item
        menuItem.target = self
        menu.addItem(menuItem)
    }
    
    return menu
}

@objc func dockItemSelected(_ sender: NSMenuItem) {
    guard let item = sender.representedObject as? MyType else { return }
    // main app handles it directly — you're already in the main app
}
```

---

## Keeping Dock Menu alive after main app quits

`applicationDockMenu` only works while the main app is running. Options:

### Option 1: NSDockTilePlugIn (no sandbox only)

**1. Create a new Bundle target** in Xcode named e.g. `DockPlugin`

**2. Main app's `Info.plist`:**
```xml
<key>NSDockTilePlugIn</key>
<string>DockPlugin</string>
```

**3. Plugin principal class:**
```swift
import AppKit

class DockPlugin: NSObject, NSDockTilePlugIn {
    var dockTile: NSDockTile?

    func setDockTile(_ dockTile: NSDockTile?) {
        self.dockTile = dockTile
    }

    func dockMenu() -> NSMenu? {
        let menu = NSMenu()
        
        // read shared data from App Group UserDefaults
        let defaults = UserDefaults(suiteName: "group.com.parker9.DIM-4")
        let items = defaults?.array(forKey: "dockMenuItems") as? [String] ?? []
        
        for item in items {
            let menuItem = NSMenuItem(title: item, action: #selector(itemSelected(_:)), keyEquivalent: "")
            menuItem.target = self
            menu.addItem(menuItem)
        }
        return menu
    }

    @objc func itemSelected(_ sender: NSMenuItem) {
        let defaults = UserDefaults(suiteName: "group.com.parker9.DIM-4")
        defaults?.set(sender.title, forKey: "dockMenuSelection")
        
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.parker9.DIM-4") {
            NSWorkspace.shared.openApplication(at: appURL, configuration: .init(), completionHandler: nil)
        }
    }
}
```

**4. Plugin's `Info.plist`:**
```xml
<key>NSPrincipalClass</key>
<string>DockPlugin.DockPlugin</string>
```

**5. Plugin location** inside main app bundle:
```
DIM-4.app/Contents/PlugIns/DockPlugin.bundle
```
Set up via main app target's Copy Files build phase.

**6. Main app reads selection on launch:**
```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    let defaults = UserDefaults(suiteName: "group.com.parker9.DIM-4")
    if let selection = defaults?.string(forKey: "dockMenuSelection") {
        defaults?.removeObject(forKey: "dockMenuSelection")
        // handle selection
    }
}
```

### Data flow:
- Main app writes menu data to App Group `UserDefaults` whenever it changes
- Plugin reads from `UserDefaults` to build the menu (even when main app is quit)
- User selects item → plugin writes selection to `UserDefaults` → launches main app → main app reads and handles it

### Option 2: LSUIElement main app (sandbox compatible)

Make the main app itself the login item with `LSUIElement = true`. It runs as a background agent with no visible Dock icon or menu bar presence, but `applicationDockMenu` is always available because the app is always running. Cleanest architecture if already shipping a login item helper.

---

## Can a login item helper control the Dock menu?

No. `applicationDockMenu` only works for the app whose Dock icon is being right-clicked. A helper app running in the background has no Dock icon and cannot inject a menu into another app's Dock tile.

Only two legitimate ways to have a Dock menu when the main app isn't running:
1. `NSDockTilePlugIn` — runs inside the Dock process, no sandbox, not App Store compatible
2. Keep the main app running as `LSUIElement = true`

---

## NSDockTilePlugIn and App Group UserDefaults

The plugin runs inside the Dock process, which is sandboxed differently — it may not have access to the App Group container. Safest data sharing for the plugin is a plist file in a location both can read:
```
~/Library/Application Support/com.parker9.DIM-4/
```

---

## Does Apple notarize non-sandboxed apps?

Yes. Notarization and sandboxing are independent:

- **Notarization** — required for all apps distributed outside the Mac App Store. Scans for malware, checks signing. No sandbox required.
- **Sandbox** — only required for Mac App Store distribution.

Without sandbox you can use `NSDockTilePlugIn`, distribute directly, get notarized, and pass Gatekeeper. You just cannot ship on the Mac App Store.

---

## Upgrading from sandboxed to non-sandboxed: UserDefaults migration

Sandboxed `UserDefaults.standard` is stored at:
```
~/Library/Containers/com.parker9.DIM-4/Data/Library/Preferences/
```

Non-sandboxed `UserDefaults.standard` is stored at:
```
~/Library/Preferences/
```

They are completely separate. The unsandboxed update will not find the sandboxed app's preferences.

**App Group UserDefaults** (`UserDefaults(suiteName:)`) are stored at:
```
~/Library/Group Containers/group.com.parker9.DIM-4/
```
This location is accessible to both sandboxed and non-sandboxed apps — anything stored there survives the transition.

### Migration code for UserDefaults.standard:
```swift
func migrateFromSandboxIfNeeded() {
    let sandboxPrefs = "~/Library/Containers/com.parker9.DIM-4/Data/Library/Preferences/com.parker9.DIM-4.plist"
    let url = URL(fileURLWithPath: NSString(string: sandboxPrefs).expandingTildeInPath)
    guard FileManager.default.fileExists(atPath: url.path),
          let dict = NSDictionary(contentsOf: url) as? [String: Any]
    else { return }
    
    dict.forEach { UserDefaults.standard.set($0.value, forKey: $0.key) }
    // optionally delete the old container plist after migration
}
```

A sandboxed app cannot read non-sandboxed `UserDefaults.standard` either — the sandbox confines it to its container. App Group UserDefaults is the only location that works across both.

---

## User experience when moving from sandboxed to non-sandboxed

On first launch after removing the sandbox:

- **Gatekeeper warning** — standard "downloaded from internet" dialog if re-downloaded. Not alarming, same as any first launch.
- **All permission prompts repeat** — camera, microphone, location, contacts, calendar, full disk access, etc. The sandbox container held those grants; outside the container macOS treats it as a different app asking for the first time.
- **Login Items** — `SMAppService` registration is lost, needs to re-register.
- **File access** — any security-scoped bookmarks saved by the sandboxed version are invalid.

---

## Why sandbox outside the Mac App Store?

There is no compelling reason for most apps. Arguments for:

- **Security posture** — limits blast radius if your app is exploited
- **Principle of least privilege** — good engineering practice

In practice the downsides outweigh these for direct distribution:
- Constant friction with entitlements
- Features that simply don't work (e.g. NSDockTilePlugIn)
- User permission fatigue
- Migration headaches
- Helper apps, plugins, and IPC are all more complicated

The vast majority of direct-distribution Mac apps are not sandboxed — Electron apps, developer tools, Adobe apps, Microsoft apps, most utilities. It is really a Mac App Store requirement masquerading as a security recommendation.
