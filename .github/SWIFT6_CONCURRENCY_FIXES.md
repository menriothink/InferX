# Swift 6 Concurrency Safety Fixes

## Overview

Encountered Swift 6 strict concurrency checking errors during GitHub Actions builds, while local Xcode builds succeeded.

## Error Message

```
error: main actor-isolated property 'navigationTitle' can not be mutated from a Sendable closure
    navigationTitle = $0
    ^
```

---

## Root Cause

### Swift Concurrency Model

```swift
// ❌ Problem Code
@State private var navigationTitle: LocalizedStringKey = ""

detail()
    .onPreferenceChange(UltramanNavigationTitleKey.self) {
        navigationTitle = $0  // Error: Cannot mutate @MainActor property from Sendable closure
    }
```

**Why Does This Error Occur?**

1. **`@State` properties** are isolated by `@MainActor`
2. **`.onPreferenceChange()` closure** is inferred as `@Sendable`
3. **`@Sendable` closures** cannot capture and mutate non-`Sendable` mutable state
4. In Swift 6 strict mode, this is a compilation error

---

## Environment Differences

| Environment | Concurrency Check | Behavior |
|-------------|-------------------|----------|
| **Local Xcode** | Minimal/Targeted | ⚠️ Warning (compiles) |
| **GitHub Actions** | Complete (strict) | ❌ Error (build fails) |

**Reasons**:
- Xcode uses more lenient concurrency checking by default
- GitHub Actions uses `xcodebuild` command-line tool with strict checking enabled by default
- Swift 6 introduces stricter data race protection

---

## Solution

### ✅ Method 1: Use `Task { @MainActor in }` (Recommended)

```swift
// ✅ Fixed Code
detail()
    .onPreferenceChange(UltramanNavigationTitleKey.self) { newTitle in
        Task { @MainActor in
            navigationTitle = newTitle
        }
    }
    .onPreferenceChange(UltramanNavigationToolbarKey.self) { newItems in
        Task { @MainActor in
            toolbarItems = newItems
        }
    }
```

**Advantages**:
- ✅ Explicitly specifies execution on MainActor
- ✅ Type-safe
- ✅ Complies with Swift 6 concurrency model
- ✅ No performance impact

---

### Alternative Solutions (Not Recommended)

#### Method 2: Use `@preconcurrency`

```swift
// Not recommended: Only suppresses warnings
.onPreferenceChange(UltramanNavigationTitleKey.self) { @MainActor newTitle in
    navigationTitle = newTitle
}
```

#### Method 3: Lower Concurrency Check Level

Set in `project.pbxproj`:
```
SWIFT_STRICT_CONCURRENCY = minimal
```

**Disadvantages**:
- ❌ Only hides the problem without truly solving it
- ❌ Loses Swift 6 concurrency safety benefits
- ❌ May introduce data races

---

## Fixed Files

### `UltramanNavigationSplitView.swift`

**Changes Made**:
1. Update to `navigationTitle` property
2. Update to `toolbarItems` property

**Code Location**: Lines 128 and 131

---

## Technical Details

### Swift 6 Concurrency Key Concepts

#### 1. **Actor Isolation**

```swift
@MainActor  // Executes on main thread
class ViewModel {
    var data: String = ""  // Automatically protected by MainActor
}
```

#### 2. **Sendable Protocol**

```swift
// Sendable indicates safe cross-concurrency-domain transfer
struct SafeData: Sendable {
    let value: Int  // Immutable, safe
}
```

#### 3. **Closure Concurrency**

```swift
// Compiler infers closure as @Sendable
someAsyncFunction { value in
    // This closure may execute on any thread
    // Cannot directly mutate @MainActor isolated properties
}
```

---

## Best Practices

### ✅ Recommended Approaches

1. **Explicitly Use `Task { @MainActor in }`**
   ```swift
   .onChange(of: someValue) { newValue in
       Task { @MainActor in
           self.property = newValue
       }
   }
   ```

2. **Mark Entire Function with `@MainActor`**
   ```swift
   @MainActor
   func updateUI() {
       // All code executes on main thread
       self.title = "New Title"
   }
   ```

3. **Use `MainActor.run`**
   ```swift
   Task {
       let data = await fetchData()  // Background
       await MainActor.run {
           self.data = data  // Main thread
       }
   }
   ```

### ❌ Avoid These Approaches

1. **Don't use `@preconcurrency` to bypass checking**
2. **Don't lower global concurrency check level**
3. **Don't use `nonisolated(unsafe)` (unless absolutely necessary)**

---

## Verify Fix

### Local Testing

```bash
# Build with strict concurrency checking
xcodebuild build \
  -project InferX.xcodeproj \
  -scheme InferX \
  -destination 'generic/platform=macOS' \
  SWIFT_STRICT_CONCURRENCY=complete
```

### GitHub Actions

After pushing code, check build logs:
```
✅ Build succeeded
No concurrency warnings or errors
```

---

## Related Resources

- [Swift Evolution SE-0337: Incremental migration to concurrency checking](https://github.com/apple/swift-evolution/blob/main/proposals/0337-support-incremental-migration-to-concurrency-checking.md)
- [Swift Concurrency Documentation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [WWDC 2023: Swift Concurrency Beyond the Basics](https://developer.apple.com/videos/play/wwdc2023/)

---

## Summary

| Issue | Cause | Solution |
|-------|-------|----------|
| Concurrency Error | `@Sendable` closure mutates `@MainActor` property | Use `Task { @MainActor in }` |
| Build Difference | GitHub Actions uses strict checking | Fix concurrency safety issues |
| Best Practice | Explicitly manage Actor isolation | Follow Swift 6 concurrency model |

**🎯 Key Takeaway**: Swift 6's concurrency model prevents data races at compile time. These fixes not only resolve build issues but also improve thread safety throughout the codebase!
