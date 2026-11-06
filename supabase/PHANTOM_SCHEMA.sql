-- add a match with odds (1.00 - 2.00; the database rejects other values)
insert into public.matches (home_team, away_team, league, match_date, match_time, status, lock_time, odds)
values ('Team A', 'Team B', 'League', current_date + 1, '20:00', 'upcoming',
        ((current_date + 1 + time '20:00') at time zone 'Asia/Baghdad'), 1.40);
-- change odds
update public.matches set odds = 1.35 where id = 1;
-- finish a match (points, totals and ranks update automatically)
update public.matches set status = 'finished', home_score = 2, away_score = 1 where id = 1;
-- generate 12-digit top-up codes: 50 codes worth 10000 each
select * from public.generate_topup_codes(10000, 50);
-- inspect codes
select code, amount, status, used_by, used_at from public.topup_codes order by created_at desc limit 100;
```

## 13. Supabase setup for a brand-new project
1. Create a NEW Supabase project (do not reuse another app's).
2. SQL Editor: run Appendix A once (it enables pgcrypto and creates everything). Then optionally run the sample matches (section 12 insert) .
3. Copy Project URL and anon key into .env (EXPO_PUBLIC_SUPABASE_URL / EXPO_PUBLIC_SUPABASE_ANON_KEY). No Supabase Auth settings need changing (the app does not use Supabase Auth).
4. Create test codes with generate_topup_codes and test the flow in section 11.

## 14. Build and release
1. npm install; npx expo install --fix; npx expo start (test on device).
2. eas login; eas init (creates Phantom's own EAS project); set the two EXPO_PUBLIC_* variables in EAS; eas build -p android --profile preview -> APK.
3. Version bump for updates: increase android.versionCode (or autoIncrement) so Android installs over the previous APK.
4. Add an icon and splash image in assets/ and reference them in app.config.js before store release.

## 15. Do-not list
No push notifications. No service_role key in the app. No Supabase Auth. No reading password_hash. No client-side odds/points/balance computation. No localStorage. No HTML/Excel/PowerPoint outputs. No placeholders in the code you return.

---
# APPENDIX A — FULL SQL (run once, as is, in a fresh Supabase project)
```sql
-- ======================================================================
-- PHANTOM FULL SCHEMA (single run, fresh Supabase project)
-- Run once in Supabase -> SQL Editor. Order: extension, base, wallet/odds, auth+lock.
-- Verified on a real project on 2026-11-06 (including rollback test suites).
-- ======================================================================
create extension if not exists pgcrypto with schema extensions;

-- ########## PART 1: base structure ##########

create table public.announcements (
  id bigserial primary key,
  message text not null,
  is_active boolean not null default true,
  created_at timestamptz default now()
);

create table public.avatar_options (
  id bigserial primary key,
  type text not null default 'local',
  source text not null,
  label text,
  is_active boolean not null default true,
  sort_order integer default 0,
  created_at timestamptz default now()
);

create table public.prediction_users (
  id bigserial primary key,
  username text not null,
  password_hash text not null,
  display_name text not null,
  avatar_id integer default 1,
  total_points integer not null default 0,
  rank integer,
  last_seen_announcement_id bigint,
  created_at timestamptz default now(),
  avatar_option_id bigint default 1 references public.avatar_options(id),
  constraint prediction_users_username_key unique (username)
);

create table public.matches (
  id bigserial primary key,
  home_team text not null,
  away_team text not null,
  home_logo text,
  away_logo text,
  league text not null default 'دوري غير محدد',
  match_date date not null default current_date,
  match_time text default '20:00',
  status text not null default 'upcoming',
  home_score integer,
  away_score integer,
  lock_time timestamptz,
  created_at timestamptz default now(),
  odds numeric(3,2) not null default 1.00 check (odds >= 1.00 and odds <= 2.00)
);
create index idx_matches_date on public.matches (match_date);

