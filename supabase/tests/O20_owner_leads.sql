-- Owner lead inbox. A like and a visit on the owner's listing are leads.
-- Another owner, the tenant, and anon cannot read or write those rows.
-- The payload has no phone, email, or street address.
begin;
select no_plan();

select tests.create_supabase_user(
  'lead_host',
  'lead_host@example.test',
  '+910000000221'
);
select tests.create_supabase_user(
  'lead_other',
  'lead_other@example.test',
  '+910000000222'
);
select tests.create_supabase_user(
  'lead_tenant',
  'lead_tenant@example.test',
  '+910000000223'
);

insert into public.properties (
  id, host_user_id, title, locality, city, property_type, furnishing, rent_inr, status
) values (
  '88888888-8888-4888-8888-888888888701',
  tests.get_supabase_uid('lead_host'),
  '2BHK in Navrangpura',
  'Navrangpura',
  'Ahmedabad',
  'apartment',
  'furnished',
  25000,
  'published'
);

insert into public.property_private_details (property_id, address_line, landmark)
values (
  '88888888-8888-4888-8888-888888888701',
  '12 CG Road, Navrangpura',
  'Near Law Garden'
);

update public.profiles
set display_name = 'Meera K.'
where user_id = tests.get_supabase_uid('lead_tenant');

insert into public.matches (id, participant_a, participant_b)
select
  '88888888-8888-4888-8888-888888888801',
  least(tests.get_supabase_uid('lead_host'), tests.get_supabase_uid('lead_tenant')),
  greatest(tests.get_supabase_uid('lead_host'), tests.get_supabase_uid('lead_tenant'));

insert into public.interests (id, actor_user_id, target_type, target_id, action)
values
  (
    '88888888-8888-4888-8888-888888888820',
    tests.get_supabase_uid('lead_tenant'),
    'property',
    '88888888-8888-4888-8888-888888888701',
    'like'
  ),
  (
    '88888888-8888-4888-8888-888888888821',
    tests.get_supabase_uid('lead_tenant'),
    'property',
    '88888888-8888-4888-8888-888888888701',
    'save'
  ),
  (
    '88888888-8888-4888-8888-888888888822',
    tests.get_supabase_uid('lead_other'),
    'property',
    '88888888-8888-4888-8888-888888888701',
    'pass'
  );

insert into public.visit_requests (
  id, match_id, requester_id, proposed_slots, property_id
) values (
  '88888888-8888-4888-8888-888888888810',
  '88888888-8888-4888-8888-888888888801',
  tests.get_supabase_uid('lead_tenant'),
  '[{"starts_at":"2026-11-02T05:30:00Z"}]'::jsonb,
  '88888888-8888-4888-8888-888888888701'
);

insert into public.visit_requests (
  id, match_id, requester_id, proposed_slots, property_id
) values (
  '88888888-8888-4888-8888-888888888811',
  '88888888-8888-4888-8888-888888888801',
  tests.get_supabase_uid('lead_tenant'),
  '[{"starts_at":"2026-11-03T05:30:00Z"}]'::jsonb,
  null
);

select is(
  (
    select count(*)::int
    from public.owner_leads
    where property_id = '88888888-8888-4888-8888-888888888701'
  ),
  2,
  'a like and a linked visit each become one lead'
);

select is(
  (
    select count(*)::int
    from public.owner_leads
    where source_id in (
      '88888888-8888-4888-8888-888888888821',
      '88888888-8888-4888-8888-888888888822',
      '88888888-8888-4888-8888-888888888811'
    )
  ),
  0,
  'a save, a pass, and an unlinked visit are not leads'
);

select is(
  (
    select status::text
    from public.owner_leads
    where kind = 'interest'
      and property_id = '88888888-8888-4888-8888-888888888701'
  ),
  'new',
  'an interest lead starts as new'
);

select is(
  (
    select status::text
    from public.owner_leads
    where kind = 'visit'
      and property_id = '88888888-8888-4888-8888-888888888701'
  ),
  'new',
  'a visit lead starts as new'
);

select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.owner_leads'::regclass
  ),
  'owner_leads has row level security'
);

select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.owner_lead_audit'::regclass
  ),
  'owner_lead_audit has row level security'
);

select is(
  (
    select count(*)::int
    from pg_policies
    where schemaname = 'public'
      and tablename = 'owner_leads'
      and cmd in ('INSERT', 'UPDATE', 'DELETE', 'ALL')
  ),
  0,
  'owner_leads has no client write policy'
);

select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name in ('owner_leads', 'owner_lead_audit')
      and column_name in ('phone', 'email', 'address_line', 'landmark', 'aadhaar')
  ),
  'lead tables do not store phone, email, or a street address'
);

update public.owner_leads
set created_at = now() - interval '2 hours'
where kind = 'interest'
  and property_id = '88888888-8888-4888-8888-888888888701';

