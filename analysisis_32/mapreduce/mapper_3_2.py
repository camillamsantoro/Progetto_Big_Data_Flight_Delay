#!/usr/bin/env python3
import sys

for line in sys.stdin:
    line = line.strip()
    
    # Salta l'intestazione o righe vuote
    if not line or line.startswith("month"):
        continue

    tokens = line.split(",")
    
    # Per l'analisi 3.2 ci servono le cause di ritardo (che sono in fondo al file)
    if len(tokens) >= 15:
        try:
            month = tokens[0]
            origin = tokens[4]
            
            dep_delay_str = tokens[6]
            arr_delay_str = tokens[7]
            cancelled_str = tokens[8]
            # cancellation_code (col 9): A/B/C/D o vuoto per voli non cancellati
            canc_code = tokens[9].strip() if tokens[9].strip() else ""

            # Cause di ritardo (colonne 10-14)
            carrier = tokens[10]
            weather = tokens[11]
            nas = tokens[12]
            security = tokens[13]
            late = tokens[14]

            # Chiave: aeroporto_partenza, mese
            key = f"{origin},{month}"

            # Valore: dep_delay, arr_delay, cancelled, cancellation_code, cause delay
            value = f"{dep_delay_str},{arr_delay_str},{cancelled_str},{canc_code},{carrier},{weather},{nas},{security},{late}"
            
            print(f"{key}\t{value}")
            
        except IndexError:
            pass