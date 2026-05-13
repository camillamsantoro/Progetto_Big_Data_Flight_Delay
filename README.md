# Flight Delay Analysis — Progetto Big Data

Progetto universitario per il corso di **Big Data**, Prof. R. Torlone, Università Roma Tre.

Analisi di circa **6.87 milioni di record di voli aerei statunitensi** (anno 2024) tramite quattro tecnologie Big Data: Apache Hive, Spark SQL, Spark Core e MapReduce. Il progetto è eseguito sia in locale che su cluster distribuito AWS EMR, con confronto delle prestazioni su sei scale di dataset.

---

## Indice

1. [Dataset](#dataset)
2. [Tecnologie](#tecnologie)
3. [Struttura del repository](#struttura-del-repository)
4. [Analisi implementate](#analisi-implementate)
5. [Esecuzione in locale](#esecuzione-in-locale)
6. [Esecuzione su cluster AWS EMR](#esecuzione-su-cluster-aws-emr)
7. [Risultati](#risultati)
8. [Benchmark e scalabilità](#benchmark-e-scalabilità)
9. [Note implementative](#note-implementative)

---

## Dataset

**Sorgente**: Bureau of Transportation Statistics — On-Time Performance 2024

Il dataset al 100% conta circa 6.87 milioni di record. Il notebook `data_preparation.ipynb` genera sei dataset stratificati per il benchmarking:

| Scala | Dimensione approssimativa |
|---|---|
| 10% | ~687K voli |
| 25% | ~1.7M voli |
| 50% | ~3.4M voli |
| 75% | ~5.1M voli |
| 100% | ~6.87M voli |
| 150% | ~10.3M voli (campionamento con rimpiazzo) |

**Colonne principali utilizzate nelle analisi:**

| Campo | Descrizione |
|---|---|
| `month` | Mese del volo (1–12) |
| `op_unique_carrier` | Codice IATA della compagnia aerea |
| `origin` | Codice aeroporto di partenza |
| `dest` | Codice aeroporto di destinazione |
| `dep_delay` | Ritardo in partenza (minuti; negativo = anticipo) |
| `arr_delay` | Ritardo in arrivo (minuti) |
| `cancelled` | 1 se il volo è stato cancellato, 0 altrimenti |
| `cancellation_code` | Causa cancellazione (A=Carrier, B=Weather, C=NAS, D=Security) |
| `carrier_delay` | Minuti di ritardo imputabili alla compagnia |
| `weather_delay` | Minuti di ritardo per condizioni meteo |
| `nas_delay` | Minuti di ritardo per sistema NAS |
| `security_delay` | Minuti di ritardo per sicurezza |
| `late_aircraft_delay` | Minuti di ritardo per aeromobile in ritardo |

I file `data/cleaned/dataset_*.csv` sono esclusi dal repository (`.gitignore`).

---

## Tecnologie

| Tecnologia | Versione locale | Versione cluster (EMR 6.15.0) | Analisi |
|---|---|---|---|
| Apache Hadoop (YARN + Streaming) | 3.4.1 | Hadoop 3.3.6 | 3.1, 3.2, 3.3 |
| Apache Hive | 2.3.9 | Hive 3.1.3 | 3.1, 3.2 |
| Apache Spark SQL | 3.5.8 | Spark 3.5.4 | 3.1, 3.2, 3.3 |
| Apache Spark Core (PySpark) | 3.5.8 | Spark 3.5.4 | 3.3 |
| Python (MapReduce Streaming) | 3.11 | 3.9 (default EMR) | 3.1, 3.2, 3.3 |

---

## Struttura del repository

```
flight-delay-bigdata1/
├── README.md                          # Questa documentazione
├── Secondo progetto.pdf               # Specifica ufficiale del progetto
├── data_preparation.ipynb             # Preprocessing e generazione dei 6 dataset
├── run_all_analyses.sh                # Esecuzione locale di tutti i 54 job
├── test_singolo.sh                    # Utilità per test di un singolo job
│
├── analysis_31/                       # Analisi 3.1 — Statistiche per compagnia/aeroporto/mese
│   ├── hive/
│   │   ├── setup_table.sql            # Creazione tabella Hive
│   │   └── hive_3_1.sql               # Query di analisi
│   ├── mapreduce/
│   │   ├── mapper.py                  # Mapper Hadoop Streaming
│   │   └── reducer.py                 # Reducer Hadoop Streaming
│   └── spark_sql/
│       ├── setup_table.sql            # Creazione tabella Spark SQL
│       └── spark_sql_3_1.sql          # Query di analisi
│
├── analysis_32/                       # Analisi 3.2 — Report fasce di ritardo per aeroporto/mese
│   ├── hive/
│   │   ├── setup_table.sql
│   │   └── hive_3_2.sql
│   ├── mapreduce/
│   │   ├── mapper_3_2.py
│   │   └── reducer_3_2.py
│   └── spark_sql/
│       ├── setup_table.sql
│       └── spark_sql_3_2.sql
│
├── analysis_33/                       # Analisi 3.3 — Ranking compagnia-aeroporto per anomalia
│   ├── mapreduce/
│   │   ├── mapper_3_3.py
│   │   └── reducer_3_3.py
│   ├── spark_core/
│   │   └── spark_core_3_3_.py         # Implementazione con Spark Core (RDD)
│   └── spark_sql/
│       ├── setup_table.sql
│       └── spark_sql_3_3.sql
│
├── benchmarks/                        # Benchmark esecuzione locale
│   ├── benchmarks.csv                 # 54 misure: 6 scale × 9 job (secondi)
│   ├── generate_charts.py             # Script generazione grafici
│   └── charts/
│       ├── scalability_per_analysis.png
│       ├── comparison_100pct.png
│       └── heatmap_times.png
│
├── benchmarks_cluster/                # Benchmark esecuzione cluster
│   ├── benchmarks_cluster.csv
│   ├── generate_charts_cluster.py
│   └── charts_cluster/
│       ├── scalability_per_analysis.png
│       ├── comparison_100pct.png
│       └── heatmap_times.png
│
├── cluster/                           # Script e guida per AWS EMR
│   ├── cluster_setup.md               # Guida step-by-step AWS Academy
│   ├── upload_to_s3.sh                # Caricamento dati e codice su S3
│   ├── run_cluster.sh                 # Esecuzione 54 job su YARN
│   └── download_results.sh            # Download risultati da S3
│
├── comparisons/                       # Confronto locale vs cluster
│   ├── confronto_locale_cluster.ipynb
│   └── charts/                        # Grafici comparativi (4 PNG)
│
├── results/                           # Output locale al 100% del dataset
│   ├── analysis_31/
│   │   ├── hive/{hive_full_results.csv, hive_top_10results.csv}
│   │   ├── mapreduce/{mapreduce_full_results.csv, mapreduce_top_10results.csv}
│   │   └── spark_sql/{spark_sql_full_results.csv, spark_sql_top_10results.csv}
│   ├── analysis_32/
│   │   ├── hive/{...}
│   │   ├── mapreduce/{...}
│   │   └── spark_sql/{...}
│   └── analysis_33/
│       ├── mapreduce/{...}
│       ├── spark_core/{...}
│       └── spark_sql/{...}
│
└── results_cluster/                   # Output cluster al 100% (struttura identica a results/)
```

---

## Analisi implementate

### Analisi 3.1 — Statistiche per compagnia aerea, aeroporto e mese

**Obiettivo**: per ogni tripla (compagnia, aeroporto di partenza, mese) calcolare statistiche aggregate sui ritardi e sulle cancellazioni.

**Output** (colonne del CSV):

| Campo | Descrizione |
|---|---|
| `codice` | Codice IATA della compagnia |
| `aeroporto_partenza` | Codice aeroporto di partenza |
| `numero_voli` | Totale voli operati |
| `ritardo_minimo` | Ritardo minimo di arrivo tra i voli non cancellati (minuti) |
| `ritardo_massimo` | Ritardo massimo di arrivo |
| `ritardo_medio` | Media del ritardo di arrivo sui voli non cancellati |
| `tasso_cancellazione` | Percentuale di voli cancellati sul totale |
| `mese` | Mese di riferimento (1–12) |

**Tecnologie**: Hive, Spark SQL, MapReduce  
**Righe risultato (100% dataset)**: 18.683 + header

---

### Analisi 3.2 — Report fasce di ritardo per aeroporto e mese

**Obiettivo**: per ogni coppia (aeroporto di partenza, mese) classificare i voli ritardati (non cancellati) in tre fasce e identificare le tre cause principali di ritardo o cancellazione.

**Fasce di ritardo in partenza:**
- **Basso**: `dep_delay < 15` minuti
- **Medio**: `15 ≤ dep_delay ≤ 60` minuti
- **Alto**: `dep_delay > 60` minuti

**Output** (colonne del CSV):

| Campo | Descrizione |
|---|---|
| `aeroporto_partenza` | Codice aeroporto |
| `mese` | Mese (1–12) |
| `numero_ritardi_basso` | Voli in fascia bassa |
| `dep_avg_basso` | Ritardo medio partenza fascia bassa |
| `arr_avg_basso` | Ritardo medio arrivo fascia bassa |
| `numero_ritardi_medio` | Voli in fascia media |
| `dep_avg_medio` | Ritardo medio partenza fascia media |
| `arr_avg_medio` | Ritardo medio arrivo fascia media |
| `numero_ritardo_alto` | Voli in fascia alta |
| `dep_avg_alto` | Ritardo medio partenza fascia alta |
| `arr_avg_alto` | Ritardo medio arrivo fascia alta |
| `cause_maggiori` | Lista delle 3 cause principali (carrier, weather, NAS, security, late aircraft, cancellation) |

**Tecnologie**: Hive, Spark SQL, MapReduce  
**Righe risultato (100% dataset)**: 4.039 + header

---

### Analisi 3.3 — Ranking compagnie per comportamento anomalo per aeroporto

**Obiettivo**: per ogni coppia (aeroporto di partenza, compagnia aerea) calcolare le statistiche di ritardo e la differenza rispetto alla media complessiva dell'aeroporto, assegnando una classifica da 1 (performance migliore) a N (peggiore).

**Output** (colonne del CSV):

| Campo | Descrizione |
|---|---|
| `aeroporto_partenza` | Codice aeroporto |
| `compagnia` | Codice IATA della compagnia |
| `numero_voli` | Totale voli operati da quella compagnia in quell'aeroporto |
| `ritardo_medio_partenza` | Media del ritardo di partenza (voli non cancellati) |
| `ritardo_medio_arrivo` | Media del ritardo di arrivo (voli non cancellati) |
| `tasso_cancellazione` | Percentuale di voli cancellati |
| `differenza` | `ritardo_medio_partenza` compagnia − media complessiva aeroporto |
| `classifica` | Posizione nel ranking dell'aeroporto (1 = minor ritardo) |

**Tecnologie**: Spark SQL, Spark Core (PySpark RDD), MapReduce  
*(Hive non implementato per questa analisi)*  
**Righe risultato (100% dataset)**: 1.738 + header

---

## Esecuzione in locale

**Prerequisiti:**
- Apache Hadoop 3.4.1 con `HADOOP_HOME` configurato
- Apache Hive 2.3.9 con `HIVE_HOME` configurato
- Apache Spark 3.5.8 con `SPARK_HOME` configurato
- Python 3.11 disponibile come `python3.11`

**Passaggi:**

1. Generare i dataset tramite il notebook `data_preparation.ipynb` (output in `data/cleaned/`)
2. Eseguire tutti i 54 job:

```bash
bash run_all_analyses.sh
```

Output salvato in:
- `results/` — CSV dei risultati al 100% per ciascuna tecnologia
- `benchmarks/benchmarks.csv` — tempi di esecuzione per ogni job
- `benchmarks/charts/` — grafici di scalabilità (rigenerati automaticamente)

---

## Esecuzione su cluster AWS EMR

**Configurazione cluster:**
- Release: `emr-6.15.0`
- Istanze: 3× `m5.xlarge` (1 master + 2 core node), regione `us-east-1`
- Applicazioni: Hadoop, Hive, Spark

Per la guida completa step-by-step (credenziali AWS Academy, creazione cluster, configurazione security group) consultare [`cluster/cluster_setup.md`](cluster/cluster_setup.md).

**Sequenza comandi:**

```bash
# 1. Impostare la variabile del bucket S3
export S3_BUCKET=<nome-bucket>

# 2. Caricare dataset e codice su S3
bash cluster/upload_to_s3.sh $S3_BUCKET

# 3. Creare il cluster EMR
aws emr create-cluster \
  --name "flight-delay" \
  --release-label emr-6.15.0 \
  --applications Name=Hadoop Name=Hive Name=Spark \
  --instance-type m5.xlarge \
  --instance-count 3 \
  --ec2-attributes KeyName=vockey,SubnetId=<subnet-id> \
  --use-default-roles \
  --log-uri s3://$S3_BUCKET/logs/ \
  --region us-east-1

# 4. Attendere che il cluster sia pronto (~7 min)
aws emr wait cluster-running --cluster-id <cluster-id>

# 5. Connettersi al master e avviare i job (~30-40 min)
ssh -i ~/labsuser.pem hadoop@<master-dns>
export S3_BUCKET=<bucket> && bash cluster/run_cluster.sh

# 6. Tornare in locale, scaricare i risultati e terminare il cluster
bash cluster/download_results.sh $S3_BUCKET
aws emr terminate-clusters --cluster-ids <cluster-id>

# 7. Rigenerare i grafici del cluster
python3 benchmarks_cluster/generate_charts_cluster.py
```

> **Importante**: terminare sempre il cluster al termine dell'esecuzione per evitare consumo di crediti AWS Academy.

---

## Risultati

I risultati del 100% del dataset sono salvati in `results/` (locale) e `results_cluster/` (cluster). La coerenza è verificata tramite `diff sort -u = 0` su tutti i 9 file di output.

| Analisi | Tecnologie | Righe (senza header) |
|---|---|---|
| 3.1 | Hive, Spark SQL, MapReduce | 18.683 |
| 3.2 | Hive, Spark SQL, MapReduce | 4.039 |
| 3.3 | Spark SQL, Spark Core, MapReduce | 1.738 |

Ogni analisi include un file `*_full_results.csv` (risultato completo) e `*_top_10results.csv` (prime 10 righe per verifica rapida).

---

## Benchmark e scalabilità

I tempi di esecuzione sono misurati su 6 scale di dataset per ciascuna delle 9 combinazioni analisi-tecnologia (54 misure totali). I CSV completi si trovano in `benchmarks/benchmarks.csv` e `benchmarks_cluster/benchmarks_cluster.csv`.

**Tempi al 100% del dataset (~6.87M voli):**

**Locale** (MacBook Pro, Apple Silicon):

| Analisi | Hive | Spark SQL | Spark Core | MapReduce |
|---|---|---|---|---|
| 3.1 | 12s | 5s | n/a | 13s |
| 3.2 | 40s | 10s | n/a | 20s |
| 3.3 | n/a | 5s | 7s | 15s |

**Cluster EMR** (3× m5.xlarge — overhead fisso YARN ~25-30s):

| Analisi | Hive | Spark SQL | Spark Core | MapReduce |
|---|---|---|---|---|
| 3.1 | 38s | 32s | n/a | 43s |
| 3.2 | 58s | 54s | n/a | 52s |
| 3.3 | n/a | 34s | 67s | 43s |

I grafici di scalabilità, confronto al 100% e heatmap sono disponibili in `benchmarks/charts/` (locale) e `benchmarks_cluster/charts_cluster/` (cluster).

Il notebook `comparisons/confronto_locale_cluster.ipynb` analizza in dettaglio il confronto tra le due modalità.

---

## Note implementative

**Filtraggio voli cancellati**  
Il calcolo di tutti i ritardi esclude i voli cancellati (`cancelled = 0`). Il tasso di cancellazione è calcolato sul totale dei voli (cancellati inclusi). Questo comportamento è uniforme tra Hive, Spark SQL, Spark Core e MapReduce.

**Gestione valori NULL**  
I campi `dep_delay` e `arr_delay` sono NULL per i voli cancellati. In Python il trattamento è esplicito:
```python
dep_delay = float(dep_str) if dep_str else None
```
Le medie escludono i valori NULL, allineandosi al comportamento di `AVG()` in SQL.

**Determinismo dell'Analisi 3.3**  
In un contesto distribuito, l'ordine di accumulazione dei valori floating-point varia tra run diversi, rendendo non deterministico il tie-breaking quando più compagnie hanno lo stesso ritardo medio. Il problema è risolto normalizzando il valore a 2 decimali prima del confronto:
- **Spark SQL**: `CAST(ROUND(avg(...), 2) AS DECIMAL(10,2))` — la precisione fissa elimina le ambiguità nel `row_number()`
- **Spark Core e MapReduce**: `float(f"{dep_avg:.2f}")` come chiave di ordinamento — la conversione attraverso stringa garantisce che valori identici al secondo decimale producano la stessa chiave

Il tie-breaking secondario è sempre alfabetico per codice compagnia.

**Differenze cross-tecnologia (attese)**  
Tra tecnologie diverse per la stessa analisi si osservano differenze minori intrinseche ai linguaggi:
- Hive tronca gli zeri finali (es. `-4.8` invece di `-4.80`); MapReduce e Spark SQL usano sempre 2 decimali fissi
- MapReduce ordina i mesi come stringhe (`1, 10, 11, 12, 2, ...`); Hive e Spark SQL li ordinano numericamente
- Circa 30 righe su 18.683 (analisi 3.1) presentano differenze di ±0.01 tra MapReduce e Hive/Spark SQL, dovute alla non-associatività dell'aritmetica in virgola mobile — non costituiscono errori logici

All'interno della stessa tecnologia, il confronto `diff sort -u` tra locale e cluster restituisce **0 per tutti i 9 job**.