create table tests.lead_ids (
  kind text primary key,
  lead_id uuid not null
);
grant select on tests.lead_ids to authenticated;
insert into tests.lead_ids (kind, lead_id)
select kind::text, id
from public.owner_leads
where property_id = '88888888-8888-4888-8888-888888888701';

select tests.authenticate_as('lead_host');
set local role authenticated;

select is(
  (public.list_owner_leads(
    '88888888-8888-4888-8888-888888888701'
  ) ->> 'ok')::boolean,
  true,
  'the owner can list leads'
);

select is(
  jsonb_array_length(
    public.list_owner_leads('88888888-8888-4888-8888-888888888701') -> 'leads'
  ),
  2,
  'the owner sees the interest and the visit'
);

select ok(
  not exists (
    select 1
    from jsonb_array_elements(
      public.list_owner_leads('88888888-8888-4888-8888-888888888701') -> 'leads'
    ) lead
    cross join lateral jsonb_object_keys(lead) as key(name)
    where key.name not in (
      'id',
      'property_id',
      'kind',
      'status',
      'person_user_id',
      'display_name',
      'created_at',
      'first_replied_at',
      'response_minutes',
      'audit'
    )
  ),
  'lead objects only expose inbox fields'
);

select is(
  position(
    '+910000000223' in public.list_owner_leads(
      '88888888-8888-4888-8888-888888888701'
    )::text
  ),
  0,
  'the lead payload does not include the tenant phone'
);

select is(
  position(
    'lead_tenant@example.test' in public.list_owner_leads(
      '88888888-8888-4888-8888-888888888701'
    )::text
  ),
  0,
  'the lead payload does not include the tenant email'
);

select is(
  position(
    '12 CG Road' in public.list_owner_leads(
      '88888888-8888-4888-8888-888888888701'
    )::text
  ),
  0,
  'the lead payload does not include the street address'
);

select is(
  position(
    'Law Garden' in public.list_owner_leads(
      '88888888-8888-4888-8888-888888888701'
    )::text
  ),
  0,
  'the lead payload does not include the landmark'
);

select is(
  (
    select lead ->> 'display_name'
    from jsonb_array_elements(
      public.list_owner_leads('88888888-8888-4888-8888-888888888701') -> 'leads'
    ) lead
    where lead ->> 'kind' = 'interest'
  ),
  'Meera K.',
  'the owner sees the display name'
);

select is(
  position(
    '+910000000223' in public.list_property_interests(
      '88888888-8888-4888-8888-888888888701'
    )::text
  ),
  0,
  'the people sheet does not include a phone'
);

select is(
  position(
    'lead_tenant@example.test' in public.list_property_interests(
      '88888888-8888-4888-8888-888888888701'
    )::text
  ),
  0,
  'the people sheet does not include an email'
);

select is(
  position(
    '12 CG Road' in public.list_property_interests(
      '88888888-8888-4888-8888-888888888701'
    )::text
  ),
  0,
  'the people sheet does not include a street address'
);

select is(
  (
    public.set_owner_lead_status(
      (select lead_id from tests.lead_ids where kind = 'interest'),
      'replied'
    ) -> 'lead' ->> 'status'
  ),
  'replied',
  'the owner can mark a lead replied'
);

select ok(
  (
    select (lead ->> 'response_minutes')::int between 120 and 180
    from jsonb_array_elements(
      public.list_owner_leads('88888888-8888-4888-8888-888888888701') -> 'leads'
    ) lead
    where lead ->> 'kind' = 'interest'
  ),
  'response time is the minutes from the lead to the first reply'
);

select is(
  (
    select a.actor_id = tests.get_supabase_uid('lead_host')
      and a.from_status = 'new'::public.owner_lead_status
      and a.to_status = 'replied'::public.owner_lead_status
      and a.changed_at is not null
    from public.owner_lead_audit a
    where a.lead_id = (select lead_id from tests.lead_ids where kind = 'interest')
  ),
  true,
  'the audit records who set replied and when'
);

select is(
  (
    public.set_owner_lead_status(
      (select lead_id from tests.lead_ids where kind = 'interest'),
      'replied'
    ) ->> 'unchanged'
  )::boolean,
  true,
  'setting the same status does not write another audit row'
);

select is(
  (
    select count(*)::int
    from public.owner_lead_audit
    where lead_id = (select lead_id from tests.lead_ids where kind = 'interest')
  ),
  1,
  'the first reply is one audit row'
);

select is(
  (public.set_owner_lead_status(
    (select lead_id from tests.lead_ids where kind = 'interest'),
    'won'
  ) ->> 'error'),
  'invalid',
  'an unknown status is refused'
);

reset role;

update public.owner_leads
set first_replied_at = timestamptz '2026-10-20 08:00:00+00'
where id = (select lead_id from tests.lead_ids where kind = 'interest');

select tests.authenticate_as('lead_host');
set local role authenticated;

