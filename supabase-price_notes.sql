-- 가격 확인 기록 표(price_notes) 만들기. Day27·Day28에서 만든 표와 같은 구조입니다.
-- 언제 쓰나: 새 Supabase 프로젝트라서 price_notes 표가 없을 때(화면에 PGRST205 "Could not find the table 'public.price_notes'"가 나올 때).
-- 이미 Day27·28에서 표를 만들었다면 쓰지 않아도 됩니다. 실행해도 있는 표와 줄은 지워지지 않습니다.
-- 실행 위치: Supabase SQL Editor에 통째로 붙여넣고 Run. 여러 번 실행해도 됩니다.
-- 이 파일은 표 구조와 안전 장치(RLS, 정책, 권한)만 만듭니다. 저장된 줄(행)은 넣지 않습니다.
-- 실행하다 빨간 오류가 나면 화면 문구를 그대로 강사에게 보여 주세요.
-- 순서: 먼저 supabase-호출기록.sql을 Run한 뒤 이 파일을 Run합니다. 승인 규칙이 관리자 목록(is_admin 함수)을 쓰기 때문입니다.

-- 0) 관리자 확인 함수가 있는지 먼저 봅니다. 없으면 아무것도 바꾸지 않고 멈춥니다.
do $$
begin
  if to_regprocedure('public.is_admin()') is null then
    raise exception 'public.is_admin() 함수가 없습니다. 먼저 supabase-호출기록.sql을 Run한 뒤 이 파일을 다시 Run하세요.';
  end if;
end
$$;

-- 1) 표 만들기 (Day27 3-2와 같은 열 + note 칸)
create table if not exists public.price_notes (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  product_code text not null,
  final_price bigint not null,
  ai_explain text,
  status text not null default '대기'
    constraint price_notes_status_check check (status in ('대기','승인','반려')),
  reviewer text,
  reviewed_at timestamptz,
  note text
);

-- 2) 표가 이미 있던 경우를 Day27 정의에 맞춥니다
alter table public.price_notes add column if not exists note text;
alter table public.price_notes alter column created_at set default now();
-- 저장 시각이 비어 있는 행이 없을 때만 not null을 겁니다(있으면 행을 지우거나 고치지 않고 안내만 남깁니다).
do $$
begin
  if exists (select 1 from public.price_notes where created_at is null) then
    raise notice 'created_at이 비어 있는 행이 있어 not null은 걸지 않았습니다. 해당 행은 그대로 둡니다.';
  else
    alter table public.price_notes alter column created_at set not null;
  end if;
end $$;

-- 3) 상태 제한이 없는 표(표 편집기로 만든 표)에만 제한을 추가합니다
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.price_notes'::regclass
      and conname = 'price_notes_status_check'
  ) then
    alter table public.price_notes
      add constraint price_notes_status_check
      check (status in ('대기','승인','반려'));
  end if;
end
$$;

-- 4) 출입 규칙(RLS) 켜기
alter table public.price_notes enable row level security;

-- 5) 규칙(정책) 네 개. 지우고 다시 만들기 때문에 여러 번 실행해도 됩니다.
--    Day27: 로그인하지 않은 사람은 승인된 행만 읽기
drop policy if exists "승인된 행만 읽기" on public.price_notes;
create policy "승인된 행만 읽기" on public.price_notes
  for select to anon using (status = '승인');

--    Day28: 로그인한 사람만 읽기·저장. 로그인 안 한 사람(anon)에게 저장·수정 규칙은 없습니다.
--    Day34: 승인·반려(수정)는 관리자 목록(admin_users)에 있는 사람만. Day28의 「로그인한 사람만 승인」은 지우고 바꿉니다.
drop policy if exists "로그인한 사람은 모두 읽기" on public.price_notes;
create policy "로그인한 사람은 모두 읽기" on public.price_notes
  for select to authenticated using (true);

drop policy if exists "로그인한 사람만 저장" on public.price_notes;
create policy "로그인한 사람만 저장" on public.price_notes
  for insert to authenticated with check (true);

drop policy if exists "로그인한 사람만 승인" on public.price_notes;
drop policy if exists "관리자만 승인" on public.price_notes;
create policy "관리자만 승인" on public.price_notes
  for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- 6) 표 권한(grant). 정책이 있어도 권한이 없으면 permission denied(42501)가 납니다.
--    anon에게는 읽기만, 로그인한 사람(authenticated)에게는 읽기·저장·수정만 줍니다.
grant select on public.price_notes to anon;
grant select, insert, update on public.price_notes to authenticated;

-- ── 확인 SQL (앞의 -- 를 지우고 Run) ──
-- 표가 있는지:        select count(*) from public.price_notes;
-- RLS가 켜졌는지(true): select relrowsecurity from pg_class where oid = 'public.price_notes'::regclass;
-- 정책 네 개:         select policyname, roles, cmd from pg_policies where tablename = 'price_notes';
-- 수정(UPDATE) 정책이 「관리자만 승인」 하나뿐인지: select policyname from pg_policies where tablename = 'price_notes' and cmd = 'UPDATE';
-- 로그인한 사람 권한(세 칸 모두 true):
-- select has_table_privilege('authenticated', 'public.price_notes', 'select') as can_select,
--        has_table_privilege('authenticated', 'public.price_notes', 'insert') as can_insert,
--        has_table_privilege('authenticated', 'public.price_notes', 'update') as can_update;
