# PHANTOM (فانتوم) — COMPLETE BUILD SPECIFICATION
React Native (Expo) + Supabase. Read this whole document, then build the app exactly as described.

## 0. Output rules (how you must answer)
1. Build the COMPLETE app. Return every file in full with its path as a heading. No "...", no "rest of the code", no TODOs.
2. JavaScript + JSX only (no TypeScript). No UI library, no Tailwind/NativeWind. React Native core components + Ionicons.
3. First give the folder tree, then package.json, config files, then every source file, then setup/run/build commands.
4. Every user-facing string is Arabic and lives in ONE file: src/constants/strings.js.
5. Do NOT add push notifications, analytics SDKs, or any native module not listed in section 2.
6. Do NOT create Excel, PowerPoint or HTML deliverables.
7. The code must run on the first try: use only the exact API contract in sections 5 and 6. Never invent RPC names, columns or parameters.

## 1. Product
Phantom is an Arabic (RTL, dark theme) football score-prediction competition app.
- Users sign up with username + password (no email, no phone). Passwords are verified on the server (bcrypt) through RPC functions.
- Users predict the exact final score of upcoming matches. When a match finishes the database awards points automatically.
- Each match has an "odds" multiplier (1.00 to 2.00) set manually by the admins. Points = base points x odds.
- NEW accounts cannot save predictions until they VERIFY the account by entering a secret 12-digit code (which also credits a money balance). They can browse everything before that.
- Verified users pick a colored star (red / green / yellow) shown next to their name in the leaderboard and challenges.
- The home screen has FOUR equal square tiles: المسابقة (contest), الصدارة (leaderboard), المنافسة (challenge friends), and الحساب المالي (finance box: balance + history + top-up).
- There is NO admin UI inside the app. Admins manage matches, odds, results and top-up codes directly in the Supabase SQL Editor (section 12).

## 2. Tech stack and exact SDK details
Reference versions (written and verified against Expo SDK 52):
| Package | Version |
|---|---|
| expo | ~52.0.0 |
| react | 18.3.1 |
| react-native | 0.76.3 |
| expo-router | ~4.0.0 (file-based routing, Stack navigator) |
| @supabase/supabase-js | ^2.45.0 |
| react-native-url-polyfill | ^2.0.0 |
| @react-native-async-storage/async-storage | 1.23.1 |
| zustand | ^5.0.0 (with zustand/middleware persist) |
| @expo/vector-icons | ^14.0.4 (Ionicons) |
| expo-constants | ~17.0.0 |
| expo-linking | ~7.0.0 |
| expo-status-bar | ~2.0.0 |
| react-native-safe-area-context | 4.12.0 |
| react-native-screens | ~4.1.0 |
| @babel/core (dev) | ^7.25.0 |

- Language: JavaScript (JSX). JS engine: Hermes (default). Node 20 LTS. Package manager: npm.
- package.json: "main": "expo-router/entry". babel.config.js: presets ['babel-preset-expo'], api.cache(true).
- After creating package.json run `npx expo install --fix` then `npx expo-doctor`. If a newer Expo SDK is current when you build, move the WHOLE set together with `npx expo install` (never mix versions).
- No native modules beyond the list, so the app runs in Expo Go (if Expo Go supports the SDK version) and builds with EAS without custom native code.
- Environment variables (read with process.env, inlined by Expo at build time):
  EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_ANON_KEY. For EAS cloud builds they must be set as EAS environment variables (a local .env is NOT uploaded). Only the anon key is ever used in the app; never the service_role key.
- Supabase client (src/lib/supabase.js): import 'react-native-url-polyfill/auto'; createClient(url, anonKey, { auth: { storage: AsyncStorage, autoRefreshToken: false, persistSession: false, detectSessionInUrl: false } }). Supabase Auth is NOT used.
- app.config.js (CommonJS module.exports): name 'فانتوم', slug 'phantom', version '1.0.0', orientation 'portrait', userInterfaceStyle 'dark', scheme 'phantom', plugins ['expo-router'], android.package 'com.yourname.phantom', ios.bundleIdentifier 'com.yourname.phantom', ios.supportsTablet false. (Developer replaces "yourname".)
- eas.json: cli.version ">= 12.0.0", appVersionSource "remote"; build profiles: development (developmentClient true, internal, android apk), preview (internal, android apk), production (autoIncrement true).
- Identity isolation: Phantom must never share a Supabase project, EAS projectId, package name or .env with any other app.

