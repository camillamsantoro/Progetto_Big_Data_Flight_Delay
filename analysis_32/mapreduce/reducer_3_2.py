#!/usr/bin/env python3
import sys

current_key = None
low_delay = 0
med_delay = 0
high_delay = 0

# Accumulatori per il ritardo medio dep/arr per ciascuna fascia (spec punto b)
low_dep_sum = 0.0; low_arr_sum = 0.0; low_count = 0; low_arr_count = 0
med_dep_sum = 0.0; med_arr_sum = 0.0; med_count = 0; med_arr_count = 0
high_dep_sum = 0.0; high_arr_sum = 0.0; high_count = 0; high_arr_count = 0

# Mappa cancellation_code → nome causa
CANC_CODE_MAP = {'A': 'Carrier', 'B': 'Weather', 'C': 'NAS', 'D': 'Security'}

# Frequenza cause (conta voli in cui quella causa è presente, spec "più frequenti")
causes_freq = {
    'Carrier': 0,
    'Weather': 0,
    'NAS': 0,
    'Security': 0,
    'Late Aircraft': 0
}

def emit_result():
    if current_key is not None:
        origin, month = current_key.split(",")

        dep_avg_basso = round(low_dep_sum / low_count, 2) if low_count > 0 else 0.0
        arr_avg_basso = round(low_arr_sum / low_arr_count, 2) if low_arr_count > 0 else 0.0
        dep_avg_medio = round(med_dep_sum / med_count, 2) if med_count > 0 else 0.0
        arr_avg_medio = round(med_arr_sum / med_arr_count, 2) if med_arr_count > 0 else 0.0
        dep_avg_alto = round(high_dep_sum / high_count, 2) if high_count > 0 else 0.0
        arr_avg_alto = round(high_arr_sum / high_arr_count, 2) if high_arr_count > 0 else 0.0

        sorted_causes = sorted(causes_freq.items(), key=lambda item: item[1], reverse=True)

        top_3_list = []
        for i in range(min(3, len(sorted_causes))):
            causa, freq = sorted_causes[i]
            if freq > 0:
                top_3_list.append(f"'{causa} ({int(freq)} voli)'")

        cause_maggiori = '"[' + ', '.join(top_3_list) + ']"' if top_3_list else '"[]"'

        print(f"{origin},{month},{low_delay},{dep_avg_basso},{arr_avg_basso},{med_delay},{dep_avg_medio},{arr_avg_medio},{high_delay},{dep_avg_alto},{arr_avg_alto},{cause_maggiori}")

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue

    try:
        key, value = line.split("\t", 1)
        tokens = value.split(",")
        dep_delay_str, arr_delay_str, cancelled_str, canc_code = tokens[0], tokens[1], tokens[2], tokens[3]
        carrier_str, weather_str, nas_str, sec_str, late_str = tokens[4], tokens[5], tokens[6], tokens[7], tokens[8]

        dep_delay = float(dep_delay_str) if dep_delay_str else None
        arr_delay = float(arr_delay_str) if arr_delay_str else None
        cancelled = int(cancelled_str)
        carrier_d = float(carrier_str)
        weather_d = float(weather_str)
        nas_d = float(nas_str)
        security_d = float(sec_str)
        late_d = float(late_str)
    except (ValueError, IndexError):
        continue

    if current_key != key:
        emit_result()
        current_key = key
        low_delay = 0; med_delay = 0; high_delay = 0
        low_dep_sum = 0.0; low_arr_sum = 0.0; low_count = 0; low_arr_count = 0
        med_dep_sum = 0.0; med_arr_sum = 0.0; med_count = 0; med_arr_count = 0
        high_dep_sum = 0.0; high_arr_sum = 0.0; high_count = 0; high_arr_count = 0
        causes_freq = {k: 0 for k in causes_freq}

    if cancelled == 0:
        # Frequenza cause di ritardo
        if carrier_d > 0: causes_freq['Carrier'] += 1
        if weather_d > 0: causes_freq['Weather'] += 1
        if nas_d > 0: causes_freq['NAS'] += 1
        if security_d > 0: causes_freq['Security'] += 1
        if late_d > 0: causes_freq['Late Aircraft'] += 1
        # Fasce di ritardo (solo se dep_delay presente)
        if dep_delay is not None:
            if dep_delay < 15.0:
                low_delay += 1
                low_dep_sum += dep_delay; low_count += 1
                if arr_delay is not None:
                    low_arr_sum += arr_delay; low_arr_count += 1
            elif 15.0 <= dep_delay <= 60.0:
                med_delay += 1
                med_dep_sum += dep_delay; med_count += 1
                if arr_delay is not None:
                    med_arr_sum += arr_delay; med_arr_count += 1
            elif dep_delay > 60.0:
                high_delay += 1
                high_dep_sum += dep_delay; high_count += 1
                if arr_delay is not None:
                    high_arr_sum += arr_delay; high_arr_count += 1
    else:
        # Frequenza cause di cancellazione tramite cancellation_code
        causa_canc = CANC_CODE_MAP.get(canc_code)
        if causa_canc:
            causes_freq[causa_canc] += 1

emit_result()
