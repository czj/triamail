---
name: write-swift
description: How to write Swift in Triamail — where code goes (app vs TriamailKit), the project's concurrency settings (app: main actor by default, `async` stays on the caller's actor; TriamailKit: `async` functions run off the caller's actor), Sendable, SwiftUI, value types, errors, Swift Testing and logging. Use when writing, reviewing or fixing Swift in this repository, or when a concurrency error, a hang or a data race shows up.
---

# Write Swift in Triamail

Adapted for this repository from [emilkowalski/skills `write-swift`](https://github.com/emilkowalski/skills/tree/main/skills/write-swift) (MIT). Only what applies here is kept; the rules below are bound to this project's build settings.

The through-line: start with the simplest, most static, most single-threaded thing that works. Add concurrency, reference types, existentials or unsafe code only for a reason you can name.

## 0. The project's settings — read before writing concurrent code

| Where | Settings | Effect |
| --- | --- | --- |
| App (`App/Sources`, `project.yml`) | `SWIFT_APPROACHABLE_CONCURRENCY: YES`, `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor` | Every declaration is `@MainActor` unless marked `nonisolated`; an `async` function stays on its caller's actor. |
| Library (`Packages/TriamailKit`, `Package.swift`) | Swift 6 language mode, **no** approachable concurrency, on purpose | Types and functions are `nonisolated`; a `nonisolated async` function runs **off** its caller's actor, on the concurrent pool. |

The two halves follow different rules. That is deliberate:

- **App: main actor, synchronous by default.** Don't write `@MainActor`: it is already there. An `async` function or method stays on the main actor; it only frees it while it waits. A `nonisolated async` function in the app also runs on its caller's actor. To leave the main actor from app code, mark the function `@concurrent`, but heavy work belongs in the library anyway.
- **Library: every `async` entry point leaves the caller's actor by itself.** Network, JSON and MIME decoding, base64, keychain calls: `await`ing them from the app never blocks the main actor, without any annotation. Never put `@MainActor` on library API, don't add `@concurrent` (it is the default here), and don't turn on `NonisolatedNonsendingByDefault` or approachable concurrency in `Package.swift`: every library call would then run on the main actor.
- **A synchronous library function runs where it is called.** CPU work called from the app (`PDFText.extract`, `LanguageDetector`…) runs on the main actor unless it is wrapped in a library `async` function.
- Task group children (`group.addTask`) run on the concurrent pool: the bounded fan-out in `GmailAPI.inbox` stays parallel.
- Closures passed from the app to a library `@Sendable` callback do not run on the main actor: hop back with `await MainActor.run { … }` (`AppModel` sign-in), or `MainActor.assumeIsolated` in callbacks that AppKit guarantees on the main thread.

Order of escalation, without skipping a step: synchronous on the main actor → `async` library call for I/O and heavy work → an `actor` for state that must live off the main actor (`AccessTokenCache`).

## 1. Where code goes

- **Logic goes in `Packages/TriamailKit`, with Swift Testing tests.** The app keeps only the UI and the glue with system frameworks (SwiftUI, WebKit, EventKit, Translation, Sparkle).
- Library types are `public` only when the app uses them. A public type gets no inferred `Sendable`: write `Sendable` on it when it crosses actors (models, clients). Non-public value types get it for free.
- Nothing personal hard-coded (AGENTS.md, rule 1): values come from `SettingsStore` (iCloud Drive) or `Keychain`; tests use `exemple.com`, `Jeanne Exemple`.
- User-facing strings are in French; identifiers, comments and doc comments in English.

## 2. Model data with value types

- `struct` and `enum` by default. `class` only for identity, shared mutable state, or a resource's lifetime (a model observed by views, a delegate, a server socket).
- `let` by default; `var` only when you mutate.
- An `enum` for mutually exclusive state, with associated values, rather than several optionals and booleans that can disagree (`TranslationModel`'s `.translating` / `.done(text)` / `.failed(message)`).
- A struct holding a mutable class is neither a value nor a reference: keep that class immutable or private.

## 3. Errors and optionals

- Recoverable (network, Gmail, files) → `throw`. Programmer mistake → `precondition`/`fatalError` with a message.
- Error enums carry their context: `case http(Int, String?)` beats `case http`.
- `guard` for error exits, `if let` for the ordinary unwrap.
- Untyped `throws` on public API. Force-unwrap only where you can state the invariant (a URL built from constants), never on input from the network or the user.
- Show errors to the user in French; keep `CancellationError` silent (a refresh replaced the task).

## 4. Sendable and data races

- `@MainActor` classes and actors are `Sendable` already. An app model (`@Observable`, main actor by default) is not shared with the background: pass it values, not itself.
- When a data race error appears, in order:
  1. Don't share it: copy what the other side needs into a local or the capture list.
  2. Make it a `Sendable` value type.
  3. Isolate it on an actor (the main one, or your own).
  4. Only then `Mutex` (`Synchronization`) or a `DispatchQueue` guarding all state, with `@unchecked Sendable` and a comment saying what protects it (`LoopbackReceiver`).
- `@Sendable` on a closure type only when it really crosses actors (`Document.text`, a token refresh).
- `nonisolated(unsafe)` and `@preconcurrency` are last resorts, never a warning silencer.
- Delegates of system APIs (`WKNavigationDelegate`…): the class stays on the main actor; mark a callback `nonisolated` only if the framework calls it from another thread, then hop back with `MainActor.assumeIsolated` or a `Task`.

## 5. Structured concurrency

- `async let` for a fixed number of parallel jobs; `withThrowingTaskGroup` for a dynamic one, **bounded** (`GmailAPI.parallelFetches`: Gmail answers 429 to bursts).
- `Task { }` only where a lifetime doesn't fit a scope: a button tap, a menu command. It inherits the main actor. In views, prefer `.task` / `.task(id:)`, cancelled with the view.
- `Task.detached` and `DispatchQueue.global()`: no. Heavy work goes in a TriamailKit `async` function.
- Cancellation is cooperative: `try Task.checkCancellation()` before expensive work.
- Bridging a callback: `withCheckedThrowingContinuation`, resumed **exactly once** on every path (timeouts included).
- After an `await`, state may have changed: re-check it. An actor is reentrant: mutate its state in synchronous methods, and re-check a cache after the `await` that filled it.
- No user-visible action without a click (AGENTS.md): no background task that acts.

## 6. SwiftUI

- Views and their `@State` are on the main actor. Models are `@Observable` (never `ObservableObject`/`@Published`).
- Some SwiftUI closures are `@Sendable` and may run off the main actor (`onGeometryChange`, `visualEffect`, `Layout`, `Shape.path`): don't capture `self`, copy the value you need into the capture list, and make constants they read `nonisolated` (`MainWindowLayout`).
- Action callbacks stay synchronous: change state (and animate) at once, then open a `Task` for the slow part.
- The view starts the work; the model does it and changes its state in one synchronous step at the end; the view reacts.

## 7. Protocols, generics, API

- Concrete types first. A protocol only when two types share a capability, or to swap an implementation in tests (`MailSource`).
- `some P` by default, `any P` only to store mixed types.
- A protocol requirement is a customization point; a method only in an extension is static and gets shadowed, not overridden.
- No type prefixes, no leading `get`. Names read clearly at the call site.
- `private` by default inside a file; `internal` in the module; `public` only at the TriamailKit boundary.

## 8. Performance

- Algorithm first: `removeAll(where:)`, not `remove(at:)` in a loop; no per-byte slicing of `Data`.
- Measure before optimizing: Instruments (Time Profiler, Hangs) on the app or on a test.
- Batch main actor hops: send arrays, not one element per `await`.
- `final` on classes not meant to be subclassed.

## 9. ARC

- `weak`/`unowned` only to break a cycle; better, don't build the cycle.
- Never depend on when `deinit` runs. Keep side effects out of it.

## 10. Testing — Swift Testing

- `@Test` + `#expect`; `try #require` to unwrap or stop; suites are `struct`s with setup in `init`.
- `@Test(arguments:)` instead of a loop or copies.
- Tests run in parallel and in random order: no shared state, no network, no real data. Test the request a client builds and the decoding of a sample answer separately (`AITests`), or use a `MailSource` double.
- `withKnownIssue` rather than commenting out; `.disabled("reason")` if needed.
- Run: `swift test --package-path Packages/TriamailKit`.

## 11. Logging

- When logging is added: `Logger` (`os`), not `print`. Interpolations stay redacted by default: never `privacy: .public` on an address, a subject or a mail body.

## 12. Modern syntax

| Instead of | Write |
| --- | --- |
| Nested ternaries, an immediately called closure for a `let` | `if` / `switch` expressions |
| `ObservableObject` + `@Published` | `@Observable` |
| Polling an object for changes | `Observations { … }` |
| String index arithmetic | Swift Regex (with Foundation parsers for dates and numbers, explicit locale) |
| `Process` + pipes | the Subprocess package, if it is added as a dependency |
| `DispatchQueue.global().async` | a TriamailKit `async` function (`@concurrent` in app code) |
| `DispatchSemaphore` across an `await` | nothing: restructure |

The project builds in the Swift 6 language mode with the Swift 6.2+ compiler. Before using a feature from a newer release, check the CI toolchain (`runs-on` in `.github/workflows/ci.yml`).

## Quick reference

| Need | Reach for | Not |
| --- | --- | --- |
| A data type | `struct` / `enum` | a `class` without identity |
| Logic to test | TriamailKit + `@Test` | code in a view |
| App code | nothing (main actor by default) | `@MainActor` everywhere |
| Library API | `nonisolated` (default) | `@MainActor` |
| Heavy work called from the UI | a TriamailKit `async` function | `Task.detached`, `DispatchQueue.global()` |
| State off the main actor | `actor` | a `class` + a lock |
| N parallel requests | bounded task group | one task per element |
| Work started by a click | `Task { }` in the action | an `async` callback |
| A data race | stop sharing | `@unchecked Sendable` |
| Constants read in a `@Sendable` closure | `nonisolated` type | capturing `self` |
| Diagnostics | `Logger` | `print` |
