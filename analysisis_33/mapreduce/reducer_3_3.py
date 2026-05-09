#!/usr/bin/env python3
import sys

current_origin = None

# Variabili per la media globale dell'aeroporto (solo voli con dep_delay presente)
airport_dep_sum = 0.0
airport_dep_count = 0

# Dizionario per memorizzare le statistiche di ogni compagnia in quell'aeroporto
carrier_stats = {}


def emit_result():
    if current_origin is not None and airport_dep_count > 0:
        airport_avg = airport_dep_sum / airport_dep_count

        results = []
        for carrier, stats in carrier_stats.items():
            if stats['count'] > 0:
                c_dep_avg = stats['dep_sum'] / stats['dep_count'] if stats['dep_count'] > 0 else 0.0
                c_arr_avg = stats['arr_sum'] / stats['arr_count'] if stats['arr_count'] > 0 else 0.0
                c_canc_rate = (stats['cancelled'] * 100.0) / stats['count']
                diff = c_dep_avg - airport_avg

                results.append({
                    'carrier': carrier,
                    'flights': stats['count'],
                    'dep_avg': c_dep_avg,
                    'arr_avg': c_arr_avg,
                    'canc_rate': c_canc_rate,
                    'diff': diff
                })

        results.sort(key=lambda x: x['dep_avg'])

        rank = 1
        for res in results:
            print(f"{current_origin},{res['carrier']},{res['flights']},{res['dep_avg']:.2f},{res['arr_avg']:.2f},{res['canc_rate']:.1f},{res['diff']:.2f},{rank}")
            rank += 1


for line in sys.stdin:
    line = line.strip()
    if not line:
        continue

    try:
        origin, value = line.split("\t", 1)
        carrier, dep_str, arr_str, canc_str = value.split(",")

        # Allineamento a Spark SQL: vuoto → None (escluso dalle medie)
        dep_delay = float(dep_str) if dep_str else None
        arr_delay = float(arr_str) if arr_str else None
        cancelled = int(canc_str)
    except ValueError:
        continue

    if current_origin != origin:
        emit_result()
        current_origin = origin
        airport_dep_sum = 0.0
        airport_dep_count = 0
        carrier_stats = {}

    if carrier not in carrier_stats:
        carrier_stats[carrier] = {
            'count': 0, 'cancelled': 0,
            'dep_sum': 0.0, 'dep_count': 0,
            'arr_sum': 0.0, 'arr_count': 0
        }

    carrier_stats[carrier]['count'] += 1

    if cancelled == 1:
        carrier_stats[carrier]['cancelled'] += 1
    else:
        # Media globale aeroporto: solo se dep_delay presente
        if dep_delay is not None:
            airport_dep_sum += dep_delay
            airport_dep_count += 1
            carrier_stats[carrier]['dep_sum'] += dep_delay
            carrier_stats[carrier]['dep_count'] += 1
        # Media arr_delay compagnia: solo se arr_delay presente
        if arr_delay is not None:
            carrier_stats[carrier]['arr_sum'] += arr_delay
            carrier_stats[carrier]['arr_count'] += 1

emit_result()
