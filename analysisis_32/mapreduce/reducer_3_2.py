#!/usr/bin/env python3
import sys

current_key = None
low_delay = 0
med_delay = 0
high_delay = 0

# Dizionario per accumulare i minuti per ogni causa
causes_total = {
    'Carrier': 0.0,
    'Weather': 0.0,
    'NAS': 0.0,
    'Security': 0.0,
    'Late Aircraft': 0.0
}

def emit_result():
    if current_key is not None:
        origin, month = current_key.split(",")
        
        # Ordiniamo il dizionario delle cause in ordine decrescente in base ai minuti
        sorted_causes = sorted(causes_total.items(), key=lambda item: item[1], reverse=True)
        
        top_3_list = []
        # Estraiamo le prime 3 cause
        for i in range(min(3, len(sorted_causes))):
            causa, minuti = sorted_causes[i]
            # Mettiamo una condizione logica: mostriamo la causa solo se ha generato effettivamente ritardo
            # (Nel caso in cui un aeroporto in un mese non abbia alcun ritardo in assoluto)
            if minuti >= 0: 
                top_3_list.append(f"'{causa} ({int(minuti)} min)'")
        
        # Formattiamo la stringa esattamente come richiesto dalla tua query SQL: "['Causa (X min)', ...]"
        if top_3_list:
            cause_maggiori = '"[' + ', '.join(top_3_list) + ']"'
        else:
            cause_maggiori = '"[]"'
            
        # Stampiamo il risultato finale
        print(f"{origin},{month},{low_delay},{med_delay},{high_delay},{cause_maggiori}")

# Elaborazione dello stream in ingresso
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
        
    try:
        key, value = line.split("\t", 1)
        dep_delay_str, cancelled_str, carrier_str, weather_str, nas_str, sec_str, late_str = value.split(",")
        
        dep_delay = float(dep_delay_str)
        cancelled = int(cancelled_str)
        carrier = float(carrier_str)
        weather = float(weather_str)
        nas = float(nas_str)
        security = float(sec_str)
        late = float(late_str)
    except ValueError:
        continue

    # Cambio di chiave
    if current_key != key:
        emit_result()
        current_key = key
        # Reset contatori
        low_delay = 0
        med_delay = 0
        high_delay = 0
        causes_total = {k: 0.0 for k in causes_total}

    # Se il volo non è cancellato, aggiorniamo le statistiche
    if cancelled == 0:
        # Aggiorniamo le fasce di ritardo
        if dep_delay < 15.0:
            low_delay += 1
        elif 15.0 <= dep_delay <= 60.0:
            med_delay += 1
        elif dep_delay > 60.0:
            high_delay += 1
            
        # Aggiorniamo i contatori delle cause
        causes_total['Carrier'] += carrier
        causes_total['Weather'] += weather
        causes_total['NAS'] += nas
        causes_total['Security'] += security
        causes_total['Late Aircraft'] += late

# Emette l'ultimo gruppo
emit_result()