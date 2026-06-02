# Design Guide for AI Agents

Keep one consistent design language across the app.

## Rules

- Do not create a new visual treatment for an element that already has a pattern.
- Use `SectionHeader` for in-page titles on bottom-nav screens.
- Avoid duplicate page titles inside pushed screens that already have an `AppBar`.
- Use fixed headers for primary list screens: title/search/tabs stay above the scrolling content, and only the content area scrolls.
- Use `TabBar` + `TabBarView` for top-level switching such as transactions, categories, and debt/loan.
- Do not use segmented controls for main top-level layouts.
- Prevent scroll color flicker on pushed screens with `AppBar` by keeping `scrolledUnderElevation: 0`, stable `backgroundColor`, and transparent `surfaceTintColor`.
- Use `AppCard(borderRadius: 8, margin: EdgeInsets.only(bottom: 12))` for repeated list groups/cards.
- Do not nest cards inside cards.
- Use rows, dividers, and columns inside a single card.
- Use compact list rows: circular icon on the left, primary text, optional value/action on the right.
- Keep list row padding close to `vertical: 8`.
- For category lists, show parent and child categories in one parent card.
- Child category rows are indented under the parent.
- Show only category icon and name unless extra data is required.
- Use the same category picker screen wherever a category or parent category is selected.
- Parent picker mode should show only parent categories plus `No parent`.
- Use modal bottom sheets for settings choices instead of dropdowns.
- Give each settings sheet a direct title like `Choose Currency`.
- Apply settings immediately on selection.
- Show user-facing setting values as examples when possible, such as formatted amount samples instead of abstract labels.
- Use `AppTextField`, `AppButton`, `AppCard`, and existing theme colors before adding new widgets or custom styling.
- Keep card radius, spacing, icons, typography, and action placement consistent with existing transaction/category/debt-list rows.
