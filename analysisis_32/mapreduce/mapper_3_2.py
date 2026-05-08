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
            
            # dep_delay (se vuoto mettiamo 0.0)
            dep_delay_str = tokens[6] if tokens[6] else "0.0"
            cancelled_str = tokens[8]
            
            # Cause di ritardo (colonne 10-14)
            carrier = tokens[10]
            weather = tokens[11]
            nas = tokens[12]
            security = tokens[13]
            late = tokens[14]

            # Chiave: aeroporto_partenza, mese
            key = f"{origin},{month}"
            
            # Valore: tutti i parametri che servono per i conteggi
            value = f"{dep_delay_str},{cancelled_str},{carrier},{weather},{nas},{security},{late}"
            
            print(f"{key}\t{value}")
            
        except IndexError:
            pass