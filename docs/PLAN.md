# Stored Plan

## Product

- Premium offline expense tracker MVP
- Android and iOS
- No login
- Local Isar database

## Core Features

- Add, edit, delete expense transactions
- Parent and child categories
- Monthly expense overview
- Previous month comparison
- Transaction history
- Settings
- Debt and loan tracking with linked paybacks
- Android SMS import for bank transaction messages

## SMS Import

- Android-only and opt-in from Settings.
- Personal APK distribution is the target for this feature.
- The app listens for new incoming bank transaction SMS after permission is granted.
- Parsed SMS creates provisional transactions only.
- Provisional transactions are excluded from reports, balances, and exports until the user saves them.
- Users review provisional transactions from the Provisional Transactions screen and can save or delete each item.
- A persistent notification shows when provisional transactions are waiting.
- Use `RECEIVE_SMS` for new incoming SMS and `POST_NOTIFICATIONS` on Android 13+.
- Do not request `READ_SMS` unless a later feature imports historical inbox messages.
- Google Play distribution needs a separate Play-safe build or policy review because SMS permissions are restricted/high-risk.

## Technical Rules

- Keep implementation simple
- No Riverpod, Bloc, Redux
- Local state only
- Reload data when screen opens or returns
- Minimal packages
- Production-friendly MVP
- For personal Android install, release APKs must be ABI-split.
- Use universal APK or App Bundle only when distribution needs it.