create table public.predictions (
  id bigserial primary key,
  user_id bigint not null references public.prediction_users(id) on delete cascade,
  match_id bigint not null references public.matches(id) on delete cascade,
  predicted_home integer not null,
  predicted_away integer not null,
  points_earned integer,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  odds_at_prediction numeric(3,2) check (odds_at_prediction >= 1.00 and odds_at_prediction <= 2.00),
  unique (user_id, match_id)
);
create index idx_predictions_user on public.predictions (user_id);
create index idx_predictions_match on public.predictions (match_id);

create table public.friend_challenges (
  id bigserial primary key,
  user_id bigint not null references public.prediction_users(id) on delete cascade,
  friend_id bigint not null references public.prediction_users(id) on delete cascade,
  created_at timestamptz default now(),
  unique (user_id, friend_id)
);

create or replace function public.set_predictions_updated_at()
returns trigger language plpgsql as $function$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $function$;

create or replace function public.update_all_ranks()
returns trigger language plpgsql as $function$
BEGIN
  UPDATE public.prediction_users pu
  SET rank = sub.rank
  FROM (
    SELECT id, DENSE_RANK() OVER (ORDER BY total_points DESC) AS rank
    FROM public.prediction_users
  ) sub
  WHERE pu.id = sub.id;
  RETURN NULL;
END; $function$;

-- Scoring: base points (25 exact / 5 outcome / 1 wrong) x odds locked at prediction time
create or replace function public.calculate_prediction_points()
returns trigger language plpgsql as $function$
BEGIN
  IF NEW.status = 'finished'
     AND NEW.home_score IS NOT NULL
     AND NEW.away_score IS NOT NULL
     AND (OLD.status != 'finished' OR OLD.home_score IS NULL) THEN

    UPDATE public.predictions p
    SET points_earned = round(
      (CASE
        WHEN p.predicted_home = NEW.home_score AND p.predicted_away = NEW.away_score THEN 25
        WHEN (p.predicted_home > p.predicted_away AND NEW.home_score > NEW.away_score)
          OR (p.predicted_home < p.predicted_away AND NEW.home_score < NEW.away_score)
          OR (p.predicted_home = p.predicted_away AND NEW.home_score = NEW.away_score)
        THEN 5
        ELSE 1
      END) * coalesce(p.odds_at_prediction, 1.00)
    )::int
    WHERE p.match_id = NEW.id;

    UPDATE public.prediction_users pu
    SET total_points = (
      SELECT COALESCE(SUM(points_earned), 0)
      FROM public.predictions
      WHERE user_id = pu.id AND points_earned IS NOT NULL
    );
  END IF;
  RETURN NEW;
END; $function$;

create trigger trg_calculate_points after update on public.matches
  for each row execute function public.calculate_prediction_points();
create trigger trg_update_ranks after insert or update of total_points on public.prediction_users
  for each statement execute function public.update_all_ranks();
create trigger trg_predictions_updated_at before update on public.predictions
  for each row execute function public.set_predictions_updated_at();

-- RLS: same policies as Tawaqoati so the app code works unchanged
alter table public.announcements enable row level security;
alter table public.avatar_options enable row level security;
alter table public.prediction_users enable row level security;
alter table public.matches enable row level security;
alter table public.predictions enable row level security;
alter table public.friend_challenges enable row level security;

create policy public_read_announcements on public.announcements for select to public using (true);
create policy public_write_announcements on public.announcements for all to public using (true) with check (true);
create policy admin_all_avatars on public.avatar_options for all to public using (true) with check (true);
create policy public_read_avatars on public.avatar_options for select to public using (true);
create policy public_all_friends on public.friend_challenges for all to public using (true) with check (true);
create policy public_read_matches on public.matches for select to public using (true);
create policy public_update_pred_users on public.prediction_users for update to public using (true) with check (true);
create policy public_read_pred_users on public.prediction_users for select to public using (true);
create policy public_insert_pred_users on public.prediction_users for insert to public with check (true);
create policy public_read_predictions on public.predictions for select to public using (true);
create policy public_insert_predictions on public.predictions for insert to public with check (true);
create policy public_update_predictions on public.predictions for update to public using (true);

