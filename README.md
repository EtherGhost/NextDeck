# NextDeck

Native but simple Ubuntu Touch client for Nextcloud Deck.

This project follows the same Ubuntu Touch development approach as NextNotes, NextNews, NextTasks, and the rest of the Nextcloud app suite.

NextDeck is not affiliated with, endorsed by, or sponsored by Nextcloud GmbH or the Nextcloud project.

## Current Status

NextDeck 0.1.0 is the first public release candidate. The shared Ubuntu Touch application shell is in place: hamburger/search/sync-status/avatar top bar, released-suite-style hamburger navigation, settings, language selection, about page, Online Accounts/AppArmor declarations, icons, translation scaffold, desktop dark debug support, and desktop test-account support. Account UI and runtime account-session handling use NextCommon shared source components. The account page discovers Ubuntu Touch Nextcloud/ownCloud accounts, guides the user to allow NextDeck in OS account settings when needed, keeps the selected account while the user grants OS permission, verifies automatically after the user returns, serializes verification while running, clears stale in-memory credentials when switching accounts, isolates Deck HTTP requests so same-host accounts do not reuse stale server sessions, ignores delayed auth/Deck API responses from the previous account, and keeps technical diagnostics out of the normal UI.

Deck boards, stacks, cards, and card detail pages are implemented. Cards can be created, edited, deleted, reordered, cached locally, and queued for upload when server access fails. Board and list create/update/delete actions are implemented as server-backed actions. The card page includes support for labels, assignments, comments, attachments, and an activity log. Attachments can be uploaded, opened through Content Hub, and removed from a card. The top-bar sync icon shows loading/success/error/conflict state and opens a compact status dialog.

Card reordering uses `NextCommon.ReorderableListView` with live placeholder movement, drag overlay, auto-scroll, and pull-to-refresh support. NextDeck owns the card-order persistence, cache update, and Deck API reorder call.

Known limitations: the offline-first queue currently covers cards, not board/list management or attachment operations. Conflict handling marks cards as conflicted but does not provide a full merge UI yet. Attachment opening depends on installed Ubuntu Touch apps that can receive the downloaded document through Content Hub.

Translations are available for Swedish plus AI-assisted starter catalogs for Danish, German, Spanish, Finnish, French, Italian, Norwegian Bokmal, Dutch, Polish, Russian, and Ukrainian. Starter translations are intended to be improved by native speakers.

## Authentication

NextDeck will always use Ubuntu Touch Online Accounts only. Users should add a Nextcloud or ownCloud account in Ubuntu Touch System Settings > Accounts. If the selected account has not allowed NextDeck yet, the app opens a guided prompt to the OS account settings, keeps the account selected, and verifies access automatically when the user returns. Credentials are kept only in memory.

## Build

```bash
~/.local/bin/clickable build --arch amd64
~/.local/bin/clickable build --arch arm64
```

## Run

```bash
~/.local/bin/clickable desktop --arch amd64
~/.local/bin/clickable script desktop-dark
scripts/desktop-test.sh
```

`scripts/desktop-test.sh` reads `.env.test.local` if present, otherwise the existing sibling NextNews/NextNotes test env files. It maps the test account into `NEXTDECK_*` variables at runtime and does not commit credentials.

## Test

```bash
~/.local/bin/clickable script test
```

## License

MIT License

Copyright (c) 2026 Etherghost
