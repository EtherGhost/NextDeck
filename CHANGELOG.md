# Changelog

## 0.3.0 - 2026-07-13

Feature and reliability release.

- Updated `vendor/NextCommon` from a very old pin to `v0.3.4`, picking up the
  Lomiri.OnlineAccounts 2.0 migration (avoids a native crash risk when an
  account is not yet approved or has its approval revoked mid-session),
  the account list's server-URL subtitle fix, and other suite-wide fixes.
  The submodule's local git remote had also drifted to a now-nonexistent
  local path; fixed so it correctly tracks the GitHub repository again.
- Closed a large pre-existing translation backlog: most non-English,
  non-Swedish languages were only about 15% translated (as little as 65 of
  403 strings), and even Swedish was missing over 100 strings. All 13
  languages are now fully translated.
- `DeckNetwork.cpp` had no request timeout and did not follow HTTP
  redirects. Added a 30s timeout for API calls (120s for attachment
  upload/download, which can legitimately take longer) and redirect
  following for same-origin redirects, matching the pattern used in
  NextTasks/NextNotes. Per-request network isolation across accounts was
  already correct and did not need changes.
- Updated `qml/UTControls/CalendarDatePicker.qml`, `TimePicker.qml`, and
  `TreeReorderableListView.qml` to the current shared UTControls content,
  fixing several strings (OK/Now/Clear/Cancel, Hour/Min, month/weekday
  names, the drag-to-indent badge) that were never translatable.
- Fixed two contract tests left over from switching to the shared
  NextCommon submodule that still checked internal details of an older,
  already-replaced Online Accounts API.
- Dropped "but simple" from the tagline.

## 0.2.0 - 2026-07-01

Feature and polish release.

- Improved board navigation with card counts, archive overview, and clearer board actions.
- Improved card list bulk actions, move behavior, archive/restore flow, and list-menu handling.
- Fixed due date/time handling so saved card times respect the local timezone.
- Updated the shared Ubuntu Touch controls, including an adaptive calendar action layout for small screens.
- Improved release readiness after mobile testing. Bugs and rough edges are still expected.

## 0.1.0 - 2026-06-29

First public release of NextDeck for Ubuntu Touch.

- Early support for using Nextcloud Deck with Ubuntu Touch Online Accounts.
- Includes board, list, card, comment, label, assignment, attachment, and activity views.
- This is an early version. Bugs and rough edges are expected.

## 0.0.1 - 2026-06-14

- Initial Ubuntu Touch scaffold for NextDeck.
- Added Clickable/CMake project structure.
- Added QML placeholder UI and C++ launcher.
- Added minimal AppArmor/accounts/networking setup.
- Added themed icon and OpenStore banner draft.
- Added gettext translation structure.
