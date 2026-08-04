-- Songs of the Church Plus: who is entitled, and until when.
--
-- RevenueCat is the source of truth for whether a subscription is live. This
-- table is a local mirror of that, written only by the RevenueCat webhook and
-- read only by the account it belongs to. Mirroring rather than calling
-- RevenueCat on every launch keeps the app's startup path off a third party,
-- and means an entitlement check is one indexed row read.

create table if not exists public.entitlements (
  -- The Supabase user id doubles as the RevenueCat App User ID, which is what
  -- makes one purchase work on every platform: whichever device signs in,
  -- RevenueCat is asked about the same subject.
  user_id      uuid primary key references auth.users (id) on delete cascade,

  product_id   text        not null,
  active       boolean     not null default false,

  -- Null means an entitlement with no scheduled end. The app treats null as
  -- "does not lapse", so only write it that way deliberately.
  expires_at   timestamptz,

  -- Which store or processor the purchase came from. Constrained because a
  -- typo here would silently send someone to the wrong place to cancel.
  source       text        not null default 'stripe'
                 check (source in ('stripe', 'app_store', 'play_store', 'promotional')),

  -- Kept for support: matching a customer's email to a RevenueCat record is
  -- otherwise guesswork.
  rc_customer_id text,

  updated_at   timestamptz not null default now()
);

comment on table public.entitlements is
  'Mirror of RevenueCat entitlement state. Written only by the service role via
   the revenuecat-webhook function; never written by clients.';

alter table public.entitlements enable row level security;

-- Read your own row, and nothing else. There is deliberately no insert, update
-- or delete policy for authenticated users: an entitlement a client could
-- write is an entitlement anyone can grant themselves. The webhook uses the
-- service role, which bypasses RLS.
drop policy if exists "read own entitlement" on public.entitlements;
create policy "read own entitlement"
  on public.entitlements
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- Revoke the default grants so the only path in is the policy above.
revoke all on public.entitlements from anon, authenticated;
grant select on public.entitlements to authenticated;

create index if not exists entitlements_active_idx
  on public.entitlements (active, expires_at);
