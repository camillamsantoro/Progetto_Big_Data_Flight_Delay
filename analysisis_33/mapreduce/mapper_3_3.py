#!/usr/bin/env python3
import sys

for line in sys.stdin:
    line = line.strip()
    
    if not line or line.startswith("month"):
        continue

    tokens = line.split(",")
    
    if len(tokens) >= 10:
        try:
            carrier = tokens[2]
            origin = tokens[4]
            
            # Se i ritardi sono vuoti, li forziamo a 0.0
            dep_delay_str = tokens[6] if tokens[6] else "0.0"
            arr_delay_str = tokens[7] if tokens[7] else "0.0"
            cancelled_str = tokens[8]

            # La chiave è solo l'aeroporto.
            # Il valore contiene la compagnia e i dati necessari ai calcoli.
            print(f"{origin}\t{carrier},{dep_delay_str},{arr_delay_str},{cancelled_str}")
            
        except IndexError:
            pass