# Flight Delay Analysis — Big Data Project

Progetto del corso di **Big Data** (Università degli Studi Roma Tre, Prof. R. Torlone).
Analisi sperimentale del dataset [Flight Delay 2024 di Kaggle](https://www.kaggle.com/datasets/hrishitpatil/flight-data-2024) (~7M record, 35 colonne) usando **MapReduce**, **Hive**, **Spark Core** e **Spark SQL**, con confronto comparativo di efficienza e scalabilità.

Le specifiche complete del progetto sono in `Secondo progetto.pdf`.

---

## 1. Tecnologie

| Tecnologia | Versione | Ruolo |
|------------|----------|-------|
| Hadoop | 3.4.1 | Runtime per MapReduce locale |
| Apache Hive | 2.3.9 | Query SQL su file CSV (metastore Derby embedded) |
| Apache Spark | 3.5.8 (Hadoop 3) | Spark Core (RDD) e Spark SQL |
| Python | 3.x | MapReduce streaming, pulizia dati, grafici |
| Derby | embedded | Metastore Hive (locale, no server) |

Tutte le tecnologie girano in **modalità locale** (no cluster, no HDFS): Hive e Hadoop sono configurati con `fs.defaultFS=file:///` per usare il filesystem locale.

---

## 2. Struttura del progetto

```
flight-delay-bigdata1/
├── README.md                          ← questo file
├── Secondo progetto.pdf               ← specifiche del professore
├── pulizia 19.29.49.ipynb             ← notebook di pulizia dati
│
├── data/
│   ├── raw/
│   │   └── flight_data_2024.csv       ← dataset originale (~1.2 GB, 7M record)
│   └── cleaned/
│       ├── dataset_10.csv  /  .parquet  ← campione 10% (~687k record)
│       ├── dataset_25.csv  /  .parquet
│       ├── dataset_50.csv  /  .parquet
│       ├── dataset_75.csv  /  .parquet
│       ├── dataset_100.csv /  .parquet  ← dataset pulito completo (~6.87M record)
│       └── dataset_150.csv /  .parquet  ← oversampling per test scalabilità
│
├── analysisis_31/                     ← Analisi 3.1: statistiche compagnie aeree
│   ├── hive/        hive_3_1.sql      + setup_table.sql
│   ├── spark_sql/   spark_sql_3_1.sql + setup_table.sql
│   └── mapreduce/   mapper.py         + reducer.py
│
├── analysisis_32/                     ← Analisi 3.2: report ritardi per aeroporto/mese
│   ├── hive/        hive_3_2.sql      + setup_table.sql
│   ├── spark_sql/   spark_sql_3_2.sql + setup_table.sql
│   └── mapreduce/   mapper_3_2.py     + reducer_3_2.py
│
├── analysisis_33/                     ← Analisi 3.3: ranking compagnie anomale per aeroporto
│   ├── spark_core/  spark_core_3_3_.py
│   ├── spark_sql/   spark_sql_3_3.sql + setup_table.sql
│   └── mapreduce/   mapper_3_3.py     + reducer_3_3.py
│
├── results/                           ← output delle analisi (CSV) sul 100%
│   ├── analysis_31/{hive,spark_sql,mapreduce}/
│   │   ├── *_full_results.csv         ← tutti i record
│   │   └── *_top_10results.csv        ← prime 10 righe (richiesta della spec)
│   ├── analysisis_32/{hive,spark_sql,mapreduce}/
│   └── analysisis_33/{spark_core,spark_sql,mapreduce}/
│
├── benchmarks/
│   ├── benchmarks.csv                 ← tempi (Percentuale, Analisi, Tecnologia, Tempo_Secondi)
│   ├── generate_charts.py             ← script grafici matplotlib/seaborn
│   └── charts/
│       ├── scalability_per_analysis.png
│       ├── comparison_100pct.png
│       └── heatmap_times.png
│
├── run_all_analyses.sh                ← esegue TUTTE le analisi su 6 dataset (10–150%)
├── debug_sandbox.sh                   ← test rapido (10%) di 4 implementazioni
├── test_singolo.sh                    ← test interattivo singola analisi/tecnologia
│
├── venv/                              ← ambiente virtuale Python
├── metastore_db/                      ← Derby (auto-generato)
├── hive_warehouse/                    ← warehouse Hive locale (auto-generato)
└── hive_run.log                       ← log errori Hive (auto-generato)
```

---

## 3. Pulizia dati (`pulizia 19.29.49.ipynb`)

Il notebook prepara il dataset partendo dal CSV grezzo in `data/raw/flight_data_2024.csv`.

**Operazioni effettuate:**
1. Caricamento di 7.079.081 record × 35 colonne
2. Eliminazione voli cancellati/dirottati con valori di ritardo mancanti
3. Rimozione colonna `year` (costante = 2024)
4. Conversione `fl_date` in datetime
5. Selezione di 15 colonne rilevanti:
   `month, fl_date, op_unique_carrier, op_carrier_fl_num, origin, dest, dep_delay, arr_delay, cancelled, cancellation_code, carrier_delay, weather_delay, nas_delay, security_delay, late_aircraft_delay`
6. Imputazione delle cause di ritardo (NaN → 0)
7. Rimozione outlier: `arr_delay` fuori range [-30, 1440] minuti (24h) → -206.367 record (2.9%)
8. Generazione subset 10/25/50/75/100/150% (CSV + Parquet)

**Dataset finale:** 6.872.714 record × 15 colonne (~374 MB CSV).

---

## 4. Le tre analisi

### 4.1 — Statistiche compagnie aeree (sezione 3.1 spec)

**Implementazioni:** Hive · Spark SQL · MapReduce

Per ciascuna combinazione `(compagnia, aeroporto_partenza, mese)` calcola:
- numero voli
- ritardo arrivo: minimo, massimo, medio
- tasso di cancellazione (%)
- mese di operatività

**Output schema (`results/analysis_31/<tech>/...`):**
```
codice, aeroporto_partenza, numero_voli, ritardo_minimo, ritardo_massimo, ritardo_medio, tasso_cancellazione, mese
```

### 4.2 — Report ritardi per aeroporto/mese (sezione 3.2 spec)

**Implementazioni:** Hive · Spark SQL · MapReduce

Per ciascuna combinazione `(aeroporto_partenza, mese)`:
- conteggio voli in 3 fasce di ritardo in partenza: basso (<15 min), medio (15–60), alto (>60)
- per ciascuna fascia: ritardo medio in partenza e arrivo
- top-3 cause di ritardo o cancellazione **per frequenza** (numero voli coinvolti).
  Le cause includono sia ritardi (carrier/weather/nas/security/late_aircraft) sia cancellazioni
  (`cancellation_code` A=Carrier, B=Weather, C=NAS, D=Security)

**Output schema:**
```
aeroporto_partenza, mese,
numero_ritardi_basso, dep_avg_basso, arr_avg_basso,
numero_ritardi_medio, dep_avg_medio, arr_avg_medio,
numero_ritardo_alto, dep_avg_alto, arr_avg_alto,
cause_maggiori
```

`cause_maggiori` è una lista in formato `"['Carrier (1234 voli)', 'Weather (567 voli)', 'NAS (89 voli)']"`.

### 4.3 — Ranking compagnie anomale per aeroporto (sezione 3.3 spec)

**Implementazioni:** Spark Core · Spark SQL · MapReduce

Per ciascuna coppia `(aeroporto_partenza, compagnia)`:
- numero voli
- ritardo medio in partenza e in arrivo
- tasso di cancellazione (%)
- differenza tra ritardo medio compagnia e ritardo medio complessivo dell'aeroporto
- classifica della compagnia in quell'aeroporto (1 = miglior performance)

**Output schema:**
```
aeroporto_partenza, compagnia, numero_voli, ritardo_medio_partenza, ritardo_medio_arrivo, tasso_cancellazione, differenza, classifica
```

---

## 5. Esecuzione

### 5.1 Prerequisiti

- macOS / Linux
- Java 8/11 (per Hadoop, Hive, Spark)
- Python 3.9+ con `venv` attivo
- Hadoop 3.4.1, Hive 2.3.9, Spark 3.5.8 installati nei percorsi indicati negli script

```bash
source venv/bin/activate
pip install pandas matplotlib seaborn pyarrow
```

### 5.2 Pulizia dati (una sola volta)

Apri ed esegui in ordine tutte le celle di `pulizia 19.29.49.ipynb`. Genera i CSV/Parquet in `data/cleaned/`.

### 5.3 Test rapido

```bash
bash debug_sandbox.sh           # 4 mini-test su dataset 10%
bash test_singolo.sh            # menu interattivo: scegli tecnologia + analisi
```

### 5.4 Esecuzione completa con benchmark

```bash
bash run_all_analyses.sh        # 9 job × 6 dimensioni dataset = 54 esecuzioni
```

Lo script:
- itera su `PERCENTUALI=(10 25 50 75 100 150)`
- per ogni percentuale lancia tutte e 3 le analisi su tutte le tecnologie applicabili
- registra i tempi in `benchmarks/benchmarks.csv`
- salva i risultati CSV (full + top-10) in `results/` solo per il 100%
- fa rotear le directory temporanee `tmp_csv_db/`, `temp_*.csv`, `/tmp/hive_run_*.sql`

Errori Hive (se presenti) sono in `hive_run.log`.

### 5.5 Generazione grafici

```bash
python3 benchmarks/generate_charts.py
```

Produce in `benchmarks/charts/`:
- `scalability_per_analysis.png` — line chart 3 subplot (uno per analisi), tempo vs % dataset, una linea per tecnologia
- `comparison_100pct.png` — bar chart raggruppato di tutte le tecnologie sull'analisi al 100%
- `heatmap_times.png` — heatmap completa (tecnologia×analisi vs %)

---

## 6. Note tecniche

### 6.1 Hive senza HDFS

Hive di default tenta di connettersi all'HDFS NameNode su `localhost:9000`.
In questo progetto **HDFS non è in esecuzione**, quindi configuriamo Hive per usare il filesystem locale tramite:

```
--hiveconf fs.defaultFS=file:///
--hiveconf hive.metastore.warehouse.dir=file://$BASE_DIR/hive_warehouse
--hiveconf hive.exec.scratchdir=file:///tmp/hive_scratch
```

Inoltre gli script applicano `chmod 1777` sia su `/tmp/hive_scratch` che su `hive_warehouse` per consentire la creazione delle session directory di Hive in locale.

### 6.2 Setup tabella + query in un'unica sessione

Per evitare problemi di lock di Derby tra invocazioni multiple, gli script generano un file SQL combinato `/tmp/hive_run_*.sql` (setup + query) ed eseguono Hive una sola volta per analisi.

### 6.3 Coerenza dei risultati tra tecnologie

Le tre implementazioni di ciascuna analisi sono progettate per produrre output equivalenti (a meno di formattazione minore di numeri float). Le query SQL escludono i NULL dalle medie; le implementazioni Python applicano la stessa logica trattando come "assenti" i campi `dep_delay`/`arr_delay` vuoti.

**Gestione NULL allineata a SQL (MapReduce 3.1, 3.2, 3.3)**: i mapper emettono stringa vuota per `arr_delay` (e `dep_delay` per 3.2) mancante; i reducer parsano `""` come `None` e usano un contatore separato `arr_count` (incrementato solo quando il valore è presente) come denominatore della media. Questo replica la semantica di `AVG(CASE WHEN cancelled=0 THEN arr_delay END)` di Hive/Spark SQL, che ignora i NULL. Senza questo fix, l'output MapReduce per ABE/9E/mese=1 mostrava `ritardo_medio = 20.99` contro il valore corretto 21.29 di Hive/Spark SQL — discrepanza causata da 1 volo con `arr_delay` NULL trattato erroneamente come 0.0.

L'analisi 3.3 in Spark Core usa `.sortBy + .coalesce(1)` per garantire l'ordinamento globale per `(aeroporto, classifica)` allineato a MapReduce e Spark SQL.

### 6.4 Ordinamento output MapReduce

L'output MapReduce per le analisi 3.1 e 3.2 segue l'ordinamento lessicografico del comando `sort` Unix (es. mesi `1, 10, 11, 12, 2, 3, ...` invece di `1, 2, ..., 12`). I valori dei dati sono identici a Hive/Spark SQL — cambia solo l'ordine delle righe nel file. È una caratteristica nota della pipeline `mapper | sort | reducer` con chiavi stringa.

---

## 7. Riproducibilità

Per replicare i risultati pubblicati:

1. Posizionare `flight_data_2024.csv` in `data/raw/`
2. Eseguire il notebook `pulizia 19.29.49.ipynb`
3. `bash run_all_analyses.sh`
4. `python3 benchmarks/generate_charts.py`
5. Risultati in `results/`, tempi in `benchmarks/benchmarks.csv`, grafici in `benchmarks/charts/`

---

## 8. Risultati e benchmark sintetici

### Tempi di esecuzione al 100% (~6.87M record, locale Mac)

| Analisi | Hive | Spark SQL | Spark Core | MapReduce |
|---------|------|-----------|------------|-----------|
| 3.1     | 12s  | 6s        | —          | 14s       |
| 3.2     | 40s  | 11s       | —          | 21s       |
| 3.3     | —    | 6s        | 6s         | 15s       |

### Scaling (MapReduce, esempio)

| Dataset | 3.1 | 3.2 | 3.3 |
|---------|-----|-----|-----|
| 10%     | 2s  | 2s  | 1s  |
| 50%     | 7s  | 10s | 8s  |
| 100%    | 14s | 21s | 15s |
| 150%    | 19s | 30s | 23s |

MapReduce mostra scaling lineare pulito. Spark SQL e Spark Core appaiono "piatti" su 3.1 e 3.3 perché il startup JVM (~4-5s) domina il tempo di calcolo effettivo (<1s) sui dataset locali. Hive 3.2 è la più lenta (40s) per via di window functions + UNION ALL + collect_list eseguiti su Derby+MapReduce locale.

### Numero di righe output al 100%

- **3.1**: 18.684 righe (combinazioni `carrier × origin × month`)
- **3.2**: 4.040 righe (combinazioni `origin × month`)
- **3.3**: 1.739 righe (combinazioni `origin × carrier`)

### Grafici generati

In `benchmarks/charts/`:
- `scalability_per_analysis.png` — line chart con 3 subplot (uno per analisi), tempo vs % dataset, una linea per tecnologia
- `comparison_100pct.png` — bar chart raggruppato di tutte le tecnologie sull'analisi al 100%
- `heatmap_times.png` — heatmap completa (tecnologia × analisi vs %)

### Coerenza cross-tecnologia (campioni verificati)

- **3.1 ABE/9E/mese=1**: tutte e 3 le tecnologie restituiscono `9E,ABE,71,-28.0,438.0,21.29,0.0,1`
- **3.2 ABE/mese=1**: identico su tutte e 3 (`230,-4.59,-9.83,31,34.32,32.5,30,241.3,234.03,...`)
- **3.3 ABE/9E**: identico su tutte e 3 (`935,10.88,3.93,1.5,-3.45,1`) salvo arrotondamento ±0.01 nella colonna `differenza` per MapReduce
