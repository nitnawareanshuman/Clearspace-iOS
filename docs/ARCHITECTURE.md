# Architecture

ClearspaceApp owns two main-actor observable stores. CleanerStore coordinates Photos access, storage snapshots, progress and immutable review drafts; ContactsStore handles independent Contacts access, scans, generations and review. Changes to either library invalidate its drafts. App backgrounding cancels active scans.

LibraryScanner is an actor. Existing normalized-preview hashes, difference hashes and Vision feature prints remain. Favorites, resolution and recency determine recommended keeps. Bounded anchors avoid unbounded feature-print memory. Media resource measurement streams serially without retaining payloads or enabling downloads. Videos are measured after photo candidates, then sorted by descending known bytes. RequestGate resumes image/player/resource continuations once and handles timeout/cancellation.

ContactService is an actor using CNContactStore. It enumerates individual records with unifyResults=false to avoid presenting a linked unified person as one source card. ContactPolicy indexes normalized full names, phone digits and trimmed case-insensitive emails with disjoint sets. Overlapping candidates form one group; country codes are not guessed. Shared details are only suggestions and nothing is automatically selected.

Contact drafts include deleted and kept records in affected groups. Selection must be known, nonempty and leave one record per group. The service re-fetches affected identifiers and compares contact snapshots before one CNSaveRequest. Notifications invalidate drafts; errors force a rescan. Notes are not fetched because Apple requires a separate entitlement. Final review explicitly warns that deletion removes other fields, does not merge details, may sync to accounts and has no app-level undo.

Media drafts carry an epoch and are checked for known IDs, keep-one rules, modification dates and delete capability immediately before PhotoKit mutation. The final review is the only entry to the mutation.

Views live in Features; shared components and the SwiftUI mascot live in DesignSystem. Resources has assets/plists. The Python project generator produces nested PBXGroups matching physical folders, with source-root file references and target memberships. No content is uploaded or persisted in an app database.
