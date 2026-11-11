-- Stronger chat contact check on the existing messages table.
-- Replaces public.contains_contact_text. send_message and the messages_no_contact
-- check call this function, so a new row is refused without a second table.
-- Not applied to a hosted project from this change. See docs/CHAT_CONTACT.md
-- and docs/staging_apply_CHAT_1111.sql.

create or replace function public.contains_contact_text(p_body text)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
  v text := lower(coalesce(p_body, ''));
  v_work text;
  v_piece text;
  v_digits text;
  v_found text[];
  k int;
  words text[] := array[
    'zero', 'oh', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine'
  ];
  digits text[] := array['0', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  w int;
  v_len int;
  i int;
  gstart int;
  starts int[] := '{}';
  ends int[] := '{}';
  lens int[] := '{}';
  gi int;
  gj int;
  buf text;
  cursor_at int;
  gap text;
  gap_words text[];
  gap_word text;
  wordy boolean;
  soft boolean;
  blocked boolean;
    plus boolean;
    dictated boolean;
    nwords int;
    ch text;
begin
  if v ~ '[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}' then
    return true;
  end if;
  if v ~ '[a-z0-9._%+\-]{1,40}[[:space:]]*(\[at\]|\(at\))[[:space:]]*[a-z0-9\-]+([[:space:]]*\.[[:space:]]*|[[:space:]]*\[dot\][[:space:]]*|[[:space:]]*\(dot\)[[:space:]]*|[[:space:]]+dot[[:space:]]+)[a-z]{2,}' then
    return true;
  end if;
  if (
      v ~ 'e-?mail'
      or v ~ '(gmail|yahoo|outlook|hotmail|rediffmail|protonmail|icloud|googlemail|ymail)'
    )
    and v ~ '[[:<:]]at[[:>:]]'
    and v ~ '(\[dot\]|\(dot\)|[[:<:]]dot[[:>:]])' then
    return true;
  end if;
  if v ~ '(^|[^a-z0-9])(wa\.me|chat\.whatsapp\.com|api\.whatsapp\.com|whatsapp\.com|t\.me|telegram\.me|telegram\.dog)([^a-z0-9]|$)' then
    return true;
  end if;

  v_work := v;
  for w in 1..array_length(words, 1) loop
    v_work := regexp_replace(
      v_work,
      '[[:<:]]triple[[:space:]]+' || words[w] || '[[:>:]]',
      repeat(digits[w], 3),
      'g'
    );
    v_work := regexp_replace(
      v_work,
      '[[:<:]]double[[:space:]]+' || words[w] || '[[:>:]]',
      repeat(digits[w], 2),
      'g'
    );
  end loop;
  for w in 1..array_length(words, 1) loop
    v_work := regexp_replace(
      v_work,
      '[[:<:]]' || words[w] || '[[:>:]]',
      digits[w],
      'g'
    );
  end loop;
  for w in 0..9 loop
    v_work := regexp_replace(
      v_work,
      '[[:<:]]triple[[:space:]]+' || w::text || '[[:>:]]',
      repeat(w::text, 3),
      'g'
    );
    v_work := regexp_replace(
      v_work,
      '[[:<:]]double[[:space:]]+' || w::text || '[[:>:]]',
      repeat(w::text, 2),
      'g'
    );
  end loop;

  v_work := regexp_replace(v_work, '[[:<:]][0-9]+[[:space:]]*-?[[:space:]]*bhks?[[:>:]]', ' ', 'g');
  v_work := regexp_replace(v_work, '[[:<:]][0-9]+[[:space:]]*-?[[:space:]]*rks?[[:>:]]', ' ', 'g');
  v_work := regexp_replace(v_work, '[[:<:]](floor|fl)\.?[[:space:]]*[0-9]{1,2}[[:>:]]', ' ', 'g');
  v_work := regexp_replace(v_work, '[[:<:]][0-9]{1,2}(st|nd|rd|th)[[:space:]]+floor[[:>:]]', ' ', 'g');
  v_work := regexp_replace(
    v_work,
    '[[:<:]](pin[[:space:]]*code|pincode|pin|zip)[[:space:]]*[1-8][0-9]{5}[[:>:]]',
    ' ',
    'g'
  );
  v_work := regexp_replace(v_work, '[0-9]{1,2}[./-][0-9]{1,2}[./-][0-9]{2,4}', ' ', 'g');
  v_work := regexp_replace(v_work, '[0-9]{4}[./-][0-9]{1,2}[./-][0-9]{1,2}', ' ', 'g');
  v_work := regexp_replace(
    v_work,
    '[[:<:]][0-9]{1,2}(st|nd|rd|th)?[[:space:]]+(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?(,[[:space:]]*[0-9]{2,4})?[[:>:]]',
    ' ',
    'g'
  );
  v_work := regexp_replace(
    v_work,
    '[[:<:]](jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?[[:space:]]+[0-9]{1,2}(st|nd|rd|th)?(,[[:space:]]*[0-9]{4})?[[:>:]]',
    ' ',
    'g'
  );
  v_work := regexp_replace(v_work, '[[:<:]][0-9]{1,2}:[0-9]{2}[[:>:]]', ' ', 'g');
  v_work := regexp_replace(v_work, '[[:<:]][0-9]{1,2}[[:space:]]*(am|pm)[[:>:]]', ' ', 'g');

  for w in 1..12 loop
    v_found := regexp_match(
      v_work,
      '((?:₹|rs\.?|inr)[[:space:]]*[0-9][0-9,]*(?:\.[0-9]{1,2})?)'
    );
    exit when v_found is null;
    v_piece := v_found[1];
    v_digits := regexp_replace(v_piece, '[^0-9]', '', 'g');
    if char_length(v_digits) >= 10 then
      v_work := replace(v_work, v_piece, v_digits);
    else
      v_work := replace(v_work, v_piece, ' ');
    end if;
  end loop;

  for w in 1..12 loop
    v_found := regexp_match(v_work, '([0-9]{1,3}(?:,[0-9]{2,3})+)');
    exit when v_found is null;
    v_piece := v_found[1];
    v_digits := regexp_replace(v_piece, '[^0-9]', '', 'g');
    if char_length(v_digits) >= 10 and char_length(v_digits) <= 15 then
      v_work := replace(v_work, v_piece, v_digits);
    else
      v_work := replace(v_work, v_piece, ' ');
    end if;
  end loop;

  v_len := char_length(v_work);
  i := 1;
  while i <= v_len loop
    ch := substr(v_work, i, 1);
    if ch ~ '[0-9]' then
      gstart := i;
      while i <= v_len and substr(v_work, i, 1) ~ '[0-9]' loop
        i := i + 1;
      end loop;
      starts := array_append(starts, gstart);
      ends := array_append(ends, i);
      lens := array_append(lens, i - gstart);
    else
      i := i + 1;
    end if;
  end loop;

  if starts is null or array_length(starts, 1) is null then
    return false;
  end if;

  for gi in 1..array_length(starts, 1) loop
    if lens[gi] >= 10 and lens[gi] <= 15 then
      return true;
    end if;
    if lens[gi] > 15 then
      continue;
    end if;
    plus := substring(v_work from 1 for starts[gi] - 1) ~ '\+[[:space:]]*$';
    buf := substr(v_work, starts[gi], lens[gi]);
    cursor_at := ends[gi];
    wordy := false;
    dictated := lens[gi] = 1;
    for gj in gi + 1..array_length(starts, 1) loop
      gap := substr(v_work, cursor_at, starts[gj] - cursor_at);
      blocked := false;
      soft := false;
      if char_length(gap) > 48 then
        blocked := true;
      elsif gap ~ '^[[:space:].+()/-]*$' then
        if char_length(gap) > 16 then
          blocked := true;
        else
          soft := true;
        end if;
      else
        gap_words := regexp_split_to_array(btrim(gap), '[[:space:]]+');
        nwords := coalesce(array_length(gap_words, 1), 0);
        if nwords = 0 then
          soft := true;
        elsif nwords > 3 then
          blocked := true;
        else
          soft := false;
          for k in 1..nwords loop
            gap_word := gap_words[k];
            if gap_word !~ '^[a-z'']{1,12}$' then
              blocked := true;
            end if;
          end loop;
          if not blocked then
            wordy := true;
          end if;
        end if;
      end if;
      exit when blocked;
      if char_length(buf) + lens[gj] > 15 then
        exit;
      end if;
      buf := buf || substr(v_work, starts[gj], lens[gj]);
      cursor_at := ends[gj];
      if lens[gj] = 1 then
        dictated := true;
      end if;
      if plus and char_length(buf) >= 10 then
        return true;
      end if;
      if dictated and char_length(buf) >= 10 then
        return true;
      end if;
      if (wordy or soft) and (
        (char_length(buf) = 10 and buf ~ '^[6-9]')
        or (char_length(buf) = 11 and buf ~ '^0')
        or (char_length(buf) = 12 and buf ~ '^91')
        or (char_length(buf) = 13 and buf ~ '^091')
        or (char_length(buf) = 14 and buf ~ '^0091')
      ) then
        return true;
      end if;
    end loop;
  end loop;

  return false;
end;
$$;

comment on function public.contains_contact_text(text) is
  'True for a phone, an email, or a wa.me / WhatsApp / Telegram link. Rents, dates, BHK, floors, and 6-digit pincodes stay false.';

revoke all on function public.contains_contact_text(text) from public, anon;
grant execute on function public.contains_contact_text(text) to authenticated;

-- Records the paste so a later `supabase db push` does not try to run it again.
insert into supabase_migrations.schema_migrations (version, name, statements)
values (
  '20261111130000',
  'chat_contact_guard',
  array['docs/staging_apply_CHAT_1111.sql']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;
