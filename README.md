# Rippple

Enter the Trakt community — **discover**, **track** and **share** movies and TV shows.

Rippple is a native client for [Trakt](https://app.trakt.tv) that runs on iPhone, iPad and Mac. You need to sign in with a Trakt account to use Rippple.
 
- **Learn more:** [Rippple 101](/docs/RIPPPLE_101.md) — what Rippple is and how it works. 
- **Questions?** [Get help](/docs/GET_HELP.md) — FAQ and contact.

## Features

**Discover** what’s trending, popular and where to watch it. **Track** what you watch and when. **Share** comments, ratings and more.

- **Browse** — Trending, popular and anticipated movies and TV shows. Browse comments about what you watched or are about to watch.
- **Check-in** — Built-in Trakt check-in for episodes and movies. See what you’re currently watching.
- **Get information** — Learn more about movies and TV shows and the people who made them (cast & crew).
- **Find where to watch** — See where you can stream, buy or rent (via JustWatch through TMDb).
- **Look back** — Full watch history with filters (movies, episodes or both) and when you watched each item.
- **Manage your watch history** — Mark episodes and movies as watched (now or by date). Multiple-watch support. **Pulse** gives you a timeline of your interactions.
- **Share** — Post comments and reviews (quick shout or long review). Markdown editor with spoiler tags (spoiler-free or in-line).
- **Interact** — React, reply and share comments. Follow Trakt users and read what they post.
- **Rate** — View rating distributions and rate movies, episodes, seasons and TV shows.
- **Everywhere** — One app on iPhone, iPad and Mac. Everything stays in sync with your Trakt account.
- **The way you like it** — Custom colours, app icons and other options. Widgets for the movies and TV shows you watch and love.

With **Trakt VIP** you get:
- Expanded Limits
- Advanced Stats
- Your very own To Watch
- Your tailored Shelf
- Smarter Searches
- Smarter Rewatching
- Support Trakt & Rippple

## Requirements

- iOS/iPadOS/macOS 26+
- Xcode 26+
- a [Trakt](https://app.trakt.tv) account

## Building

1. Clone the repository:
   ```bash
   git clone https://github.com/trakt/trakt-rippple.git
   cd trakt-rippple
   ```

2. Open the project in Xcode. App dependencies are resolved through Swift Package Manager:
   ```bash
   open Rippple.xcodeproj
   ```

3. **Secrets** — Copy `Rippple/Secrets-Template.swift` to `Rippple/Secrets.swift` and fill in the required values (see [Secrets setup](#secrets-setup) below). `Secrets.swift` is gitignored.

4. Configure signing in Xcode (select your team under Signing & Capabilities).

5. Build and run on a simulator or device (⌘R).

### Secrets setup

`Secrets-Template.swift` defines the API keys and configuration the app needs. After copying it to `Secrets.swift`, replace the placeholders:

| Section | What to provide |
|--------|------------------|
| **Trakt** | `clientId` and `secretId` from your [Trakt API application](https://app.trakt.tv/settings/apps/api). Required for Trakt login and sync. |
| **TMDb** | `apiKey` from [The Movie Database](https://www.themoviedb.org/settings/api). Used for fetching images and “where to watch” data. |
| **Remote notifications** | Optional maintainer infrastructure. Public forks can leave `RemoteNotificationsConfiguration.remoteNotificationsBaseURL`, `remoteNotificationsAPIKey`, and all `AWSConfiguration` values as `nil`; remote push is disabled while local notifications still work. |

Maintainer builds use a small REST API proxy for endpoint registration, push information, and topic subscription updates. Remote push backend details are intentionally not required for local development, and the app no longer depends on the AWS SDK.

The build includes a run script that fails if `Secrets.swift` is missing or still contains template placeholders.

## Project structure

- **Managers & architecture** — The app uses many `*Manager` singletons (e.g. Session, User, Follow, Watched, Progress, Calendar, Filter, Shelf, Notes, Purchase) to handle specific responsibilities. It is an older UIKit-first codebase that relies on storyboards and `.xib` files; SwiftUI is used gradually for new, mostly standalone or configuration views.

- **`Rippple/`** — Main app target (Swift, UIKit, SwiftUI)
  - **`Controllers/`** — View controllers (Settings, Browse, To Watch, Friends, Purchase, Deeplink, Search, Calendar, etc.)
  - **`Trakt API/`** — Trakt API client, models, and provider extensions (list/library items)
  - **`Tmdb API/`** — TMDb API client and models (images, where to watch)
  - **`Cells/`** — Table and collection view cells (Browse, Details, Media, Settings, Ratings, To Watch, etc.)
  - **`Model/`** — Shared domain models (e.g. `Media`, comment models)
  - **`Notifications/`** — Local (episode, movie, anticipated, DVD) and remote (trending, recommended, manual) notification logic
  - **`Deeplinks/`** — Deeplink parsing and handling
  - **`Widget/`** — Home and Lock screen widget code
  - **`Shortcut/`** — App shortcuts (Search, Icon Configuration)
  
- **`NotificationService/`** — Notification Service Extension to enrich notifications

- **Dependencies** — Swift Package Manager through the Xcode project. See [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md) for more info about dependencies.

- **Key libraries:** The app relies heavily on [Receiver](https://github.com/kevincador/Receiver) for observability (Observer pattern—broadcast/listen). All API networking is built on [Moya](https://github.com/Moya/Moya) (network abstraction layer on top of Alamofire).

## Contributing

Contributions are welcome. Please read [CONTRIBUTING](CONTRIBUTING.md) and our [Code of Conduct](.github/CODE_OF_CONDUCT.md) first.

## License

This project is licensed under the GNU General Public License v3.0 — see the [LICENSE](LICENSE) file for details.

## Disclaimer

Rippple is affiliated with [Trakt](https://app.trakt.tv). Rippple uses the TMDb APIs for "Where to watch" information and images but is not endorsed or certified by TMDb. The source of "Where to watch" information is provided by JustWatch via the TMDb API. Rippple cannot be used to stream or play movies or TV shows. Some features may be limited by the APIs. [Terms of Use](TERMS.md) · [Privacy Policy](PRIVACY.md)
