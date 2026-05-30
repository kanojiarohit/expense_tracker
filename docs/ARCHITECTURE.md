# Architecture Overview

## Principles

- Flutter + Isar only
- Offline-first
- Local database is source of truth
- No global reactive state manager
- Reload screen data on open and on navigation return
- Keep widgets and services simple

## App Flow

1. `main.dart` boots `ExpenseTrackerBootstrap`
2. `IsarService` initializes collections and seeds default data
3. `AppShell` holds bottom navigation and opens forms/screens with `Navigator`
4. Feature screens load data from services in `initState`
5. After add/edit/delete, screens pop with `true`
6. Parent shell or screen reloads local data

## Layers

- `models/`: Isar collections
- `database/`: Isar initialization
- `services/`: CRUD and dashboard calculations
- `screens/`: feature screens
- `widgets/`: reusable UI
- `core/`: constants, formatters, validators
- `theme/`: colors and ThemeData
