# Account entry — 2026-09-16.1

- Entry: greeting → bundled rotating examples and Apple/Google sign-in → main app. Email remains available for existing email accounts. Nickname, avatar, tour and first-score entry no longer block signup.
- The visible entry notice links the complete terms and privacy notice and explains that continuing accepts the terms and confirms signup eligibility. Document reads, app launch and provider cancellation create no receipt.
- Authentication must succeed before `accept_account_terms` runs. The pending request is bound to one account and reuses its request ID on retry. Failed receipt storage does not permit migration/sync or posting, and can be retried without another provider login.
- New receipts contain only `terms` and `age`, with the actual entry action. No `privacy_notice`, `account_data` or sensitive-data acceptance is fabricated. Essential account processing is described separately as contract performance. Historical receipts are retained unchanged.
- Sensitive topic submission calls `needs_sensitive_consent` with only the topic ID before sending a score/comment. If consent is absent, the separate optional notice appears; server triggers remain in force. Notifications and other system permissions remain at feature use.
- Account settings distinguish stopping account services from withdrawing optional sensitive-data consent. Account deletion and management remain available.

## Rollout

`supabase/migrations/20260916000001_account_entry.sql` was applied to production on 2026-09-16 after explicit user approval. It adds new RPCs and preserves the existing 2026-09-15 signup RPC and receipt compatibility. Do not replace historical migration hashes. The website's terms/privacy routes already import the bundled policy JSON; publish those routes together with the new app's notice.

The shared bundle SHA-256 is `67b17e8f2ed8aabe0fd7b9b44b3b28656879305b3173deb2993a72a35cd6ee11`. Separate sensitive-topic consent retains its own unchanged `2026-09-15.1` version. No production data or legacy consent receipts should be rewritten.

Provider authentication (Apple system confirmation / Google account selection) still belongs to the provider; the app adds no extra signup form after it succeeds.

## Verification and deployment status

- Debug and Release iOS builds passed; the Release bundle retains the configured Google/Supabase settings and verified policy digest. 22 unit tests (account-entry/authentication) and all 7 updated UI tests passed. Provider UI tests use deterministic mock authentication; Apple/Google system authentication itself was not completed with a real account.
- Three isolated PostgreSQL suites passed: legacy legal consent, release safety, and new account entry. The new suite verifies ordinary writes, separate sensitive consent, withdrawal, replay protection, receipt isolation, and anonymous denial.
- The website's legal routes type-check, and KO/EN published-source documents match the app bundle and server digest.
- Production migration `20260916000001_account_entry` was applied after the user explicitly approved deployment. No historical consent receipts were changed. Another pre-existing unapplied migration (`20260915000007`) was excluded. The installed CLI’s `db push` failed to read its profile, so the same tested migration and its schema-migration history row were applied together in one transaction through the official `supabase db query --linked --file` command.

Production read-only verification passed all 11 checks: migration history, action column, both new RPCs, authenticated access, anonymous denial, current/previous terms support, bundle digest and sensitive-write trigger.
