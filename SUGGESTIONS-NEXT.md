# PlugInKit — Additional Improvements for Robustness & Dynamism

**Companion to:** `SUGGESTIONS.md` (Dec 2025)
**Status:** Proposed roadmap, not yet implemented

## Context

PlugInKit has matured significantly since the original `SUGGESTIONS.md` was written. Many of its critical-gap items have shipped:

- Hot-reload (`PKPlugInManager+HotReload`)
- Resource limits (`PKConnection+ResourceLimits`)
- Dependency graph (`PKPlugInManager+Dependencies`)
- Compatibility / version negotiation (`PKPlugInManager+Compatibility`)
- Unified logging (`PKLogger`)
- Cancellation tokens (`PKCancellationToken`)
- A comprehensive 87-code error enum (`PKError`)

What remains is the work that turns a well-architected framework into a *production-grade, secure, observable, and extensible* one. This document captures **additional** improvements not yet covered (or only stubbed) in the repository, grouped along the two axes that define the next phase: **robust** (correctness, security, observability, lifecycle) and **dynamic** (extensibility, streaming, runtime discovery, modern Swift).

Each item references the concrete file(s) it touches so the work is directly actionable.

---

## Robustness Track

### R1. Implement the security primitives the error enum already promises *(highest leverage)*

`PKError.h` defines `PKErrorSandboxViolation` (1501) and code-signing/entitlement error codes, but no code actually enforces them. Plugins are loaded by bundle URL with **zero trust verification** — any malicious bundle dropped into a watched directory will load.

**Add a `Sources/PlugInKit/Security/` subsystem:**

- `PKPlugInTrustEvaluator` — wraps `SecStaticCodeCreateWithPath` + `SecStaticCodeCheckValidityWithErrors`, evaluates a designated requirement string (Team ID anchor, certificate pinning, hardened-runtime flag).
- `PKPlugInTrustPolicy` — configurable allow-list: required Team IDs, minimum signing identity, required entitlement set, reject ad-hoc-signed plugins in release builds.
- Hook into `PKPlugInManager` discovery in `Sources/PlugInKit/Core/PKPlugInManager.m` so untrusted bundles surface as `PKErrorCodeSignatureInvalid` and never reach `PKConnection` activation.
- Audit-log every trust decision via `PKLogger` category `Security`.

This is the single biggest robustness gap in the current codebase.

### R2. Crash isolation & supervised restart policy

XPC isolates crashes, but `PKConnection` currently surfaces invalidation and stops. For a robust host, add a *supervision strategy* mirroring Erlang-style policies:

- `PKConnectionRestartPolicy` enum: `Never`, `OnCrash`, `Always`, with `maxRestarts`, `backoff` (exponential with jitter), `resetWindow`.
- Implement in `PKConnection.m` invalidation handler: schedule restart on the serial queue and replay `initializeWithConfiguration:` with the cached `PKPlugInConfiguration`.
- Emit `PKConnectionDelegate connection:didRestart:afterAttempt:` so hosts can observe flapping.

### R3. Convert remaining `NSLog` call sites to `PKLogger`

`PKPlugInManager.m` lines 232 / 235 / 241 still use `NSLog`. Sweep all `Sources/` for `NSLog(` and route through `PKLogger` so log levels, categories, and unified-logging metadata are consistent. Add a Bash one-liner to CI to fail on new `NSLog` introductions.

### R4. Add `os_signpost` performance markers

`PKLogger` covers level-based logging, but the codebase has **zero** `os_signpost` / `os_signpost_interval_begin/end`. Wrap the hot paths so Instruments' "Points of Interest" template surfaces them:

- Plugin discovery (per-bundle scan).
- XPC handshake (connect → `initializeWithConfiguration:` reply).
- Each `pollWithCompletion:` round-trip (latency is already measured — emit as a signpost metric).
- Future chain resolution in `PKFuture.m`.

Add an `OSLog` instance per subsystem in `PKLogger.h` so signpost IDs are stable.

