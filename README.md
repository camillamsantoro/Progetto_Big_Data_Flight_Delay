# Flight Delay Analysis - Big Data Project

## Progetto di Big Data
Questo progetto analizza i ritardi dei voli utilizzando diverse tecnologie di processamento dati: **Hive**, **Spark (Core e SQL)** e **MapReduce**.

## Struttura del Progetto

La struttura è organizzata per separare le diverse analisi e i relativi risultati:

- `analysisis_31/`: Prima analisi (es. ritardi medi per aeroporto)
  - `hive/`, `spark_sql/`, `mapreduce/`
- `analysisis_32/`: Seconda analisi (es. rotte più trafficate)
  - `hive/`, `spark_sql/`, `mapreduce/`
- `analysisis_33/`: Terza analisi (es. andamento temporale dei ritardi)
  - `spark_core/`, `spark_sql/`, `mapreduce/`
- `data/`: Contiene i dataset
  - `raw/`: Dati grezzi originali
  - `cleaned/`: Dati pre-processati e puliti
  - `subsets/`: Campioni del dataset per test (5%, 10%, etc.)
- `results/`: Risultati delle analisi in formato CSV
- `benchmarks/`: Confronto delle performance tra le tecnologie
  - `charts/`: Grafici comparativi

## Roadmap e Operazioni

### 1. Inizializzazione e Pulizia Dati
- Caricamento dei dati in `data/raw/`.
- Script di cleaning per gestire valori nulli e tipi di dato.
- Creazione di subset per lo sviluppo rapido.

### 2. Implementazione Analisi 31
- Script Hive, Spark SQL e MapReduce.
- Validazione dei risultati tra le tre tecnologie.

### 3. Implementazione Analisi 32
- Script Hive, Spark SQL e MapReduce.
- Estrazione dei top 10 risultati.

### 4. Implementazione Analisi 33
- Focus su Spark Core e Spark SQL.
- Analisi dei trend.

### 5. Benchmarking
- Misurazione dei tempi di esecuzione per ogni tecnologia e subset.
- Generazione grafici in `benchmarks/charts/`.

---
*Nota: Tutte le operazioni verranno documentate in questo file passo dopo passo.*