## 3. Folder structure
```
app/
  _layout.jsx            Stack + AuthGuard + RTL setup + ErrorBoundary export
  (auth)/_layout.jsx     Stack without header
  (auth)/login.jsx
  (auth)/register.jsx
  index.jsx              Home (header, announcement, 4 tiles)
  matches.jsx            المسابقة
  leaderboard.jsx        الصدارة
  challenges.jsx         المنافسة
  profile.jsx            حسابي
src/
  constants/config.js    env, COLORS, STAR_COLORS, SPACING, RADIUS, RTL helper, AVATAR_EMOJIS, CURRENCY, APP_NAME, MAX_GOALS
  constants/strings.js   ALL Arabic strings
  lib/supabase.js
  lib/errors.js          mapError(): raw error -> Arabic message
  lib/api.js             re-exports lib/api/*
  lib/api/run.js         run(fn) -> { data, error, raw } (never throws)
  lib/api/auth.js  matches.js  social.js
  store/authStore.js     zustand + persist (session user only)
  utils/format.js        formatDay, isMatchOpen
  components/            ui (Button, Loading, Empty, ErrorState), Avatar, MatchCard, Stepper, UserRow, AnnouncementBanner, Tile
  finance/               self-contained finance module (section 8)
```

## 4. Architecture rules
- Screens NEVER call supabase directly: only functions from src/lib/api.js.
- Every API function returns { data, error, raw } and never throws. `error` is a ready Arabic message (or null). `raw` is the original error object (used to detect the server errors 'not_verified' and 'match_locked').
- Every screen implements loading, empty, error (with retry) and pull-to-refresh where it lists data.
- Session: zustand store with persist (AsyncStorage key 'phantom-auth', partialize only { user }). On app start, after hydration, call refreshUser() to refresh points/rank. AuthGuard in app/_layout.jsx is the ONLY place that redirects: no user and not in (auth) -> /(auth)/login; user and in (auth) -> /. Show a splash (ActivityIndicator) until the persisted store has hydrated (useAuthStore.persist.hasHydrated() / onFinishHydration).
- Logout: reset the finance store, clear the user.
- Never select `password_hash` from the client. Never trust the client for odds, points, balance or verification: the server computes them.
- RTL: at the top of app/_layout.jsx run I18nManager.allowRTL(true); if (!I18nManager.isRTL) I18nManager.forceRTL(true) (applies from the next launch). Also use a layout helper so the first launch is correct: RTL.row = isRTL ? 'row' : 'row-reverse'; RTL.start = isRTL ? 'flex-start' : 'flex-end'; text uses textAlign 'right'. Use these in every horizontal row.
- Theme tokens (dark, violet ink + gold): bg #0E0B1C, card #181330, card2 #241D44, border #3A2F66, text #F1ECFF, muted #9D93C4, accent #F2C14E, accentText #2A1E00, credit #3DDC97, debit #FF6B8B, info #8AB4FF. STAR_COLORS: red #FF4D4F, green #2ECC71, yellow #FFC531. SPACING xs4 sm8 md12 lg16 xl24. RADIUS sm8 md12 lg18 pill999. Primary button = accent background with accentText label, min height 48.
- Avatars are EMOJI (no image assets): AVATAR_EMOJIS = ['⚽','🏆','🦁','🦅','🐺','🔥','⭐','🎯','🦊','🐯','🏟️','👑']; the emoji of avatar_option_id n is AVATAR_EMOJIS[(n-1) % 12], drawn inside a colored circle.
- Currency label: "د.ع" (constant CURRENCY). Money is an integer, shown with thousands separators (e.g. 10,000).
- Dates: matches.match_date is 'YYYY-MM-DD' -> show as YYYY/MM/DD plus match_time ('20:00').