### R5. Strict concurrency & `Sendable` audit (Swift 6 readiness)

`Package.swift` pins Swift 5.5 / macOS 10.15. Bump the tools-version, opt into `SwiftSetting.enableUpcomingFeature("StrictConcurrency")` for the Swift target, and annotate the typed `Future<T>` (`Sources/PlugInKit/Swift/PlugInKitSwift.swift` ~lines 169–270) and the `SwiftPlugInProtocol` extensions with `Sendable` / `@unchecked Sendable` as appropriate. Without this, downstream Swift 6 adopters get warnings or errors.

### R6. Bridge `PKCancellationToken` ↔ Swift `Task` cancellation

`PKCancellationToken` is currently standalone. In `Sources/PlugInKit/Swift/PKFuture+Swift.swift`, wrap `withTaskCancellationHandler` so that:

- `Task.cancel()` automatically cancels the underlying `PKFuture`.
- Token cancellation surfaces as `CancellationError` in `await`-style consumers.

### R7. Real test coverage on the critical paths

`Tests/` has 4 files covering state, compatibility, dependencies, and resource limits. The four highest-risk untested subsystems are **PKConnection, PKPlugInManager, PKXPCService, PKFuture**. Add:

- A `MockXPCService` test double (in-process, no actual `xpcproxy`) so connection lifecycle can be driven deterministically.
- `PKConnectionHealthTests` driving fake latency samples through the polling logic and asserting Healthy → Degraded → Unhealthy transitions and delegate fan-out.
- `PKFutureCompositionTests` for `then` / `flatMap` / `all` / `any` / `race` / `timeout` / `zip`, including cancellation propagation across compositions (the riskiest correctness surface).
- `PKPlugInManagerDiscoveryTests` using a tmp directory of fake `.plugin` bundles.

### R8. Replace `NSCondition` operation tracking in `PKConnection` with a queue invariant

`PKConnection` uses `NSCondition` plus a serial queue. Two synchronization primitives doubling up on the same invariant is a classic source of subtle deadlocks (especially with `synchronousRemotePlugInWithErrorHandler:`). Collapse to a single serial queue + atomic counter for in-flight ops, asserting queue identity with `dispatch_assert_queue`.

---

## Dynamic Track

### D1. `AsyncSequence` / `AsyncStream` event bus for plugins *(highest leverage)*

The framework is point-to-point and callback-based. Add a typed pub-sub layer:

- `PKEventBus` actor in `Sources/PlugInKit/Swift/`, with `publish<E: Codable & Sendable>(_:topic:)` and `subscribe<E>(_:topic:) -> AsyncStream<E>`.
- Wire through XPC so plugins can emit events without the host having pre-registered a selector.
- Bridge to ObjC consumers via a block-based subscription on `PKConnection (Events)`.

This is what makes the framework feel *dynamic*: hosts react to plugin-driven events instead of polling.

### D2. Per-method API versioning & capability semver

`PKRequiredCapabilities` today is a list of opaque strings (all-or-nothing). Extend `PKMethodMetadata` in `Sources/PlugInKitProtocol/` with:

- `availableSinceVersion` / `deprecatedSinceVersion` strings (semver).
- `capabilityVersion:` dictionary `[capability: minVersion]`.

`PKIntrospector` (`Sources/PlugInKit/Introspection/PKIntrospector.m`) filters methods the current host can call; `PKScriptingDefinitionGenerator` omits deprecated methods from generated SDEF.

### D3. Finish the ScriptingBridge — it's currently broken in subtle ways

`PKScriptingDefinitionGenerator.m` has shipped problems:

- Suite code hard-coded to `"PKIt"` (line 39).
- Four-char codes are a placeholder (line 58) — Apple Events will not dispatch correctly.
- Parameter labels are generic `"Parameter N"` (line 71) — produces unusable AppleScript.
- No ObjC type ↔ AppleScript type coercion table.