select is(
  (public.set_owner_lead_status(
    (select lead_id from tests.lead_ids where kind = 'interest'),
    'closed'
  ) -> 'lead' ->> 'status'),
  'closed',
  'the owner can close a lead'
);

select is(
  (public.set_owner_lead_status(
    (select lead_id from tests.lead_ids where kind = 'interest'),
    'replied'
  ) -> 'lead' ->> 'status'),
  'replied',
  'the owner can set replied again after closing'
);

select is(
  (
    select first_replied_at
    from public.owner_leads
    where id = (select lead_id from tests.lead_ids where kind = 'interest')
  ),
  timestamptz '2026-10-20 08:00:00+00',
  'a later reply does not replace the first response time'
);

select is(
  (
    select count(*)::int
    from public.owner_lead_audit
    where lead_id = (select lead_id from tests.lead_ids where kind = 'interest')
  ),
  3,
  'close and a second reply are audited'
);

select is(
  (public.set_owner_lead_status(
    (select lead_id from tests.lead_ids where kind = 'visit'),
    'closed'
  ) -> 'lead' -> 'response_minutes'),
  'null'::jsonb,
  'closing without a reply leaves the response time empty'
);

select is(
  (
    select a.actor_id = tests.get_supabase_uid('lead_host')
      and a.from_status = 'new'::public.owner_lead_status
      and a.to_status = 'closed'::public.owner_lead_status
    from public.owner_lead_audit a
    where a.lead_id = (select lead_id from tests.lead_ids where kind = 'visit')
  ),
  true,
  'closing a visit records the owner and the change'
);

select throws_ok(
  $$update public.owner_leads set status = 'new'$$,
  '42501',
  'permission denied for table owner_leads',
  'the owner cannot skip the audit by writing the row'
);

select throws_ok(
  $$insert into public.owner_leads (property_id, kind, source_id, person_user_id)
    values (
      '88888888-8888-4888-8888-888888888701',
      'interest',
      '88888888-8888-4888-8888-888888888899',
      auth.uid()
    )$$,
  '42501',
  'permission denied for table owner_leads',
  'the owner cannot insert a lead directly'
);

reset role;
select tests.authenticate_as('lead_other');
set local role authenticated;

select is(
  (select count(*)::int from public.owner_leads),
  0,
  'another owner cannot read these leads'
);

select is(
  (select count(*)::int from public.owner_lead_audit),
  0,
  'another owner cannot read the audit'
);

select throws_ok(
  $$update public.owner_leads set status = 'closed'$$,
  '42501',
  'permission denied for table owner_leads',
  'another owner cannot write a lead'
);

select is(
  (public.list_owner_leads(
    '88888888-8888-4888-8888-888888888701'
  ) ->> 'error'),
  'not_owner',
  'another owner is refused the inbox'
);

select is(
  (public.set_owner_lead_status(
    (select lead_id from tests.lead_ids where kind = 'interest'),
    'closed'
  ) ->> 'error'),
  'not_owner',
  'another owner cannot set the status'
);

reset role;
select tests.authenticate_as('lead_tenant');
set local role authenticated;

select is(
  (select count(*)::int from public.owner_leads),
  0,
  'the tenant cannot read the owner inbox'
);

select throws_ok(
  $$update public.owner_lead_audit set to_status = 'closed'$$,
  '42501',
  'permission denied for table owner_lead_audit',
  'the tenant cannot write the audit'
);

select is(
  (public.set_owner_lead_status(
    (select lead_id from tests.lead_ids where kind = 'visit'),
    'replied'
  ) ->> 'error'),
  'not_owner',
  'the tenant cannot set lead status'
);

reset role;
select tests.clear_authentication();
set local role anon;

select throws_ok(
  $$select * from public.owner_leads$$,
  '42501',
  'permission denied for table owner_leads',
  'anon cannot read leads'
);

select throws_ok(
  $$select * from public.owner_lead_audit$$,
  '42501',
  'permission denied for table owner_lead_audit',
  'anon cannot read the audit'
);

select throws_ok(
  $$update public.owner_leads set status = 'closed'$$,
  '42501',
  'permission denied for table owner_leads',
  'anon cannot write a lead'
);

select throws_ok(
  $$select public.list_owner_leads('88888888-8888-4888-8888-888888888701'::uuid)$$,
  '42501',
  'permission denied for function list_owner_leads',
  'anon cannot call the inbox'
);

select throws_ok(
  $$select public.set_owner_lead_status(
    '88888888-8888-4888-8888-888888888820'::uuid,
    'closed'
  )$$,
  '42501',
  'permission denied for function set_owner_lead_status',
  'anon cannot set a lead status'
);

reset role;

delete from public.interests
where id = '88888888-8888-4888-8888-888888888820';

select is(
  (
    select count(*)::int
    from public.owner_leads
    where source_id = '88888888-8888-4888-8888-888888888820'
  ),
  0,
  'removing the interest removes its lead'
);

select * from finish();
rollback;
