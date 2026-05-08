#!/usr/bin/env python3
import sys

current_origin = None

# Variabili per la media globale dell'aeroporto
airport_dep_sum = 0.0
airport_dep_count = 0

# Dizionario per memorizzare le statistiche di ogni compagnia in quell'aeroporto
carrier_stats = {}

def emit_result():
    if current_origin is not None and airport_dep_count > 0:
        # 1. Calcoliamo la media globale dell'aeroporto
        airport_avg = airport_dep_sum / airport_dep_count
        
        results = []
        
        # 2. Calcoliamo le statistiche per ogni compagnia
        for carrier, stats in carrier_stats.items():
            if stats['count'] > 0:
                # Evitiamo divisioni per zero nel caso in cui una compagnia abbia solo voli cancellati
                c_dep_avg = stats['dep_sum'] / stats['dep_count'] if stats['dep_count'] > 0 else 0.0
                c_arr_avg = stats['arr_sum'] / stats['arr_count'] if stats['arr_count'] > 0 else 0.0
                c_canc_rate = (stats['cancelled'] * 100.0) / stats['count']
                
                # Differenza tra media compagnia e media aeroporto
                diff = c_dep_avg - airport_avg
                
                results.append({
                    'carrier': carrier,
                    'flights': stats['count'],
                    'dep_avg': c_dep_avg,
                    'arr_avg': c_arr_avg,
                    'canc_rate': c_canc_rate,
                    'diff': diff
                })
                
        # 3. Ordiniamo la lista per ritardo medio di partenza crescente (per fare il RANK)
        results.sort(key=lambda x: x['dep_avg'])
        
        # 4. Stampiamo i risultati aggiungendo la posizione in classifica
        rank = 1
        for res in results:
            # Formato: aeroporto_partenza, compagnia, numero_voli, ritardo_medio_partenza, ritardo_medio_arrivo, tasso_cancellazione, differenza, classifica
            print(f"{current_origin},{res['carrier']},{res['flights']},{res['dep_avg']:.2f},{res['arr_avg']:.2f},{res['canc_rate']:.1f},{res['diff']:.2f},{rank}")
            rank += 1

# Lettura dello stream
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
        
    try:
        origin, value = line.split("\t", 1)
        carrier, dep_str, arr_str, canc_str = value.split(",")
        
        dep_delay = float(dep_str)
        arr_delay = float(arr_str)
        cancelled = int(canc_str)
    except ValueError:
        continue

    # Cambio aeroporto: elaboriamo i dati precedenti e resettiamo le strutture
    if current_origin != origin:
        emit_result()
        current_origin = origin
        airport_dep_sum = 0.0
        airport_dep_count = 0
        carrier_stats = {}

    # Inizializziamo il dizionario per la compagnia se non esiste ancora
    if carrier not in carrier_stats:
        carrier_stats[carrier] = {
            'count': 0, 'cancelled': 0, 
            'dep_sum': 0.0, 'dep_count': 0, 
            'arr_sum': 0.0, 'arr_count': 0
        }

    # Aggiorniamo i contatori totali della compagnia
    carrier_stats[carrier]['count'] += 1
    
    if cancelled == 1:
        carrier_stats[carrier]['cancelled'] += 1
    else:
        # Aggiorniamo i contatori per la media GLOBALE dell'aeroporto
        airport_dep_sum += dep_delay
        airport_dep_count += 1
        
        # Aggiorniamo i contatori per la media della SINGOLA compagnia
        carrier_stats[carrier]['dep_sum'] += dep_delay
        carrier_stats[carrier]['dep_count'] += 1
        carrier_stats[carrier]['arr_sum'] += arr_delay
        carrier_stats[carrier]['arr_count'] += 1

# Emette i risultati dell'ultimo aeroporto processato
emit_result()