Wire the existing C++ AST parser in `Sources/PlugInKit/ScriptingBridge/` (referenced in `SCRIPTING_LEDGER.md`) to feed real parameter names and synthesize stable four-char codes from an FNV-1a hash of `bundleID + methodSelector` (clamped to the printable ASCII range).

### D4. Enrich introspection metadata

`PKIntrospector.m` (lines 124–186) extracts ObjC type-encoded strings but loses parameter names, nullability, and async-signature flags. Extend `PKMethodMetadata` with:

- `parameterNames: [String]` (from the clang AST already available to the ledger).
- `nullability: [PKNullability]` per parameter / return value.
- `isAsync: BOOL` (detect `reply:` block last-arg pattern).
- `throwsErrorViaReply: BOOL` (detect `NSError**` or `error:` in the reply block).

This unlocks better SDEF generation (D3), better Swift bridging, and richer developer-tool output.

### D5. DocC catalog

No DocC currently exists. Add `Sources/PlugInKit/PlugInKit.docc/` with a landing page, an `Articles/` set (mirroring the existing `README.md` + `FUTURES.md` sections), and tutorials for *Building your first plugin*, *Bidirectional messaging*, *Health monitoring*. Wire `swift package generate-documentation` into a CI artifact upload. This replaces markdown-only documentation with browsable, Xcode-native help.

### D6. Remote / federated plugin discovery

`PKPlugInManager` only scans local bundle directories. Add a pluggable `PKPlugInSource` protocol with implementations:

- `PKLocalBundleSource` (current behavior, refactored).
- `PKRemoteRegistrySource` — fetches a manifest (JSON) of plugin URLs + signatures + minimum-host-version, downloads to a cache directory, then hands off to the local trust evaluator from R1.

This is what enables a "plugin marketplace" without baking marketplace policy into the framework.

### D7. Privacy manifest & SPM resource

Apple now requires `PrivacyInfo.xcprivacy` for frameworks distributed through the App Store. Add one to `Sources/PlugInKit/Resources/` and declare it via `.process("Resources")` in `Package.swift`. Even if hosts ship outside the App Store, downstream adopters will need it.

### D8. CI/CD

Still missing (SUGGESTIONS.md called this out — restating because it gates everything above). Add `.github/workflows/ci.yml` running on `macos-14`:

- `swift build`
- `swift test --enable-code-coverage`
- `xcodebuild -scheme PlugInKit docbuild`
- A guard `! grep -RIn 'NSLog(' Sources/` to enforce R3.

Add a release workflow that pushes DocC output to GitHub Pages.

---

## Critical Files to Modify

| Area | Files |
|---|---|
| Trust (R1) | new `Sources/PlugInKit/Security/PKPlugInTrustEvaluator.{h,m}`, `PKPlugInTrustPolicy.{h,m}`; hook in `Sources/PlugInKit/Core/PKPlugInManager.m` discovery path |
| Supervision (R2) | `Sources/PlugInKit/Core/PKConnection.{h,m}` (new restart-policy property + invalidation-handler logic) |
| Logging hygiene (R3) | `Sources/PlugInKit/Core/PKPlugInManager.m:232,235,241`; CI grep in `.github/workflows/ci.yml` |
| Signposts (R4) | `Sources/PlugInKit/Core/PKLogger.{h,m}`; instrument `PKConnection.m`, `PKPlugInManager.m`, `PKFuture.m` |
| Concurrency (R5, R6) | `Package.swift` (Swift tools bump), `Sources/PlugInKit/Swift/PlugInKitSwift.swift`, `Sources/PlugInKit/Swift/PKFuture+Swift.swift` |
| Tests (R7) | new `Tests/PlugInKitTests/Mocks/MockXPCService.{h,m}`, `Tests/PlugInKitTests/Core/PKConnectionHealthTests.m`, `Tests/PlugInKitTests/Futures/PKFutureCompositionTests.m`, `Tests/PlugInKitTests/Core/PKPlugInManagerDiscoveryTests.m` |
| Connection sync (R8) | `Sources/PlugInKit/Core/PKConnection.m` |
| Event bus (D1) | new `Sources/PlugInKit/Swift/PKEventBus.swift`, `Sources/PlugInKit/Core/PKConnection+Events.{h,m}` |
| Versioning (D2) | `Sources/PlugInKitProtocol/PKMethodMetadata.{h,m}`, `Sources/PlugInKit/Introspection/PKIntrospector.m`, `Sources/PlugInKit/ScriptingBridge/PKScriptingDefinitionGenerator.m` |
| Scripting fix (D3) | `Sources/PlugInKit/ScriptingBridge/PKScriptingDefinitionGenerator.m:39,58,71`; integrate existing AST parser |
| Introspection (D4) | `Sources/PlugInKitProtocol/PKMethodMetadata.{h,m}`, `Sources/PlugInKit/Introspection/PKIntrospector.m:124-186` |
| DocC (D5) | new `Sources/PlugInKit/PlugInKit.docc/` |
| Remote discovery (D6) | new `Sources/PlugInKit/Core/PKPlugInSource.{h,m}`, refactor of `PKPlugInManager` discovery |
| Privacy manifest (D7) | new `Sources/PlugInKit/Resources/PrivacyInfo.xcprivacy`; `Package.swift` resource declaration |
| CI (D8) | new `.github/workflows/ci.yml`, `.github/workflows/release.yml` |

