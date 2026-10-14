-- PD-06 scoring on the server. Budget, city, locality, furnishing, property type.
-- Gender, religion, caste, age, and marital status are not arguments.

create or replace function public.score_compatibility(
  p_rent_inr integer,
  p_city text,
  p_locality text,
  p_furnishing text,
  p_property_type text,
  p_budget_min_inr integer,
  p_budget_max_inr integer,
  p_pref_city text,
  p_pref_locality text default null,
  p_pref_furnishing text default null,
  p_pref_property_type text default null
)
returns jsonb
language plpgsql
immutable
set search_path = public
as $$
declare
  v_score integer := 0;
  v_reasons jsonb := '[]'::jsonb;
  v_budget integer := 0;
  v_bound integer;
  v_delta numeric;
  v_wanted text;
begin
  if p_rent_inr is not null
     and p_budget_min_inr is not null
     and p_budget_max_inr is not null
     and p_rent_inr >= p_budget_min_inr
     and p_rent_inr <= p_budget_max_inr then
    v_budget := 40;
    v_reasons := v_reasons || jsonb_build_array('Rent sits inside your budget.');
  else
    if p_rent_inr is null
       or p_budget_min_inr is null
       or p_budget_max_inr is null then
      v_budget := 0;
    else
      v_bound := case
        when p_rent_inr < p_budget_min_inr then p_budget_min_inr
        else p_budget_max_inr
      end;
      if v_bound = 0 then
        v_budget := 0;
      else
        v_delta := abs(p_rent_inr - v_bound)::numeric / v_bound;
        v_budget := case when v_delta <= 0.20 then 15 else 0 end;
      end if;
    end if;
    v_reasons := v_reasons || jsonb_build_array(
      case
        when v_budget = 15 then 'Rent is close to your budget.'
        else 'Rent is outside your budget.'
      end
    );
  end if;
  v_score := v_score + v_budget;

  if lower(btrim(coalesce(p_pref_city, ''))) = lower(btrim(coalesce(p_city, '')))
     and btrim(coalesce(p_pref_city, '')) <> '' then
    v_score := v_score + 25;
    v_reasons := v_reasons || jsonb_build_array('City matches ' || btrim(p_city) || '.');
  else
    v_reasons := v_reasons || jsonb_build_array(
      'City does not match ' || btrim(coalesce(p_pref_city, '')) || '.'
    );
  end if;

  v_wanted := btrim(coalesce(p_pref_locality, ''));
  if v_wanted = ''
     or lower(v_wanted) = lower(btrim(coalesce(p_locality, ''))) then
    v_score := v_score + 15;
    v_reasons := v_reasons || jsonb_build_array(
      case
        when v_wanted = '' then 'No locality preference set.'
        else 'Locality matches ' || btrim(coalesce(p_locality, '')) || '.'
      end
    );
  else
    v_reasons := v_reasons || jsonb_build_array('Locality does not match ' || v_wanted || '.');
  end if;

  if p_pref_furnishing is null
     or btrim(p_pref_furnishing) = ''
     or lower(btrim(p_pref_furnishing)) = lower(btrim(coalesce(p_furnishing, ''))) then
    v_score := v_score + 10;
    v_reasons := v_reasons || jsonb_build_array(
      case
        when p_pref_furnishing is null or btrim(p_pref_furnishing) = ''
          then 'No furnishing preference set.'
        else 'Furnishing matches.'
      end
    );
  else
    v_reasons := v_reasons || jsonb_build_array('Furnishing does not match.');
  end if;

  if p_pref_property_type is null
     or btrim(p_pref_property_type) = ''
     or lower(btrim(p_pref_property_type)) = lower(btrim(coalesce(p_property_type, ''))) then
    v_score := v_score + 10;
    v_reasons := v_reasons || jsonb_build_array(
      case
        when p_pref_property_type is null or btrim(p_pref_property_type) = ''
          then 'No property type preference set.'
        else 'Property type matches.'
      end
    );
  else
    v_reasons := v_reasons || jsonb_build_array('Property type does not match.');
  end if;

  return jsonb_build_object('score', v_score, 'reasons', v_reasons);
end;
$$;

comment on function public.score_compatibility(
  integer, text, text, text, text, integer, integer, text, text, text, text
) is
  'PD-06 score. Does not read profiles and does not accept protected traits.';

revoke all on function public.score_compatibility(
  integer, text, text, text, text, integer, integer, text, text, text, text
) from public, anon;

grant execute on function public.score_compatibility(
  integer, text, text, text, text, integer, integer, text, text, text, text
) to authenticated;
