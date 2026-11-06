-- Day34 강사용: 호출 기록 표와 허용 사용자 목록 표 (Day28 price_notes 표는 건드리지 않습니다)
-- 실행 위치: Supabase SQL Editor에 통째로 붙여넣고 Run. 실행하다 빨간 오류가 나면 화면 문구를 그대로 강사에게 보여 주세요.
--
-- 구조
--   ai_allowed_users : AI 설명을 쓸 수 있는 사용자 목록 (강사가 관리)
--   admin_users      : 관리자 목록. 화면의 승인·반려, 시트·검사 탭은 이 목록에 있는 사람에게만 보입니다.
--   is_admin()       : 로그인한 사람이 관리자 목록에 있는지 true/false로 돌려줍니다. 화면이 부릅니다.
--   ai_call_log      : 호출 한 번당 한 줄. 사용자별·전체 호출 수를 여기서 셉니다.
--   claim_ai_call()  : 서버 함수가 부르는 함수. 허용 여부 확인 + 한도 확인 + 한 줄 기록을 한 번에 합니다.
--   finish_ai_call() : 호출이 끝나면 결과(성공/오류, 토큰 수)를 적습니다.
-- 두 표는 RLS를 켜고 정책을 하나도 만들지 않습니다. 화면(Publishable key)에서는 표를 직접 읽거나 쓸 수 없고,
-- 아래 두 함수로만 접근합니다. 서버 함수는 Secret key 없이 사용자 토큰으로 이 함수만 부릅니다.

create table if not exists public.ai_allowed_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.ai_call_log (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  user_id uuid not null,
  model text not null,
  status text not null default 'started'
    constraint ai_call_log_status_check check (status in ('started','ok','error')),
  attempts int not null default 0,
  input_tokens int,
  output_tokens int,
  error_kind text,
  finished_at timestamptz
);
create index if not exists ai_call_log_user_time on public.ai_call_log (user_id, created_at);
create index if not exists ai_call_log_time on public.ai_call_log (created_at);

alter table public.ai_allowed_users enable row level security;
alter table public.ai_call_log enable row level security;
revoke all on public.ai_allowed_users from anon, authenticated;
revoke all on public.ai_call_log from anon, authenticated;

-- 관리자 목록: 가입만 해서는 관리자가 아닙니다. 아래 「관리자 추가」로 따로 넣어야 합니다.
create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text,
  note text,
  created_at timestamptz not null default now()
);
alter table public.admin_users enable row level security;
revoke all on public.admin_users from anon, authenticated;

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (select 1 from public.admin_users where user_id = auth.uid());
$$;
revoke execute on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- 한도 숫자는 여기에서만 바꿉니다. (사용자 1명당 60분에 10회, 전체 24시간에 200회)
create or replace function public.claim_ai_call(p_model text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_user_limit constant int := 10;
  v_global_limit constant int := 200;
  v_user_count int;
  v_global_count int;
  v_id bigint;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_allowed');
  end if;
  if not exists (select 1 from public.ai_allowed_users where user_id = v_uid) then
    return jsonb_build_object('ok', false, 'reason', 'not_allowed');
  end if;

  -- 동시에 여러 요청이 와도 세는 순서가 섞이지 않게 한 줄로 세웁니다.
  perform pg_advisory_xact_lock(hashtext('ai_call_log_claim'));

  select count(*) into v_user_count from public.ai_call_log
    where user_id = v_uid and created_at > now() - interval '60 minutes';
  if v_user_count >= v_user_limit then
    return jsonb_build_object('ok', false, 'reason', 'user_limit');
  end if;

  select count(*) into v_global_count from public.ai_call_log
    where created_at > now() - interval '24 hours';
  if v_global_count >= v_global_limit then
    return jsonb_build_object('ok', false, 'reason', 'global_limit');
  end if;

  insert into public.ai_call_log (user_id, model) values (v_uid, left(coalesce(p_model, ''), 60))
    returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;

create or replace function public.finish_ai_call(
  p_id bigint, p_status text, p_attempts int,
  p_input_tokens int, p_output_tokens int, p_error_kind text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.ai_call_log
     set status = case when p_status = 'ok' then 'ok' else 'error' end,
         attempts = coalesce(p_attempts, 0),
         input_tokens = p_input_tokens,
         output_tokens = p_output_tokens,
         error_kind = left(p_error_kind, 40),
         finished_at = now()
   where id = p_id and user_id = auth.uid();
end;
$$;

revoke execute on function public.claim_ai_call(text) from public, anon;
revoke execute on function public.finish_ai_call(bigint, text, int, int, int, text) from public, anon;
grant execute on function public.claim_ai_call(text) to authenticated;
grant execute on function public.finish_ai_call(bigint, text, int, int, int, text) to authenticated;

-- ── 허용 사용자 추가 (가입만 해서는 AI 설명을 쓸 수 없습니다. 이 목록에 따로 넣어야 합니다) ──
-- 순서: ① 화면에서 가입 → 메일 확인 링크를 한 번만 눌러 확인 → 로그인이 되는지 확인
--       ② 아래 둘 중 하나를 SQL Editor에서 실행 (앞의 -- 를 지우고 Run)
-- A) 내 이메일만 허용 (이메일은 화면의 "로그인함: …" 주소와 글자까지 같게)
-- insert into public.ai_allowed_users (user_id, email)
--   select id, email from auth.users where lower(email) = lower('여기에내이메일')
--   on conflict (user_id) do nothing
--   returning email as 이번에_등록된_계정;
-- B) 로그인한 적 있는 계정을 모두 허용 (내 프로젝트에서 가입자가 나뿐일 때만 씁니다. 여러 사람이 쓰는 공용 프로젝트에서는 쓰지 않습니다)
-- insert into public.ai_allowed_users (user_id, email)
--   select id, email from auth.users where last_sign_in_at is not null
--   on conflict (user_id) do nothing
--   returning email as 이번에_등록된_계정;
-- 허용 해제: delete from public.ai_allowed_users where email = '내이메일';
-- 가입 계정별 AI 허용 여부 보기 (AI허용이 true여야 AI 설명이 나옵니다):
-- select u.email, u.email_confirmed_at is not null as 메일확인, a.user_id is not null as AI허용
--   from auth.users u left join public.ai_allowed_users a on a.user_id = u.id order by u.created_at;

-- ── 관리자 추가 (승인·반려, 시트·검사 탭은 이 목록에 있는 사람에게만 보입니다) ──
-- 순서: 가입·로그인이 되는 이메일로, SQL Editor에서 아래를 실행 (앞의 -- 를 지우고 Run)
-- insert into public.admin_users (user_id, email)
--   select id, email from auth.users where lower(email) = lower('여기에내이메일')
--   on conflict (user_id) do nothing
--   returning email as 이번에_등록된_관리자;
-- 관리자 해제: delete from public.admin_users where email = '이메일';
-- 관리자 목록 보기: select email, created_at from public.admin_users order by created_at;
-- ※ 관리자 목록을 바꾸면 화면을 새로 고치거나 다시 로그인해야 반영됩니다.
-- ※ 승인·반려를 막는 규칙(RLS)은 supabase-price_notes.sql의 「관리자만 승인」이 맡습니다. 관리자가 아니면 화면에서 탭이 안 보이고, 규칙도 승인·반려를 막습니다.

-- ── 확인 SQL ──
-- select count(*) from public.ai_allowed_users;
-- select status, count(*) from public.ai_call_log group by status;
-- select user_id, count(*) from public.ai_call_log where created_at > now() - interval '60 minutes' group by user_id;
-- select error_kind, count(*) from public.ai_call_log where status = 'error' group by error_kind;