## 5. Database contract (tables the client may touch directly)
Tables (all in schema public; created by the SQL in Appendix A):
- prediction_users(id bigint, username, display_name, avatar_option_id, total_points int, rank int, last_seen_announcement_id, created_at, password_hash [NEVER select]).
- matches(id bigint, home_team, away_team, league, match_date date, match_time text, status text 'upcoming'|'finished', home_score, away_score, lock_time timestamptz, odds numeric(3,2) 1.00..2.00).
- predictions(id, user_id, match_id, predicted_home, predicted_away, points_earned int null until the match is finished, odds_at_prediction numeric(3,2), created_at, updated_at; UNIQUE(user_id, match_id)).
- friend_challenges(id, user_id, friend_id, created_at; UNIQUE(user_id, friend_id)).
- announcements(id, message, is_active, created_at). avatar_options(id, type, source, label, is_active, sort_order).
Allowed client queries:
- matches: select * order by match_date asc, id asc limit 200.
- predictions: select * where user_id = me; and savePrediction = upsert({ user_id, match_id, predicted_home, predicted_away }, { onConflict: 'user_id,match_id' }).select().single(). Do NOT send odds_at_prediction or points_earned: the server sets them.
- prediction_users: select id, display_name, username, total_points, rank, avatar_option_id (leaderboard: order total_points desc, id asc, limit 100); and select id, username, display_name, avatar_option_id, total_points, rank, last_seen_announcement_id where id = me (refreshUser).
- friend_challenges: select id, friend:prediction_users!friend_challenges_friend_id_fkey(id, display_name, username, total_points, rank, avatar_option_id) where user_id = me order by created_at desc; insert { user_id, friend_id }; delete by id.
- announcements: select where is_active order by id desc limit 1 (maybeSingle). avatar_options: select where is_active order by sort_order.

## 6. RPC contract (call with supabase.rpc; parameter names are exact)
Auth / profile
- phantom_register({ p_username, p_password, p_display_name }) -> { ok:true, user:{id,username,display_name,avatar_option_id,total_points,rank} } | { ok:false, error: 'invalid_username'|'invalid_password'|'invalid_name'|'username_taken' }. Username is lowercased server-side, 3-20 chars [a-z0-9_]; password 6-72 chars; display name optional (<=30), defaults to the username.
- phantom_login({ p_username, p_password }) -> { ok:true, user } | { ok:false, error:'invalid_credentials'|'too_many_attempts' } (8 failures / 15 min per username).
- update_profile({ p_user_id, p_display_name, p_avatar_option_id }) -> { ok:true, user } | { ok:false, error:'invalid_name'|'invalid_avatar'|'invalid_user' }.
- mark_announcement_seen({ p_user_id, p_id }) -> boolean.
Finance / verification
- get_account({ p_user_id }) -> { balance, verified, badge:'red'|'green'|'yellow'|null, can_predict, total_points, rank }.
- redeem_topup_code({ p_user_id, p_code, p_referral }) -> { ok:true, amount, balance, verified:true, badge } | { ok:false, error:'invalid_code'|'too_many_attempts'|'invalid_referral'|'invalid_user' }. The code is 12 digits (non-digits are stripped server-side), single use, 5 wrong attempts / 15 min per user. A successful redeem credits the balance AND verifies the account. p_referral is optional (<=32 chars) and only stored.
- set_badge({ p_user_id, p_badge }) -> { ok:true, badge } | { ok:false, error:'invalid_badge'|'not_verified' } (verified accounts only).
- get_badges() -> [{ user_id, badge }] (only users that have a badge).
- get_points_history({ p_user_id }) -> rows { match_id, home_team, away_team, league, match_date, predicted_home, predicted_away, final_home, final_away, odds, points_earned, running_total } newest first; running_total is the cumulative sum of points_earned in chronological order.
- get_wallet_history({ p_user_id, p_limit }) -> rows { id, direction:'credit'|'debit', kind, amount, balance_after, description, created_at } newest first.
Server errors raised by the predictions trigger (message text): 'not_verified' (account not verified) and 'match_locked' (match not 'upcoming' or lock_time passed).

## 7. Points and odds rules
- Base points: exact score = 25; correct outcome (win/draw/loss) = 5; otherwise = 1.
- points_earned = round_half_up(base x odds_at_prediction). Odds are frozen on the server at the moment the prediction is saved or its scores are changed (read from matches.odds). Example, odds 1.35: exact 34, outcome 7, wrong 1; odds 1.50 exact = 38.
- Client display of expected points must use integer maths identical to the server: cents = Math.round(odds*100); points = Math.floor((base*cents + 50) / 100).
- A prediction can be edited until the match locks. After a match is 'finished' points_earned is filled by the database; total_points and rank are maintained by triggers. The client NEVER computes them.
- Display rule: odds shown as "x1.35" with two decimals.

