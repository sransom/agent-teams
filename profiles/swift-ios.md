# Profile: swift-ios

Swift / iOS project. Detected by `*.xcodeproj`, `*.xcworkspace`, or `Package.swift` at repo root.

## Commands

```bash
LINT="swiftlint"                    # requires swiftlint installed; skip gracefully if missing
TEST="xcodebuild test -scheme {scheme} -destination 'platform=iOS Simulator,name=iPhone 15'"
BUILD="xcodebuild build -scheme {scheme}"
TYPECHECK=""                        # swiftc covers this during build
```

`{scheme}` must be extracted from the project — list with `xcodebuild -list -project {name}.xcodeproj` and pick the main scheme.

For Swift Package Manager libraries (no Xcode project, just `Package.swift`):
```bash
LINT="swiftlint"
TEST="swift test"
BUILD="swift build"
```

## Test conventions

- XCTest: test classes in `{Module}Tests` targets
- Swift Testing framework (Swift 6+): `@Test` annotations
- Test files: `*Tests.swift`

## File conventions

- Source: `*.swift`
- `Package.swift` defines SPM targets + dependencies
- `.xcodeproj` / `.xcworkspace` for Xcode-managed projects

## Commit conventions

- `.pre-commit-config.yaml`: `SKIP=all git commit`
- Some teams use fastlane — check for `fastlane/Fastfile`
- No husky typically
