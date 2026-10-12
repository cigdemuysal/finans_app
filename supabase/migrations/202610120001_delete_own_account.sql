-- Google Play ve App Store kuralları gereği kullanıcı hesabını uygulama
-- içinden silebilmelidir. Bu fonksiyon yalnızca çağıran kullanıcının
-- hesabını siler.
--
-- Ortak bütçede başka bir üye kalıyorsa bütçe ve kayıtlar onda kalır:
-- bütçenin sahipliği ve silinen kullanıcının eklediği kayıtlar kalan üyeye
-- devredilir. Bütçede başka üye yoksa bütçe ve tüm kayıtları silinir.
create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  membership record;
  remaining_user_id uuid;
begin
  if current_user_id is null then
    raise exception 'Giriş yapmalısınız.' using errcode = '42501';
  end if;

  for membership in
    select hm.household_id
    from public.household_members hm
    where hm.user_id = current_user_id
  loop
    select hm.user_id into remaining_user_id
    from public.household_members hm
    where hm.household_id = membership.household_id
      and hm.user_id <> current_user_id
    order by hm.joined_at
    limit 1;

    if remaining_user_id is null then
      delete from public.households h where h.id = membership.household_id;
    else
      update public.households
      set created_by = remaining_user_id
      where id = membership.household_id
        and created_by = current_user_id;

      update public.household_members
      set role = 'owner'
      where household_id = membership.household_id
        and user_id = remaining_user_id;

      -- source_local_id yalnızca tek seferlik içe aktarmayı tekrar etmemek
      -- için tutulur; devredilen kayıtlarda kalan üyenin kayıtlarıyla
      -- çakışmaması için temizlenir.
      update public.financial_records
      set created_by = remaining_user_id,
          source_local_id = null
      where household_id = membership.household_id
        and created_by = current_user_id;

      update public.household_invites
      set created_by = remaining_user_id
      where household_id = membership.household_id
        and created_by = current_user_id;

      delete from public.household_members
      where household_id = membership.household_id
        and user_id = current_user_id;
    end if;
  end loop;

  -- Hiçbir bütçeye bağlı kalmamış kayıtlar varsa onları da temizle.
  delete from public.financial_records where created_by = current_user_id;

  delete from auth.users where id = current_user_id;
end;
$$;

revoke all on function public.delete_own_account() from public;
grant execute on function public.delete_own_account() to authenticated;