## 8. Finance module (src/finance, self-contained)
Files: supabaseClient.js (re-exports supabase from ../lib/supabase), theme.js (re-exports the app theme), strings.js, format.js, api.js (getAccount, getPointsHistory, getWalletHistory, getBadges, setBadge, redeemCode, isNotVerifiedError(raw) -> message includes 'not_verified'), store.js (zustand: account, badges, loadAccount(userId) returns the account, loadBadges, applyRedeem, applyBadge, reset), usePredictionGate.js, index.js and components/: FinanceBox, FinanceSheet, TopupForm, BadgePicker, PointsHistory, WalletHistory, StarBadge (+NameWithBadge), OddsBadge (+ExpectedPoints), Btn.
- FinanceBox: SQUARE tile (aspectRatio 1, gold border) showing a wallet icon, the star badge (top corner), the label "الحساب المالي", the balance large, and the currency. Tap opens FinanceSheet.
- FinanceSheet: ONE Modal (bottom sheet, 88% height in account view) with internal views (never nested modals): 'account', 'gate', 'topup', 'badge'.
  - account view: balance (large, gold), status (verified + star, or "غير موثّق"), buttons "تعبئة" and (if verified) "اختر نجمتك"; two tabs: "سجل النقاط" (PointsHistory) and "سجل الرصيد" (WalletHistory).
  - gate view: title "حسابك غير موثّق", text "يمكنك تصفّح المباريات، لكن لحفظ توقعاتك يجب توثيق حسابك أولاً.", button "وثّق الآن" (-> topup view), button "إلغاء".
  - topup view (TopupForm): title "توثيق الحساب وتعبئة الرصيد"; field 1 "الكود السري (12 رقماً)" numeric keypad, digits only, displayed grouped as "0000 0000 0000"; field 2 "كود الإحالة (اختياري)" max 32; button "إدخال" disabled until 12 digits, with loading state. Error texts: invalid_code "الكود غير صحيح أو مستخدم من قبل"; too_many_attempts "محاولات كثيرة خاطئة. حاول بعد 15 دقيقة."; invalid_referral "كود الإحالة غير صالح"; offline message. On success: store.applyRedeem, show "تم التوثيق وإضافة {amount} د.ع إلى رصيدك" for ~1.3 s, then go to badge view if the account has no badge, otherwise finish.
  - badge view (BadgePicker): title "اختر نجمتك المميزة", hint "تظهر بجانب اسمك في لوحة الصدارة والمنافسات.", three large star options (red "نجمة حمراء", green "نجمة خضراء", yellow "نجمة صفراء"); optional "لاحقاً" button right after verification; saves with set_badge then store.applyBadge.
  - Android back button: from topup/badge go back to the base view, otherwise close.
- usePredictionGate(userId) returns { guard(action), handleSaveError(raw), gateElement, canPredict }. guard: if the loaded account has can_predict === false, store the action, open the gate sheet and return false; else run the action. handleSaveError(raw): if isNotVerifiedError(raw) open the gate and return true. After successful verification (and badge step) the sheet closes and the pending action runs automatically (the save the user attempted). gateElement is rendered once in the screen.
- PointsHistory: per match card: "home — away", date, "توقعي: a - b", "النتيجة: x - y" (or "لم تنتهِ"), odds "x1.35", "النقاط: n" (or "—"), "المجموع: running_total".
- WalletHistory: rows with description, date/time, balance after, amount (+ green for credit, - red for debit).

