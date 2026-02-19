AbletonShortcutTrainer (macOS)

What you get
- Native macOS SwiftUI app
- Active recall training: you press the shortcut, the app checks it
- Daily session queue: due reviews + new items
- Searchable shortcut library
- Local progress stored in Application Support

Data
- shortcuts_live12_macos.json is bundled from Ableton Live 12 Manual, Chapter 41 (Live Keyboard Shortcuts).

How to run in Xcode
1. Open Xcode
2. File -> New -> Project -> App
3. Product Name: AbletonShortcutTrainer
4. Interface: SwiftUI, Language: Swift
5. Create the project
6. Replace the generated files with the files in this folder:
   - AbletonShortcutTrainerApp.swift
   - Models.swift
   - KeyStroke.swift
   - AppStore.swift
   - Views.swift
7. Add the Data folder to the project:
   - Drag AbletonShortcutTrainer/Data into Xcode
   - Ensure "Copy items if needed" is checked
8. Build and Run

Notes
- The key monitor is local to the app window.
- Some Ableton shortcuts rely on mouse drag or click. Those entries exist in the dataset, but the trainer expects a key press. You can filter them out by searching for "drag" or "click" in Library.

Keyboard
- Cmd Shift D starts a session from the menu (Trainer -> Start Daily Session).

Progress file location
~/Library/Application Support/AbletonShortcutTrainer/progress_live12_macos.json