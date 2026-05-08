#!/usr/bin/env python3
import sys

# Leggiamo riga per riga dallo standard input
for line in sys.stdin:
    line = line.strip()
    
    # Saltiamo le righe vuote o l'intestazione del CSV
    if not line or line.startswith("month"):
        continue

    tokens = line.split(",")
    
    # Assicuriamoci che la riga sia formattata correttamente
    if len(tokens) >= 10:
        try:
            month = tokens[0]
            carrier = tokens[2]
            origin = tokens[4]
            
            # Se per qualche motivo arr_delay è vuoto, lo forziamo a 0.0
            arr_delay_str = tokens[7] if tokens[7] else "0.0"
            cancelled_str = tokens[8]

            # Chiave composta: codice_compagnia, aeroporto, mese
            key = f"{carrier},{origin},{month}"
            
            # Valore passato al reducer: arr_delay e cancelled
            value = f"{arr_delay_str},{cancelled_str}"
            
            # Stampa delimitata da TAB (standard per Hadoop Streaming)
            print(f"{key}\t{value}")
            
        except IndexError:
            # Ignora righe malformate
            pass