## 9. Screens (exact behaviour)
### Auth
- login.jsx: logo "فانتوم" (gold, large), tagline "توقّع النتائج، واصعد الصدارة", fields username / password, button "تسجيل الدخول", link to register. register.jsx: fields username (hint "3 إلى 20 حرفاً إنجليزياً أو أرقاماً أو _"), display name (optional), password, confirm; client validation before calling the RPC; map server errors to Arabic (username_taken "اسم المستخدم مستخدم مسبقاً", invalid_credentials "اسم المستخدم أو كلمة المرور غير صحيحة", too_many_attempts "محاولات كثيرة خاطئة. حاول بعد 15 دقيقة.").
### Home (index.jsx) — no stack header
- Top: avatar circle + display name + "نقاطك X · ترتيبك #Y" (from the refreshed user, refresh on screen focus). Tapping it opens /profile.
- AnnouncementBanner: latest active announcement whose id > user.last_seen_announcement_id; a close button calls mark_announcement_seen and hides it.
- Grid 2 x 2 of equal SQUARE tiles: المسابقة (football icon, "توقّع المباريات") -> /matches; الصدارة (podium, "أفضل اللاعبين") -> /leaderboard; المنافسة (people, "تحدَّ أصدقاءك") -> /challenges; and <FinanceBox userId={user.id} style={{flex:1}} />. Tiles share the same size, radius and padding.
### Matches / المسابقة
- Two tabs: "القادمة" (status != finished, ascending by date) and "المنتهية" (finished, descending).
- MatchCard: league + date/time; home team, "ضد", away team; OddsBadge "الأوديس x1.35" centered; two Steppers (minus / value / plus, 0..20) one under each team, pre-filled from the user's existing prediction (else 0-0); ExpectedPoints box (exact/outcome/wrong values at this odds); primary button "احفظ التوقع" (or "تحديث التوقع" if a prediction exists), disabled when nothing changed. After a successful save show "تم حفظ توقعك" in green for 2 s.
- Closed match (status != upcoming or lock_time passed): steppers/button hidden, show "أُغلق التوقع" and the user's prediction if any. Finished match: final score, "توقعي a-b", the odds used, and "النقاط: n".
- Save flow: `await guard(async () => { const r = await savePrediction(...); if (r.raw && handleSaveError(r.raw)) return; if (r.error) { show it on the card; return; } update local predictions; flash success })`. 'match_locked' shows "أُغلق التوقع لهذه المباراة".
- Render {gateElement} once at the bottom of the screen.
### Leaderboard / الصدارة
- Pull-to-refresh list (top 100): rank number (the DB `rank` column, dense), emoji avatar, display name with its star (NameWithBadge using get_badges loaded once per focus), points. Top 3 ranks in gold. The current user's row highlighted with "أنت".
### Challenges / المنافسة
- Card for me (points, rank). Input "اسم المستخدم" + button "إضافة" (adds a friend by exact username, lowercased; errors: unknown "لا يوجد مستخدم بهذا الاسم", self "لا يمكنك إضافة نفسك", duplicate "تمت إضافته مسبقاً").
- Friend list: avatar, display name + star, points, and the comparison versus me: "متقدم عليك بـ N نقطة" / "أنت متقدم عليه بـ N نقطة" / "متعادلان"; a delete button with a confirmation Alert. Empty state: "أضف أصدقاءك بأسماء مستخدميهم وقارن نقاطك بنقاطهم".
### Profile / حسابي
- Shows username (read only), display name input (1-30), avatar grid built from avatar_options (emoji by option id, selected one highlighted), button "حفظ" -> update_profile -> store.setUser. Button "تسجيل الخروج".

## 10. Verification flow (state machine)
1. New account registers -> logged in -> can browse everything.
2. Taps "احفظ التوقع": guard sees can_predict === false -> gate sheet "وثّق الآن".
3. "وثّق الآن" -> top-up form -> redeem_topup_code ok -> balance credited, account verified.
4. If no badge yet -> star picker (can skip with "لاحقاً").
5. Sheet closes and the interrupted prediction is saved automatically; the card flashes "تم حفظ توقعك".
6. From then on the finance box shows the balance, history, and the star appears next to the user's name everywhere.
Server enforcement: the database rejects saving without verification even if the app is bypassed ('not_verified'); handleSaveError covers that path.

## 11. Quality bar and acceptance checklist
- RTL correct on first launch and after restart; no text clipped; Arabic numerals not required (use Latin digits).
- All lists have loading/empty/error states and pull-to-refresh; all buttons show loading and are disabled while busy; no unhandled promise rejections.
- Acceptance tests to pass: (1) register -> login persists after app restart; (2) browse matches without verification; (3) saving a prediction triggers the gate; (4) a valid 12-digit code verifies, credits the balance, then the prediction is saved; (5) the same code is rejected the second time; (6) odds shown on the card equal matches.odds and the stored odds_at_prediction; (7) after the admin finishes a match the points equal base x odds and the leaderboard/rank update; (8) star shows next to the name in leaderboard and challenges; (9) a locked/finished match cannot be edited; (10) logout clears the finance data.

## 12. Admin operations (Supabase SQL Editor)
```sql
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
```