-- Avatar options (app config; prediction_users.avatar_option_id defaults to 1)
insert into public.avatar_options (id, type, source, label, is_active, sort_order) values
  (1, 'local', '1', 'أفاتار 1', true, 1),
  (2, 'local', '2', 'أفاتار 2', true, 2),
  (3, 'local', '3', 'أفاتار 3', true, 3),
  (4, 'local', '4', 'أفاتار 4', true, 4),
  (5, 'local', '5', 'أفاتار 5', true, 5),
  (6, 'remote', 'https://www.footyrenders.com/render/kevin-de-bruyne-74-248x540.png', 'أفاتار 6', true, 6),
  (7, 'local', '7', 'أفاتار 7', true, 7),
  (8, 'local', '8', 'أفاتار 8', true, 8),
  (9, 'local', '9', 'أفاتار 9', true, 9),
  (10, 'local', '10', 'أفاتار 10', true, 10),
  (11, 'local', '11', 'أفاتار 11', true, 11),
  (12, 'local', '12', 'avatar-2', false, 12);
select setval(pg_get_serial_sequence('public.avatar_options', 'id'), 12);

-- ########## PART 2: wallet, verification, stars, odds ##########

-- 1) Manual odds (1.00 - 2.00), set by admins directly in the database
alter table public.matches
  add column if not exists odds numeric(3,2) not null default 1.00
  check (odds >= 1.00 and odds <= 2.00);

-- Odds are frozen per prediction at save time (set by a trigger, not by the client)
alter table public.predictions
  add column if not exists odds_at_prediction numeric(3,2)
  check (odds_at_prediction >= 1.00 and odds_at_prediction <= 2.00);

-- 2) Account / wallet tables (no client access: only via the functions below)
create table if not exists public.gate_config (
  id int primary key default 1 check (id = 1),
  enforce_from timestamptz not null
);
-- Phantom is new: every account created after this moment must verify before predicting.
insert into public.gate_config (id, enforce_from) values (1, now()) on conflict (id) do nothing;

create table if not exists public.user_accounts (
  user_id bigint primary key references public.prediction_users(id) on delete cascade,
  balance bigint not null default 0 check (balance >= 0),
  verified_at timestamptz,
  badge text check (badge in ('red', 'green', 'yellow')),
  referral_code text,
  created_at timestamptz not null default now()
);

create table if not exists public.wallet_transactions (
  id bigint generated always as identity primary key,
  user_id bigint not null references public.prediction_users(id) on delete cascade,
  direction text not null check (direction in ('credit', 'debit')),
  kind text not null check (kind in ('topup', 'adjust')),
  amount bigint not null check (amount > 0),
  balance_after bigint not null,
  description text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists wallet_tx_user_idx on public.wallet_transactions (user_id, created_at desc);

create table if not exists public.topup_codes (
  code text primary key check (code ~ '^[0-9]{12}$'),
  amount bigint not null check (amount > 0),
  status text not null default 'unused' check (status in ('unused', 'used', 'disabled')),
  used_by bigint references public.prediction_users(id),
  used_at timestamptz,
  batch_id uuid,
  created_at timestamptz not null default now()
);

create table if not exists public.redeem_attempts (
  id bigint generated always as identity primary key,
  user_id bigint,
  success boolean not null,
  created_at timestamptz not null default now()
);
create index if not exists redeem_attempts_user_idx on public.redeem_attempts (user_id, created_at desc);

alter table public.gate_config enable row level security;
alter table public.user_accounts enable row level security;
alter table public.wallet_transactions enable row level security;
alter table public.topup_codes enable row level security;
alter table public.redeem_attempts enable row level security;
revoke all on public.gate_config, public.user_accounts, public.wallet_transactions,
              public.topup_codes, public.redeem_attempts from anon, authenticated;

-- 3) Gate + odds lock on predictions
create or replace function public.predictions_gate_and_odds()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_from timestamptz; v_created timestamptz; v_verified timestamptz; v_odds numeric(3,2);
begin
  if tg_op = 'UPDATE' then
    if new.predicted_home is not distinct from old.predicted_home
       and new.predicted_away is not distinct from old.predicted_away then
      new.odds_at_prediction := old.odds_at_prediction;
      return new;
    end if;
  end if;

  select enforce_from into v_from from public.gate_config where id = 1;
  select created_at into v_created from public.prediction_users where id = new.user_id;

  if v_created >= v_from then
    select verified_at into v_verified from public.user_accounts where user_id = new.user_id;
    if v_verified is null then
      raise exception 'not_verified';
    end if;
  end if;

  select odds into v_odds from public.matches where id = new.match_id;
  new.odds_at_prediction := coalesce(v_odds, 1.00);
  return new;
