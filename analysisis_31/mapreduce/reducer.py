#!/usr/bin/env python3
import sys

current_key = None
total_flights = 0
cancelled_count = 0
min_delay = float('inf')
max_delay = float('-inf')
valid_min_found = False
valid_max_found = False
sum_delay = 0.0

def emit_result():
    """Funzione per stampare il risultato aggregato di una chiave in formato CSV."""
    global current_key, total_flights, cancelled_count, min_delay, max_delay
    global valid_min_found, valid_max_found, sum_delay
    
    if current_key is not None and total_flights > 0:
        carrier, origin, month = current_key.split(",")
        
        # Logica dei coalesce: se non abbiamo trovato valori validi, stampiamo 0.0
        final_min = min_delay if valid_min_found else 0.0
        final_max = max_delay if valid_max_found else 0.0
        final_avg = sum_delay / total_flights
        cancellation_rate = (cancelled_count * 100.0) / total_flights
        
        # Formato di output CSV: codice, aeroporto_partenza, numero_voli, ritardo_minimo, ritardo_massimo, ritardo_medio, tasso_cancellazione, mese
        print(f"{carrier},{origin},{total_flights},{final_min:.1f},{final_max:.1f},{final_avg:.2f},{cancellation_rate:.1f},{month}")

# Leggiamo l'output del mapper
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
        
    try:
        # Separiamo la chiave dal valore usando il TAB
        key, value = line.split("\t", 1)
        arr_delay_str, cancelled_str = value.split(",")
        
        arr_delay = float(arr_delay_str)
        cancelled = int(cancelled_str)
    except ValueError:
        continue # Salta righe malformate

    # Se la chiave è cambiata, elaboriamo i risultati della chiave precedente
    if current_key != key:
        emit_result()
        # Resettiamo i contatori per la nuova chiave
        current_key = key
        total_flights = 0
        cancelled_count = 0
        min_delay = float('inf')
        max_delay = float('-inf')
        valid_min_found = False
        valid_max_found = False
        sum_delay = 0.0
        
    # Aggiorniamo i contatori per la chiave corrente
    total_flights += 1
    
    if cancelled == 1:
        cancelled_count += 1
    else:
        if arr_delay >= 1.0:
            min_delay = min(min_delay, arr_delay)
            valid_min_found = True
        max_delay = max(max_delay, arr_delay)
        valid_max_found = True
        
    # greatest(0, coalesce(arr_delay, 0)) per la media
    delay_for_avg = max(0.0, arr_delay)
    sum_delay += delay_for_avg

# Assicuriamoci di emettere l'ultimo gruppo elaborato
emit_result()