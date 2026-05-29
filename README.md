# Flight Delay Analysis — Progetto Big Data



Analisi di circa **6.87 milioni di record di voli aerei statunitensi** (anno 2024) tramite quattro tecnologie Big Data: Apache Hive, Spark SQL, Spark Core e MapReduce. Il progetto è eseguito sia in locale che su cluster distribuito AWS EMR, con confronto delle prestazioni su sei scale di dataset.


---

## Indice

1. [Dataset](#dataset)
2. [Tecnologie](#tecnologie)
3. [Struttura del repository](#struttura-del-repository)
4. [Analisi implementate](#analisi-implementate)
5. [Esecuzione in locale](#esecuzione-in-locale)
6. [Esecuzione su cluster AWS EMR](#esecuzione-su-cluster-aws-emr)
7. [Risultati e benchmark](#risultati-e-benchmark)

---

## Dataset


Il dataset pulito al 100% conta **6.872.714 record**. Il notebook `data_preparation.ipynb` genera sei dataset stratificati per il benchmarking:

| Scala | 10% | 25% | 50% | 75% | 100% | 150% |
|---|---|---|---|---|---|---|
| Voli (~) | 687K | 1.7M | 3.4M | 5.1M | 6.87M | 10.3M* |

*150% = campionamento con rimpiazzo.

Le 15 colonne mantenute includono `month`, `op_unique_carrier`, `origin`, `dest`, `dep_delay`, `arr_delay`, `cancelled`, `cancellation_code` (A=Carrier, B=Weather, C=NAS, D=Security) e le 5 cause di ritardo (`carrier_delay`, `weather_delay`, `nas_delay`, `security_delay`, `late_aircraft_delay`).


---

## Tecnologie

| Tecnologia | Versione locale | Versione cluster (EMR 6.15.0) | Analisi |
|---|---|---|---|
| Apache Hadoop (YARN + Streaming) | 3.4.1 | 3.3.6 | 3.1, 3.2, 3.3 |
| Apache Hive | 2.3.9 | 3.1.3 | 3.1, 3.2 |
| Apache Spark SQL | 3.5.8 | 3.5.4 | 3.1, 3.2, 3.3 |
| Apache Spark Core (PySpark) | 3.5.8 | 3.5.4 | 3.3 |
| Python (MapReduce Streaming) | 3.11 | 3.9 (default EMR) | 3.1, 3.2, 3.3 |

---

## Struttura del repository

```
flight-delay-bigdata1/
├── README.md                      # Questa documentazione
├── Secondo progetto.pdf           # Specifica ufficiale del progetto
├── data_preparation.ipynb         # Preprocessing e generazione dei 6 dataset
├── run_all_analyses.sh            # Esecuzione locale di tutti i 54 job
│
├── analysis_31/                   # Analisi 3.1 (hive/ mapreduce/ spark_sql/)
├── analysis_32/                   # Analisi 3.2 (hive/ mapreduce/ spark_sql/)
├── analysis_33/                   # Analisi 3.3 (mapreduce/ spark_core/ spark_sql/)
│
├── benchmarks/                    # Tempi locali: benchmarks.csv + charts/
├── benchmarks_cluster/            # Tempi cluster: benchmarks_cluster.csv + charts_cluster/
├── cluster/                       # Script e guida AWS EMR (upload, run, download)
├── comparisons/                   # Confronto locale vs cluster (notebook + charts/)
│
├── results/                       # Output locale al 100% (full + top10 per tecnologia)
└── results_cluster/               # Output cluster al 100% (struttura identica a results/)
```

Ogni cartella di analisi contiene i sorgenti per tecnologia: file `.sql` (Hive/Spark SQL con `setup_table.sql`) e `.py` (mapper/reducer MapReduce, RDD Spark Core).

---

## Analisi implementate

### Analisi 3.1 — Statistiche per compagnia, aeroporto e mese
Per ogni tripla (compagnia, aeroporto di partenza, mese): numero voli, ritardo min/max/medio di arrivo (voli non cancellati) e tasso di cancellazione.
**Tecnologie**: Hive, Spark SQL, MapReduce · **Output**: 8 colonne, 18.683 righe.

### Analisi 3.2 — Report fasce di ritardo per aeroporto e mese
Per ogni coppia (aeroporto, mese): classificazione dei voli in tre fasce di ritardo in partenza (basso `<15`, medio `15–60`, alto `>60` minuti) con conteggi e medie, più le 3 cause principali di ritardo/cancellazione.
**Tecnologie**: Hive, Spark SQL, MapReduce · **Output**: 12 colonne, 4.039 righe.

### Analisi 3.3 — Ranking compagnie per comportamento anomalo
Per ogni coppia (aeroporto, compagnia): statistiche di ritardo, differenza rispetto alla media complessiva dell'aeroporto e classifica (1 = performance migliore).
**Tecnologie**: Spark SQL, Spark Core (RDD), MapReduce *(Hive non implementato)* · **Output**: 8 colonne, 1.738 righe.


---

## Esecuzione in locale

**Prerequisiti**: Hadoop 3.4.1 (`HADOOP_HOME`), Hive 2.3.9 (`HIVE_HOME`), Spark 3.5.8 (`SPARK_HOME`), Python 3.11 (`python3.11`).

1. Generare i dataset con `data_preparation.ipynb` (output in `data/cleaned/`).
2. Eseguire tutti i 54 job:

```bash
bash run_all_analyses.sh
```

Output: `results/` (CSV al 100%), `benchmarks/benchmarks.csv` (tempi), `benchmarks/charts/` (grafici rigenerati automaticamente).

---

## Esecuzione su cluster AWS EMR

**Configurazione**: `emr-6.15.0`, 3× `m5.xlarge` (1 master + 2 core), regione `us-east-1`, applicazioni Hadoop/Hive/Spark.

Guida completa step-by-step (credenziali AWS Academy, creazione cluster, security group): [`cluster/cluster_setup.md`](cluster/cluster_setup.md).

```bash
export S3_BUCKET=<nome-bucket>

# 1. Carica dataset e codice su S3
bash cluster/upload_to_s3.sh $S3_BUCKET

# 2. Crea il cluster EMR
aws emr create-cluster --name "flight-delay" --release-label emr-6.15.0 \
  --applications Name=Hadoop Name=Hive Name=Spark \
  --instance-type m5.xlarge --instance-count 3 \
  --ec2-attributes KeyName=vockey,SubnetId=<subnet-id> \
  --use-default-roles --log-uri s3://$S3_BUCKET/logs/ --region us-east-1

# 3. Connettiti al master ed esegui i job (~30-40 min)
ssh -i ~/labsuser.pem hadoop@<master-dns>
export S3_BUCKET=<bucket> && bash cluster/run_cluster.sh

# 4. Scarica i risultati e termina il cluster
bash cluster/download_results.sh $S3_BUCKET
aws emr terminate-clusters --cluster-ids <cluster-id>
python3 benchmarks_cluster/generate_charts_cluster.py
```


---

## Risultati e benchmark

I risultati al 100% sono in `results/` (locale) e `results_cluster/` (cluster). La coerenza locale-cluster è verificata con `diff sort -u = 0` su tutti i 9 file di output. Ogni analisi produce un `*_full_results.csv` e un `*_top_10results.csv`.

**Tempi di esecuzione al 100% (~6.87M voli):**

| Analisi | Hive (loc/cls) | Spark SQL (loc/cls) | Spark Core (loc/cls) | MapReduce (loc/cls) |
|---|---|---|---|---|
| 3.1 | 12s / 38s | 5s / 32s | — | 13s / 43s |
| 3.2 | 40s / 58s | 10s / 54s | — | 20s / 52s |
| 3.3 | — | 5s / 34s | 7s / 67s | 15s / 43s |

Su questo workload (~1 GB) l'esecuzione locale è più veloce: l'overhead fisso di YARN (~25-30s) domina sul tempo di calcolo effettivo. I grafici di scalabilità, confronto e heatmap sono in `benchmarks/charts/`, `benchmarks_cluster/charts_cluster/` e `comparisons/charts/`.

---

## Note implementative

Tutte le tecnologie escludono i voli cancellati dal calcolo dei ritardi (`cancelled = 0`) e calcolano il tasso di cancellazione sul totale; i valori NULL sono esclusi dalle medie. L'Analisi 3.3 richiede una normalizzazione a 2 decimali prima dell'ordinamento per garantire un tie-breaking deterministico tra locale e cluster.