end $$;
revoke all on function public.predictions_gate_and_odds() from public, anon, authenticated;

drop trigger if exists trg_predictions_gate_odds on public.predictions;
create trigger trg_predictions_gate_odds
  before insert or update on public.predictions
  for each row execute function public.predictions_gate_and_odds();

-- 4) Scoring: base points (25 exact / 5 outcome / 1 wrong) x odds locked at prediction time
create or replace function public.calculate_prediction_points()
returns trigger
language plpgsql
as $function$
BEGIN
  IF NEW.status = 'finished'
     AND NEW.home_score IS NOT NULL
     AND NEW.away_score IS NOT NULL
     AND (OLD.status != 'finished' OR OLD.home_score IS NULL) THEN

    UPDATE public.predictions p
    SET points_earned = round(
      (CASE
        WHEN p.predicted_home = NEW.home_score AND p.predicted_away = NEW.away_score THEN 25
        WHEN (p.predicted_home > p.predicted_away AND NEW.home_score > NEW.away_score)
          OR (p.predicted_home < p.predicted_away AND NEW.home_score < NEW.away_score)
          OR (p.predicted_home = p.predicted_away AND NEW.home_score = NEW.away_score)
        THEN 5
        ELSE 1
      END) * coalesce(p.odds_at_prediction, 1.00)
    )::int
    WHERE p.match_id = NEW.id;

    UPDATE public.prediction_users pu
    SET total_points = (
      SELECT COALESCE(SUM(points_earned), 0)
      FROM public.predictions
      WHERE user_id = pu.id AND points_earned IS NOT NULL
    );
  END IF;
  RETURN NEW;
END; $function$;

-- 5) Redeem a 12-digit code: credits balance, verifies the account (one use per code)
create or replace function public.redeem_topup_code(p_user_id bigint, p_code text, p_referral text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text := regexp_replace(coalesce(p_code, ''), '\D', '', 'g');
  v_ref text := nullif(btrim(coalesce(p_referral, '')), '');
  v_row public.topup_codes%rowtype;
  v_acc public.user_accounts%rowtype;
  v_fails int;
begin
  if not exists (select 1 from public.prediction_users where id = p_user_id) then
    return jsonb_build_object('ok', false, 'error', 'invalid_user');
  end if;
  if v_ref is not null and char_length(v_ref) > 32 then
    return jsonb_build_object('ok', false, 'error', 'invalid_referral');
  end if;

  select count(*) into v_fails from public.redeem_attempts
   where user_id = p_user_id and success = false and created_at > now() - interval '15 minutes';
  if v_fails >= 5 then
    return jsonb_build_object('ok', false, 'error', 'too_many_attempts');
  end if;

  if char_length(v_code) <> 12 then
    insert into public.redeem_attempts (user_id, success) values (p_user_id, false);
    return jsonb_build_object('ok', false, 'error', 'invalid_code');
  end if;

  select * into v_row from public.topup_codes where code = v_code for update;
  if not found or v_row.status <> 'unused' then
    insert into public.redeem_attempts (user_id, success) values (p_user_id, false);
    return jsonb_build_object('ok', false, 'error', 'invalid_code');
  end if;

  update public.topup_codes set status = 'used', used_by = p_user_id, used_at = now() where code = v_code;

  insert into public.user_accounts (user_id) values (p_user_id) on conflict (user_id) do nothing;
  update public.user_accounts
     set balance = balance + v_row.amount,
         verified_at = coalesce(verified_at, now()),
         referral_code = coalesce(referral_code, v_ref)
   where user_id = p_user_id
   returning * into v_acc;

  insert into public.wallet_transactions (user_id, direction, kind, amount, balance_after, description)
  values (p_user_id, 'credit', 'topup', v_row.amount, v_acc.balance, 'تعبئة رصيد بكود');
  insert into public.redeem_attempts (user_id, success) values (p_user_id, true);

  return jsonb_build_object('ok', true, 'amount', v_row.amount, 'balance', v_acc.balance,
                            'verified', true, 'badge', v_acc.badge);
end $$;

-- 6) Read / badge functions used by the app
create or replace function public.get_account(p_user_id bigint)
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_acc public.user_accounts%rowtype; v_from timestamptz; v_created timestamptz; v_pts int; v_rank int;
begin
  select created_at, total_points, rank into v_created, v_pts, v_rank
    from public.prediction_users where id = p_user_id;
  if not found then return null; end if;
  select * into v_acc from public.user_accounts where user_id = p_user_id;
  select enforce_from into v_from from public.gate_config where id = 1;
  return jsonb_build_object(
    'balance', coalesce(v_acc.balance, 0),
    'verified', v_acc.verified_at is not null,
    'badge', v_acc.badge,
    'can_predict', (v_acc.verified_at is not null) or (v_created < v_from),
    'total_points', v_pts,
    'rank', v_rank
  );
