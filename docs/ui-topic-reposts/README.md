# Topic input and home reposts — 2026-09-16

- Topic score entry opens at the large detent. Its fields scroll independently of the four-row keypad. Focusing the comment replaces the keypad with a Done action.
- Removed the emoji/score preset row from this sheet.
- Home cards offer repost/cancel with a count and selected state. Writes disable repeat taps; errors preserve the prior state and display an alert.
- My Page has a Reposts tab ordered by repost time, with pagination and the original card's comments, likes and reporting actions.
- Reposts reference original posts; moderation and blocking still apply. Account deletion cascades repost rows.

## Deployment

Apply `supabase/migrations/20260916000003_post_reposts.sql` before releasing the updated app. This task tested the migration in an isolated local PostgreSQL database; it did not apply it to production. Existing home-feed reads remain compatible with the older schema.

## Validation

- iOS simulator build succeeded.
- All 14 feed decoding and repost service/view-model unit tests passed.
- Both UI tests passed: My Page Reposts tab and topic keypad. Keypad checks: all digits visible and tappable, score input, presets absent, comment keyboard transitions.
- Local PostgreSQL assertions: idempotency, account isolation, cancellation, blocked/hidden original filtering, cancellation after moderation.
- Localization catalog validation passed.

`topic-keypad.png` is the simulator screenshot from the passing UI test.
