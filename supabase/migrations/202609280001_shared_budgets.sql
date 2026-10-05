-- Shared household budgets for the Flutter app.
-- Run this migration in the Supabase SQL editor or through Supabase CLI.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 80),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.household_members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (household_id, user_id)
);

create table if not exists public.household_invites (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  code_hash text not null unique,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '7 days'),
  used_at timestamptz,
  revoked_at timestamptz
);

create table if not exists public.financial_records (
  id bigint generated always as identity primary key,
  household_id uuid not null references public.households(id) on delete cascade,
  kind text not null check (kind in ('expense', 'income', 'installment', 'investment')),
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  source_local_id bigint,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists financial_records_import_once_idx
  on public.financial_records (household_id, created_by, kind, source_local_id);

create index if not exists financial_records_household_kind_created_idx
  on public.financial_records (household_id, kind, created_at desc);

create or replace function public.is_household_member(target_household_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.household_members hm
    where hm.household_id = target_household_id
      and hm.user_id = (select auth.uid())
  );
$$;

create or replace function public.create_household(household_name text)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  new_household_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapmalısınız.' using errcode = '42501';
  end if;
  if char_length(trim(household_name)) not between 1 and 80 then
    raise exception 'Ortak bütçe adı 1-80 karakter olmalı.' using errcode = '22023';
  end if;

  insert into public.households (name, created_by)
  values (trim(household_name), auth.uid())
  returning id into new_household_id;

  insert into public.household_members (household_id, user_id, role)
  values (new_household_id, auth.uid(), 'owner');

  return new_household_id;
end;
$$;

create or replace function public.create_household_invite(target_household_id uuid)
returns text
language plpgsql security definer
set search_path = ''
as $$
declare
  invite_code text;
begin
  if not public.is_household_member(target_household_id) then
    raise exception 'Bu ortak bütçeye erişiminiz yok.' using errcode = '42501';
  end if;

  update public.household_invites
  set revoked_at = now()
  where household_id = target_household_id
    and used_at is null
    and revoked_at is null;

  invite_code := upper(encode(extensions.gen_random_bytes(6), 'hex'));
  insert into public.household_invites (household_id, code_hash, created_by)
  values (
    target_household_id,
    encode(extensions.digest(invite_code, 'sha256'), 'hex'),
    auth.uid()
  );
  return invite_code;
end;
$$;

create or replace function public.join_household(invite_code text)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  matched_invite public.household_invites%rowtype;
  member_count integer;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapmalısınız.' using errcode = '42501';
  end if;

  select * into matched_invite
  from public.household_invites hi
  where hi.code_hash = encode(
      extensions.digest(upper(trim(join_household.invite_code)), 'sha256'),
      'hex'
    )
    and hi.used_at is null
    and hi.revoked_at is null
    and hi.expires_at > now()
  for update;

  if matched_invite.id is null then
    raise exception 'Davet kodu geçersiz veya süresi dolmuş.' using errcode = '22023';
  end if;

  perform 1 from public.households h where h.id = matched_invite.household_id for update;
  select count(*) into member_count
  from public.household_members hm
  where hm.household_id = matched_invite.household_id;

  if exists (
    select 1 from public.household_members hm
    where hm.household_id = matched_invite.household_id and hm.user_id = auth.uid()
  ) then
    update public.household_invites set used_at = now() where id = matched_invite.id;
    return matched_invite.household_id;
  end if;

  if member_count >= 2 then
    raise exception 'Ortak bütçede en fazla iki kişi olabilir.' using errcode = '23514';
  end if;

  insert into public.household_members (household_id, user_id, role)
  values (matched_invite.household_id, auth.uid(), 'member');
  update public.household_invites set used_at = now() where id = matched_invite.id;
  return matched_invite.household_id;
end;
$$;

alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.household_invites enable row level security;
alter table public.financial_records enable row level security;

drop policy if exists "Members can read their households" on public.households;
create policy "Members can read their households"
  on public.households for select to authenticated
  using (public.is_household_member(id));

drop policy if exists "Members can read household membership" on public.household_members;
create policy "Members can read household membership"
  on public.household_members for select to authenticated
  using (public.is_household_member(household_id));

drop policy if exists "Members can read shared financial records" on public.financial_records;
create policy "Members can read shared financial records"
  on public.financial_records for select to authenticated
  using (public.is_household_member(household_id));

drop policy if exists "Members can add shared financial records" on public.financial_records;
create policy "Members can add shared financial records"
  on public.financial_records for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and public.is_household_member(household_id)
  );

drop policy if exists "Members can update shared financial records" on public.financial_records;
create policy "Members can update shared financial records"
  on public.financial_records for update to authenticated
  using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

drop policy if exists "Members can delete shared financial records" on public.financial_records;
create policy "Members can delete shared financial records"
  on public.financial_records for delete to authenticated
  using (public.is_household_member(household_id));

revoke all on function public.is_household_member(uuid) from public;
grant execute on function public.is_household_member(uuid) to authenticated;
grant execute on function public.create_household(text) to authenticated;
grant execute on function public.create_household_invite(uuid) to authenticated;
grant execute on function public.join_household(text) to authenticated;
grant select, insert, update, delete on public.financial_records to authenticated;
grant select on public.households, public.household_members to authenticated;
grant usage, select on sequence public.financial_records_id_seq to authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'financial_records'
     ) then
    alter publication supabase_realtime add table public.financial_records;
  end if;
end;
$$;