end $$;

create or replace function public.set_badge(p_user_id bigint, p_badge text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_badge not in ('red', 'green', 'yellow') then
    return jsonb_build_object('ok', false, 'error', 'invalid_badge');
  end if;
  update public.user_accounts set badge = p_badge where user_id = p_user_id and verified_at is not null;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_verified');
  end if;
  return jsonb_build_object('ok', true, 'badge', p_badge);
end $$;

create or replace function public.get_badges()
returns table (user_id bigint, badge text)
language sql
security definer
stable
set search_path = public
as $$
  select a.user_id, a.badge from public.user_accounts a where a.badge is not null and a.verified_at is not null;
$$;

create or replace function public.get_points_history(p_user_id bigint)
returns table (
  match_id bigint, home_team text, away_team text, league text, match_date date,
  predicted_home int, predicted_away int, final_home int, final_away int,
  odds numeric, points_earned int, running_total bigint
)
language sql
security definer
stable
set search_path = public
as $$
  select t.match_id, t.home_team, t.away_team, t.league, t.match_date,
         t.predicted_home, t.predicted_away, t.final_home, t.final_away,
         t.odds, t.points_earned, t.running_total
  from (
    select m.id as match_id, m.home_team, m.away_team, m.league, m.match_date,
           p.predicted_home, p.predicted_away,
           m.home_score as final_home, m.away_score as final_away,
           coalesce(p.odds_at_prediction, 1.00) as odds,
           p.points_earned,
           (sum(coalesce(p.points_earned, 0)) over (order by m.match_date, m.id))::bigint as running_total
      from public.predictions p
      join public.matches m on m.id = p.match_id
     where p.user_id = p_user_id
  ) t
  order by t.match_date desc, t.match_id desc;
$$;

create or replace function public.get_wallet_history(p_user_id bigint, p_limit int default 50)
returns table (id bigint, direction text, kind text, amount bigint, balance_after bigint, description text, created_at timestamptz)
language sql
security definer
stable
set search_path = public
as $$
  select w.id, w.direction, w.kind, w.amount, w.balance_after, w.description, w.created_at
    from public.wallet_transactions w
   where w.user_id = p_user_id
   order by w.created_at desc, w.id desc
   limit least(coalesce(p_limit, 50), 200);
$$;

-- 7) Admin only (SQL editor / dashboard; NOT callable by the app)
create or replace function public.generate_topup_codes(p_amount bigint, p_count int)
returns table (new_code text)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_batch uuid := gen_random_uuid();
  v_n bigint; v_code text; i int;
