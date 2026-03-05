# Contributing to Rippple

Thank you for your interest in contributing to Rippple. This document explains how to get set up and how to submit changes.

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](.github/CODE_OF_CONDUCT.md).

## How to Contribute

### Reporting Bugs

Use the [Bug report](.github/ISSUE_TEMPLATE/bug_report.md) template when opening an issue. Include:

- Steps to reproduce
- Expected vs actual behavior
- iOS version and device/simulator
- Any relevant logs or screenshots

### Suggesting Features

Use the [Feature request](.github/ISSUE_TEMPLATE/feature_request.md) template for new ideas. Describe the use case and, if possible, a proposed solution.

**Not sure if it’s a good fit?** If you’re unsure whether a feature fits the project or would like to discuss it before opening an issue, start a [Discussion](https://github.com/trakt/trakt-rippple/discussions) on GitHub instead. That keeps the issue tracker for concrete proposals and bugs.

### Pull Requests

1. **Fork** the repository and create a branch from `main` (or the current default branch).
2. **Make your changes** — keep commits focused and messages clear.
3. **Test** your changes on at least one simulator and, if possible, a device.
4. **Open a pull request** using the [pull request template](.github/PULL_REQUEST_TEMPLATE.md). Link any related issues.
5. **Address review feedback** promptly.

**Commit messages**: The maintainer loosely follows [gitmoji](https://gitmoji.dev) for commit messages. You’re welcome (but not required) to do the same.

## Development Setup

- **Xcode**: Use the latest stable Xcode that supports the project’s minimum iOS version.
- **Swift**: Follow the project’s existing style.
- **SwiftLint**: The project uses [SwiftLint](https://github.com/realm/SwiftLint), which runs as an Xcode build phase. You normally don’t need to run it manually, but builds must pass without new SwiftLint violations. Rules are in [`.swiftlint.yml`](.swiftlint.yml).
- **Dependencies**: Do not add new dependencies without discussion, and keep the dependency set minimal.
- **Tests**: The project has no tests. The approach is to keep the code simple and easy to understand and maintain. It should remain that way.

## Code Style

- **Swift APIs and idioms**: Prefer Swift’s standard APIs and idioms. Use meaningful names and keep functions and types reasonably sized.
- **Comments**: Add or update comments for non-obvious behavior and public APIs.
- **Warnings as errors**: The project treats warnings as errors. Your changes must build without introducing new warnings. If you think a warning is unavoidable, call it out in your pull request so it can be discussed.
- **UIKit vs SwiftUI**: UIKit remains the default choice for new UI. Prefer UIKit when integrating with existing flows and storyboards. Use SwiftUI when it clearly makes sense (for example, new standalone or configuration views) and does not add unnecessary complexity.

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (GPLv3). See [LICENSE](LICENSE) for details.
