with cause_raw as (

    -- Cause di ritardo: conta i voli in cui quella causa è presente (spec: "più frequenti")
    select origin, month, 'Carrier' as causa, count(*) as frequenza
    from flights_project.flights where cancelled = 0 and carrier_delay > 0 group by origin, month
    union all
    select origin, month, 'Weather' as causa, count(*) as frequenza
    from flights_project.flights where cancelled = 0 and weather_delay > 0 group by origin, month
    union all
    select origin, month, 'NAS' as causa, count(*) as frequenza
    from flights_project.flights where cancelled = 0 and nas_delay > 0 group by origin, month
    union all
    select origin, month, 'Security' as causa, count(*) as frequenza
    from flights_project.flights where cancelled = 0 and security_delay > 0 group by origin, month
    union all
    select origin, month, 'Late Aircraft' as causa, count(*) as frequenza
    from flights_project.flights where cancelled = 0 and late_aircraft_delay > 0 group by origin, month

    union all

    -- Cause di cancellazione: cancellation_code A/B/C/D (spec: "cancellazione o ritardo")
    select origin, month, 'Carrier' as causa, count(*) as frequenza
    from flights_project.flights where cancellation_code = 'A' group by origin, month
    union all
    select origin, month, 'Weather' as causa, count(*) as frequenza
    from flights_project.flights where cancellation_code = 'B' group by origin, month
    union all
    select origin, month, 'NAS' as causa, count(*) as frequenza
    from flights_project.flights where cancellation_code = 'C' group by origin, month
    union all
    select origin, month, 'Security' as causa, count(*) as frequenza
    from flights_project.flights where cancellation_code = 'D' group by origin, month
),
cause_ritardi as (
    -- Aggrega causa con stesso nome (es. Carrier da ritardo + Carrier da cancellazione)
    select origin, month, causa, sum(frequenza) as frequenza
    from cause_raw
    group by origin, month, causa
),
classifica_cause as (
    select origin, month, causa, frequenza,
           concat(causa, ' (', cast(frequenza as int), ' voli)') as cause_desc,
           row_number() over(partition by origin, month order by frequenza desc) as ranking
    from cause_ritardi
),
top_3_cause_aggregate as (
    select origin, month,
concat(chr(34), '[', chr(39), concat_ws(concat(chr(39), ', ', chr(39)), collect_list(cause_desc)), chr(39), ']', chr(34)) as cause_maggiori
    from classifica_cause
    where ranking <= 3
    group by origin, month
)

select f.origin as aeroporto_partenza,
       f.month as mese,
       sum(case when f.cancelled = 0 and f.dep_delay < 15.0 then 1 else 0 end) as numero_ritardi_basso,
       round(avg(case when f.cancelled = 0 and f.dep_delay < 15.0 then f.dep_delay end), 2) as dep_avg_basso,
       round(avg(case when f.cancelled = 0 and f.dep_delay < 15.0 then f.arr_delay end), 2) as arr_avg_basso,
       sum(case when f.cancelled = 0 and f.dep_delay between 15.0 and 60.0 then 1 else 0 end) as numero_ritardi_medio,
       round(avg(case when f.cancelled = 0 and f.dep_delay between 15.0 and 60.0 then f.dep_delay end), 2) as dep_avg_medio,
       round(avg(case when f.cancelled = 0 and f.dep_delay between 15.0 and 60.0 then f.arr_delay end), 2) as arr_avg_medio,
       sum(case when f.cancelled = 0 and f.dep_delay > 60.0 then 1 else 0 end) as numero_ritardo_alto,
       round(avg(case when f.cancelled = 0 and f.dep_delay > 60.0 then f.dep_delay end), 2) as dep_avg_alto,
       round(avg(case when f.cancelled = 0 and f.dep_delay > 60.0 then f.arr_delay end), 2) as arr_avg_alto,
       coalesce(max(t.cause_maggiori), '"[]"') as cause_maggiori
from flights_project.flights f
left join top_3_cause_aggregate t on f.origin = t.origin and f.month = t.month
group by f.origin, f.month
order by f.origin, f.month
