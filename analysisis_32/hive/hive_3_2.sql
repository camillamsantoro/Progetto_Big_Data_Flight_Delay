with cause_ritardi as(

    select origin, month, 'Carrier' as causa, sum(carrier_delay) as minuti_totali
    from flights_project.flights where cancelled = 0 group by origin, month

    union all

    select origin, month, 'Weather' as causa, sum(weather_delay) as minuti_totali
    from flights_project.flights where cancelled = 0 group by origin, month

    union all
    
    select origin, month, 'NAS' as causa, sum(nas_delay) as minuti_totali
    from flights_project.flights where cancelled = 0 group by origin, month

    union all
    
    select origin, month, 'Security' as causa, sum(security_delay) as minuti_totali
    from flights_project.flights where cancelled = 0 group by origin, month

    union all

    select origin, month, 'Late Aircraft' as causa, sum(late_aircraft_delay) as minuti_totali
    from flights_project.flights where cancelled = 0 group by origin, month
),
classifica_cause as (
    select origin, month, causa, minuti_totali,
           concat(causa, ' (', cast(minuti_totali as int), ' min)') as cause_desc,
           row_number() over(partition by origin, month order by minuti_totali desc) as ranking
    from cause_ritardi
),
top_3_cause_aggregate as (
    select origin, month,
concat(chr(34), '[', chr(39), concat_ws(concat(chr(39), ', ', chr(39)), collect_list(cause_desc)), chr(39), ']', chr(34)) as cause_maggiori    from classifica_cause
    where ranking <= 3
    group by origin, month
)



select f.origin as aeroporto_partenza,
       f.month as mese,
       sum(case when f.cancelled = 0 and f.dep_delay < 15.0 then 1 else 0 end) as numero_ritardi_basso,
       sum(case when f.cancelled = 0 and f.dep_delay between 15.0 and 60.0 then 1 else 0 end) as numero_ritardi_medio,
       sum(case when f.cancelled = 0 and f.dep_delay > 60.0 then 1 else 0 end) as numero_ritardo_alto,
       coalesce(max(t.cause_maggiori), '"[]"') as cause_maggiori
from flights_project.flights f
left join top_3_cause_aggregate t on f.origin = t.origin and f.month = t.month
group by f.origin, f.month
order by f.origin, f.month