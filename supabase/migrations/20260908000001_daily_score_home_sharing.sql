-- One active home post per user and journal day. A user can unshare and later
-- share again because soft-deleted rows are outside this partial index.
create unique index if not exists posts_author_source_day_active_idx
  on public.posts (author_id, source_day)
  where source_day is not null and deleted_at is null and not is_official;

comment on index public.posts_author_source_day_active_idx is
  'Prevents duplicate active feed posts when a daily score share is retried.';
