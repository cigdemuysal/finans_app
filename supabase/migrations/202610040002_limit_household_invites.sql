-- A household may contain its creator and one invited member only.
-- Keep the server-side invite endpoint closed once both seats are occupied.
create or replace function public.create_household_invite(target_household_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  invite_code text;
  member_count integer;
begin
  if not public.is_household_member(target_household_id) then
    raise exception 'Bu ortak bütçeye erişiminiz yok.' using errcode = '42501';
  end if;

  select count(*) into member_count
  from public.household_members hm
  where hm.household_id = target_household_id;

  if member_count >= 2 then
    raise exception 'Ortak bütçe zaten iki kişiyle dolu.' using errcode = '23514';
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

revoke all on function public.create_household_invite(uuid) from public;
grant execute on function public.create_household_invite(uuid) to authenticated;