begin
  if p_amount is null or p_amount <= 0 or p_count is null or p_count < 1 or p_count > 5000 then
    raise exception 'invalid_input';
  end if;
  for i in 1..p_count loop
    loop
      v_n := ((('x' || encode(gen_random_bytes(8), 'hex'))::bit(64)::bigint) & 9223372036854775807) % 1000000000000;
      v_code := lpad(v_n::text, 12, '0');
      begin
        insert into public.topup_codes (code, amount, batch_id) values (v_code, p_amount, v_batch);
        exit;
      exception when unique_violation then
        null;
      end;
    end loop;
    new_code := v_code;
    return next;
  end loop;
end $$;

-- 8) Function permissions
revoke all on function public.redeem_topup_code(bigint, text, text) from public, anon, authenticated;
revoke all on function public.get_account(bigint) from public, anon, authenticated;
revoke all on function public.set_badge(bigint, text) from public, anon, authenticated;
revoke all on function public.get_badges() from public, anon, authenticated;
revoke all on function public.get_points_history(bigint) from public, anon, authenticated;
revoke all on function public.get_wallet_history(bigint, int) from public, anon, authenticated;
revoke all on function public.generate_topup_codes(bigint, int) from public, anon, authenticated;

grant execute on function public.redeem_topup_code(bigint, text, text) to anon, authenticated;
grant execute on function public.get_account(bigint) to anon, authenticated;
grant execute on function public.set_badge(bigint, text) to anon, authenticated;
grant execute on function public.get_badges() to anon, authenticated;
grant execute on function public.get_points_history(bigint) to anon, authenticated;
grant execute on function public.get_wallet_history(bigint, int) to anon, authenticated;
-- generate_topup_codes: no grant on purpose

-- ########## PART 3: auth RPCs, profile, match lock ##########
-- Phantom: server-side auth (bcrypt), profile/announcement RPCs, and match lock enforcement