## Existing Utilities to Reuse

- `PKLogger` (`Sources/PlugInKit/Core/PKLogger.h`) — extend with per-subsystem `OSLog` instances rather than introducing a new logger.
- `PKError` / `PKErrorDomain` — promote the already-defined security codes (`PKErrorSandboxViolation`, code-signing codes) into the trust evaluator rather than minting new ones.
- `PKCancellationToken` (`Sources/PlugInKit/Futures/`) — extend, don't replace, when adding Swift `Task` bridging.
- The C++ AST parser referenced in `SCRIPTING_LEDGER.md` — wire into the SDEF generator for parameter-name extraction.
- `PKPlugInManager+Compatibility`'s semantic-version comparator — reuse for D2 method-level versioning.

## Verification

End-to-end checks to confirm each track works:

**Robustness**

- `swift test` — new `PKConnectionHealthTests`, `PKFutureCompositionTests`, and `MockXPCService`-driven discovery tests all pass.
- Sign a sample plugin with a test certificate, modify its binary post-signing, observe `PKErrorCodeSignatureInvalid` and refusal to connect (R1).
- Force a sample plugin to `abort()` inside a method call; observe `PKConnection` restart per `PKConnectionRestartPolicy.OnCrash` with exponential backoff (R2).
- `grep -RIn 'NSLog(' Sources/` returns empty (R3); Instruments → Points of Interest shows discovery/handshake/poll/future signposts (R4).
- Build the Swift target with `-strict-concurrency=complete`; expect zero warnings (R5).
- A Swift `Task { try await future.async() }` cancelled mid-flight surfaces `CancellationError` and the underlying `PKFuture` reports cancelled state (R6).

**Dynamic**

- A plugin publishes events via `PKEventBus.publish`; host receives them via `for await event in bus.subscribe(...)` (D1).
- A plugin marked `availableSinceVersion: "2.0"` is filtered out by a 1.x host's `PKIntrospector` and omitted from generated SDEF (D2).
- Generated SDEF opened in Script Editor exposes real parameter names and unique four-char codes; an AppleScript `tell` actually dispatches (D3, D4).
- `swift package generate-documentation` builds without errors; opening the `.doccarchive` in Xcode shows the landing page + tutorials (D5).
- A `PKRemoteRegistrySource` pointed at a `file://` manifest discovers, downloads, trust-evaluates, and connects to a sample plugin (D6).
- App Store validation accepts a host-app archive that embeds PlugInKit + `PrivacyInfo.xcprivacy` (D7).
- A push to a feature branch triggers `ci.yml`; the workflow runs build, tests, coverage upload, docs build, and the `NSLog` guard (D8).
