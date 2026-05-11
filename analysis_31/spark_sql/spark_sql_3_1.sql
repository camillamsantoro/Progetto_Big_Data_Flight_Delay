select op_unique_carrier as codice,
        origin as aeroporto_partenza,
        count(*) as numero_voli,
        coalesce(min(case when cancelled = 0 then arr_delay end), 0.0) as ritardo_minimo,
        coalesce(max(case when cancelled = 0 then arr_delay end), 0.0) as ritardo_massimo,
        round(avg(case when cancelled = 0 then arr_delay end), 2) as ritardo_medio,
        round((1.0* sum(case when cancelled = 1 then 1.0 else 0.0 end)) / (1.0*count(*)) * 100.0, 1) as tasso_cancellazione,
        month as mese
from flights_project.flights
group by op_unique_carrier, origin, month
order by op_unique_carrier, origin, month