-- Allow a signed-in household member to see the other member's account email.
-- The function only returns other accounts in a household the caller belongs to.
create or replace function public.get_other_household_members(
  target_household_id uuid
)
returns table (member_email text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Giriş yapmalısınız.' using errcode = '42501';
  end if;

  if not public.is_household_member(target_household_id) then
    raise exception 'Bu ortak bütçeye erişiminiz yok.' using errcode = '42501';
  end if;

  return query
  select coalesce(u.email, 'E-posta bilgisi yok')::text
  from public.household_members hm
  join auth.users u on u.id = hm.user_id
  where hm.household_id = target_household_id
    and hm.user_id <> auth.uid()
  order by hm.joined_at;
end;
$$;

revoke all on function public.get_other_household_members(uuid) from public;
grant execute on function public.get_other_household_members(uuid) to authenticated;
