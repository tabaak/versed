-- Reporting and automatic hiding.
--
-- A fit accumulates reports; once it crosses the threshold it is hidden, which
-- takes it out of matchmaking immediately (next_matchup() filters on
-- hidden_at) without deleting anything. Clearing hidden_at is a moderator
-- action performed from the dashboard.

create table if not exists public.fit_reports (
  id uuid primary key default gen_random_uuid(),
  fit_id uuid not null references public.fits(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null check (
    reason in ('inappropriate', 'not_an_outfit', 'spam', 'other')
  ),
  note text check (char_length(note) <= 500),
  created_at timestamptz not null default now(),
  constraint fit_reports_one_per_reporter unique (fit_id, reporter_id)
);

create index if not exists fit_reports_fit_idx
on public.fit_reports (fit_id);

alter table public.fit_reports enable row level security;

drop policy if exists "Users can view their own reports"
on public.fit_reports;

create policy "Users can view their own reports"
on public.fit_reports
for select
to authenticated
using (reporter_id = (select auth.uid()));

revoke insert, update, delete on public.fit_reports from authenticated;
grant select on public.fit_reports to authenticated;

-- Number of distinct reporters that pulls a fit from the arena.
create or replace function public.fit_report_threshold()
returns integer
language sql
immutable
as $$
  select 3;
$$;

create or replace function public.report_fit(
  p_fit_id uuid,
  p_reason text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reporter uuid := auth.uid();
  v_owner uuid;
  v_count integer;
begin
  if v_reporter is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select f.owner_id into v_owner
  from public.fits f
  where f.id = p_fit_id
    and f.deleted_at is null
  for update;

  if v_owner is null then
    raise exception 'fit is unavailable' using errcode = '22023';
  end if;

  if v_owner = v_reporter then
    raise exception 'cannot report your own fit' using errcode = '42501';
  end if;

  insert into public.fit_reports (fit_id, reporter_id, reason, note)
  values (p_fit_id, v_reporter, p_reason, p_note)
  on conflict (fit_id, reporter_id) do nothing;

  get diagnostics v_count = row_count;

  if v_count = 0 then
    -- Already reported by this user; treat as success so the UI stays simple.
    return;
  end if;

  update public.fits
  set
    report_count = report_count + 1,
    hidden_at = case
      when hidden_at is not null then hidden_at
      when report_count + 1 >= public.fit_report_threshold() then now()
      else null
    end
  where id = p_fit_id;
end;
$$;

revoke all on function public.report_fit(uuid, text, text) from public, anon;
grant execute on function public.report_fit(uuid, text, text) to authenticated;
