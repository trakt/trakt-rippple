# Rippple contributor guide

This file applies to the whole repository. Keep changes simple, focused, and consistent with nearby code. For setup and contribution details, also read `README.md` and `CONTRIBUTING.md`.

## Project shape

- Rippple is a native Trakt client for iPhone, iPad, and Mac Catalyst. The deployment target is version 26 and the project uses Swift 5 language mode.
- Open and build `Rippple.xcodeproj`. Dependencies are managed with Swift Package Manager.
- The main `Rippple` app target embeds `WidgetExtension`, `WidgetIntent`, and `NotificationService`.
- The codebase is UIKit-first and still uses storyboards and XIBs. SwiftUI is used for suitable standalone, configuration, widget, and live-activity views.
- There is no committed test target or CI workflow. Validate focused changes with SwiftFormat, a relevant build, and a manual smoke test.

## Working principles

- Make the smallest coherent change that solves the problem. Avoid unrelated cleanup, broad rewrites, or new abstractions for one use.
- Follow the architecture and terminology already used by the feature. Put code beside related code; do not reorganize folders without a clear need.
- Preserve existing behavior on iPhone, iPad, and Mac Catalyst. Check nearby `targetEnvironment(macCatalyst)` handling before adding platform-specific UI.
- Do not add a dependency or test framework without prior discussion. Prefer Apple APIs and existing project utilities.
- Never commit or expose `Rippple/Secrets.swift`, tokens, API keys, signing data, or user data. Use `Rippple/Secrets-Template.swift` only as the public schema.
- Preserve unrelated working-tree changes; do not format or rewrite untouched files.

## Architecture and coding conventions

### UI

- Prefer UIKit when extending an existing controller, storyboard, XIB, table, or collection flow. Use SwiftUI when the feature is self-contained and it clearly reduces complexity.
- Reuse existing cells, hosting controllers, colors, image helpers, loading indicators, and message presentation before creating another UI system.
- Perform UI mutation and user-facing message presentation on the main thread. Preserve Dynamic Type, accessibility, reuse, empty/loading/error states, and Mac Catalyst behavior.
- New Swift, storyboard, XIB, or asset files must be added to the correct Xcode group, target membership, and build phase. Keep `project.pbxproj` edits minimal.

### Managers, state, and events

- Shared domain state normally belongs in a focused `*Manager` singleton with `static let shared`, a private initializer, and an explicit `setup()` when lifecycle registration is needed.
- Use Receiver for the existing broadcast/listen architecture. Name channels `on…Transmitter` and `on…Receiver`, retain a `DisposeBag`, and dispose every long-lived listener.
- Capture `self` weakly in escaping closures that are owned by controllers or long-lived services. In nested escaping closures, declare `[weak self]` at every enclosing closure level so an inner weak capture does not conflict with an implicitly strong outer capture. Unwrap with `guard let self = self else { return }` at the start of each closure that directly uses `self`; an outer closure that only passes the weak capture into a nested closure does not need to unwrap it. When the guard has additional conditions, keep the full `self = self` binding before them. Do not use optional chaining or shorthand `guard let self` for this pattern.
- Synchronize shared mutable state only when it is genuinely accessed concurrently. Prefer main-thread or queue confinement when that keeps the code simpler; use nearby `NSLock` and snapshot/update patterns only when a lock is really needed. Never hold a lock during network or UI work. Clear account-specific state on logout and broadcast only after state is consistent.

### Networking and models

- Keep Trakt and TMDb networking in their existing Moya layers. Add endpoint cases to the relevant `*APIService`, use the shared provider/decoder, and put reusable pagination or mapping in `*APIProvider` extensions.
- Do not introduce direct `URLSession` calls in views or controllers. Use Alamofire directly only inside the existing Moya session, monitor, and retry infrastructure.
- Choose provider variants deliberately; authentication, caching, rating monitoring, and debug logging differ. Treat API data as fallible: filter status codes, surface failures, guard identifiers and indices, and avoid new force unwraps for remote data.
- Run network and decoding work off the main thread, then return to the main thread for UI or UI-observed state. In files importing Moya, `_Concurrency.Task` avoids the `Moya.Task` name collision.

### Persistence and caching

- Use `UserDefaults` for user settings, `KeychainStore` for authentication tokens, and TinyStorage for Codable cache snapshots.
- Use LRUCache for bounded in-memory caches. Give cached data an invalidation or expiration path instead of assuming it remains current.
- Reuse `ImagesManager` to resolve image URLs and Kingfisher for image loading and caching; follow the options used by nearby image views.
- Prefer pagination and correct cache invalidation over eagerly loading large datasets.

## Swift style

- `.swiftformat` is authoritative. Use four-space indentation, no trailing commas, inline pattern bindings, and the configured parameter wrapping. Do not hand-format against the tool.
- Prefer `let` over `var`, early `guard` exits over deep nesting, and `final` for classes not designed for inheritance.
- Refer to a type explicitly by its concrete name; do not use `Self`, including from within that type's own implementation.
- Default implementation details to `private`. Use `fileprivate` or wider access only when the existing feature boundary requires it.
- Use descriptive project vocabulary and existing type suffixes such as `ViewController`, `Manager`, `Model`, `Cell`, `View`, and `Provider`.
- Group protocol conformances and substantial helpers in extensions. Use `// MARK: - …` in longer files. Comment only non-obvious intent, invariants, workarounds, or public APIs.
- Do not introduce warnings. Preserve exhaustive switch behavior and handle unsupported or unknown cases safely.

## Third-party libraries

Use each dependency through its established boundary:

- **Receiver**: application events and observable manager state.
- **Moya**: Trakt/TMDb endpoints, requests, responses, and decoding; **Alamofire** supports Moya sessions and retry behavior.
- **Kingfisher**: remote image loading and caching; **LRUCache** and **TinyStorage** cover other memory and disk caches.
- **Haring**: Markdown rendering through the parsers in `Rippple/Markdown`.
- **NVActivityIndicatorView**: legacy loading UI; reuse the project animation in `Rippple/RippleLoader` or a nearby cell/controller pattern.
- **YouTubePlayerKit**, **SFSymbols**, **Emoji**, **HTMLEntities**, and **Toast**: specialized uses already isolated to trailers, symbol picking, text utilities, and app messages. Extend those call sites instead of duplicating their behavior.
- **ReactiveSwift** and **RxSwift** are resolved transitively; the app does not use them directly.

When dependencies change, update the Xcode package references, the relevant `Package.resolved`, and `THIRD_PARTY_NOTICES.md`. CocoaPods has been removed; do not reintroduce it.

## Validation and commits

1. Format only the Swift files you changed when needed: `Scripts/swiftformat.sh --format --changed`.
2. Run the required lint gate: `Scripts/swiftformat.sh --lint --strict --changed`.
3. Build the affected scheme in Xcode. Build the relevant extension scheme too when target-shared code changes.
4. Smoke-test the changed flow on a simulator or device, including logged-out, empty, loading, error, and Mac Catalyst paths when relevant.

Keep commits focused. The repository convention is a short, imperative gitmoji subject, for example `🐛 Fix stale poster reuse`, `✨ Add list sorting`, or `⚡️ Cache browse rail data`.
