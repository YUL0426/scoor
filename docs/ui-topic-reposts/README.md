# Topic input and home reposts — 2026-09-16

- Topic score entry opens at the large detent. Its fields scroll independently of the four-row keypad. Focusing the comment replaces the keypad with a Done action.
- Removed the emoji/score preset row from this sheet.
- Home cards offer repost/cancel with a count and selected state. Writes disable repeat taps; errors preserve the prior state and display an alert.
- My Page has a Reposts tab ordered by repost time, with pagination and the original card's comments, likes and reporting actions.
- Reposts reference original posts; moderation and blocking still apply. Account deletion cascades repost rows.

## Deployment

Applied `supabase/migrations/20260916000003_post_reposts.sql` to the linked production project on 2026-09-16 after explicit user approval. The table, RLS policies, feed columns and migration history were committed together, then the PostgREST schema cache was refreshed.

Before rollout, the app's repost list request returned HTTP 400 (`42703`: missing `feed_posts.reposted_by_me`), and `post_reposts` returned HTTP 404 (`PGRST205`). After rollout, the same repost-list request, repost-table read, and ordinary home-feed read all returned HTTP 200. Production schema checks confirmed the table, all three feed columns and migration history exist.

Production database validation exercised authenticated-role save, duplicate save, per-user list metadata, cancel, cross-account protection, blocked/hidden original filtering and cancellation after moderation. It used fresh synthetic IDs in a transaction ending in ROLLBACK, leaving no test records. No app rebuild is required for this server fix.

## Validation

- iOS simulator build succeeded.
- All 14 feed decoding and repost service/view-model unit tests passed.
- Both UI tests passed: My Page Reposts tab and topic keypad. Keypad checks: all digits visible and tappable, score input, presets absent, comment keyboard transitions.
- Local PostgreSQL assertions: idempotency, account isolation, cancellation, blocked/hidden original filtering, cancellation after moderation.
- Localization catalog validation passed.

`topic-keypad.png` is the simulator screenshot from the passing UI test.