create table if not exists public.login_attempts (
  id bigint generated always as identity primary key,
  username text not null,
  success boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists login_attempts_idx on public.login_attempts (username, created_at desc);
alter table public.login_attempts enable row level security;
revoke all on public.login_attempts from anon, authenticated;

-- internal helper: the safe user payload (never includes password_hash)
create or replace function public.phantom_user_json(p_id bigint)
returns jsonb language sql security definer stable set search_path = public as $$
  select jsonb_build_object('id', id, 'username', username, 'display_name', display_name,
                            'avatar_option_id', avatar_option_id, 'total_points', total_points, 'rank', rank)
    from public.prediction_users where id = p_id;
$$;

create or replace function public.phantom_register(p_username text, p_password text, p_display_name text default null)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare
  v_u text := lower(btrim(coalesce(p_username, '')));
  v_name text := nullif(btrim(coalesce(p_display_name, '')), '');
  v_id bigint;
begin
  if v_u !~ '^[a-z0-9_]{3,20}$' then return jsonb_build_object('ok', false, 'error', 'invalid_username'); end if;
  if char_length(coalesce(p_password, '')) < 6 or char_length(p_password) > 72 then
    return jsonb_build_object('ok', false, 'error', 'invalid_password');
  end if;
  if v_name is not null and char_length(v_name) > 30 then return jsonb_build_object('ok', false, 'error', 'invalid_name'); end if;
  if exists (select 1 from public.prediction_users where lower(username) = v_u) then
    return jsonb_build_object('ok', false, 'error', 'username_taken');
  end if;
  begin
    insert into public.prediction_users (username, password_hash, display_name)
    values (v_u, crypt(p_password, gen_salt('bf', 10)), coalesce(v_name, v_u))
    returning id into v_id;
  exception when unique_violation then
    return jsonb_build_object('ok', false, 'error', 'username_taken');
  end;
  return jsonb_build_object('ok', true, 'user', public.phantom_user_json(v_id));
end $$;

create or replace function public.phantom_login(p_username text, p_password text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare
  v_u text := lower(btrim(coalesce(p_username, '')));
  v_row public.prediction_users%rowtype;
  v_fails int; v_ok boolean := false;
begin
  delete from public.login_attempts where created_at < now() - interval '1 day';
  select count(*) into v_fails from public.login_attempts
   where username = v_u and success = false and created_at > now() - interval '15 minutes';
  if v_fails >= 8 then return jsonb_build_object('ok', false, 'error', 'too_many_attempts'); end if;

  select * into v_row from public.prediction_users where lower(username) = v_u limit 1;
  if found then
    begin
      v_ok := v_row.password_hash = crypt(coalesce(p_password, ''), v_row.password_hash);
    exception when others then v_ok := false;
    end;
  end if;

  if not v_ok then
    insert into public.login_attempts (username, success) values (v_u, false);
    return jsonb_build_object('ok', false, 'error', 'invalid_credentials');
  end if;
  return jsonb_build_object('ok', true, 'user', public.phantom_user_json(v_row.id));
end $$;

create or replace function public.update_profile(p_user_id bigint, p_display_name text, p_avatar_option_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_name text := btrim(coalesce(p_display_name, ''));
begin
  if char_length(v_name) < 1 or char_length(v_name) > 30 then
    return jsonb_build_object('ok', false, 'error', 'invalid_name');
  end if;
  if not exists (select 1 from public.avatar_options where id = p_avatar_option_id and is_active) then
    return jsonb_build_object('ok', false, 'error', 'invalid_avatar');
  end if;
  update public.prediction_users set display_name = v_name, avatar_option_id = p_avatar_option_id where id = p_user_id;
  if not found then return jsonb_build_object('ok', false, 'error', 'invalid_user'); end if;
  return jsonb_build_object('ok', true, 'user', public.phantom_user_json(p_user_id));
end $$;

create or replace function public.mark_announcement_seen(p_user_id bigint, p_id bigint)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  update public.prediction_users
     set last_seen_announcement_id = greatest(coalesce(last_seen_announcement_id, 0), p_id)
   where id = p_user_id;
  return found;
end $$;

-- Gate + odds lock + MATCH LOCK: predictions can only be saved while the match is open
create or replace function public.predictions_gate_and_odds()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_from timestamptz; v_created timestamptz; v_verified timestamptz;
  v_odds numeric(3,2); v_status text; v_lock timestamptz;
begin
  if tg_op = 'UPDATE' then
    if new.predicted_home is not distinct from old.predicted_home
       and new.predicted_away is not distinct from old.predicted_away then
      new.odds_at_prediction := old.odds_at_prediction;
      return new;
    end if;
  end if;

  select enforce_from into v_from from public.gate_config where id = 1;
  select created_at into v_created from public.prediction_users where id = new.user_id;
  if v_created >= v_from then
    select verified_at into v_verified from public.user_accounts where user_id = new.user_id;
    if v_verified is null then raise exception 'not_verified'; end if;
  end if;

  select odds, status, lock_time into v_odds, v_status, v_lock from public.matches where id = new.match_id;
  if not found or v_status <> 'upcoming' or (v_lock is not null and v_lock <= now()) then
    raise exception 'match_locked';
  end if;

  new.odds_at_prediction := coalesce(v_odds, 1.00);
  return new;
end $$;

revoke all on function public.phantom_user_json(bigint) from public, anon, authenticated;
revoke all on function public.phantom_register(text, text, text) from public, anon, authenticated;
revoke all on function public.phantom_login(text, text) from public, anon, authenticated;
revoke all on function public.update_profile(bigint, text, bigint) from public, anon, authenticated;
revoke all on function public.mark_announcement_seen(bigint, bigint) from public, anon, authenticated;
grant execute on function public.phantom_register(text, text, text) to anon, authenticated;
grant execute on function public.phantom_login(text, text) to anon, authenticated;
grant execute on function public.update_profile(bigint, text, bigint) to anon, authenticated;
grant execute on function public.mark_announcement_seen(bigint, bigint) to anon, authenticated;
