#!/bin/bash

# --- 1. CONFIGURAZIONE PERCORSI ---
export HADOOP_HOME="/Users/camillamariasantoro/hadoop-3.4.1"
export HIVE_HOME="/Users/camillamariasantoro/apache-hive-2.3.9-bin"
export SPARK_HOME="/Users/camillamariasantoro/spark-3.5.8-bin-hadoop3"
export BASE_DIR="/Users/camillamariasantoro/flight-delay-bigdata1"
export PATH="$HIVE_HOME/bin:$SPARK_HOME/bin:$HADOOP_HOME/bin:$PATH"

cd "$BASE_DIR" || exit 1

# --- 2. FIX MAC & MEMORIA ---
export SPARK_LOCAL_IP="127.0.0.1"
export HADOOP_OPTS="$HADOOP_OPTS -Djava.net.preferIPv4Stack=true"
export HADOOP_HEAPSIZE=2048

# --- 3. CONFIGURAZIONI HIVE (Rimossa l'intestazione automatica per non averla doppia) ---
HIVE_SETTINGS="--hiveconf fs.defaultFS=file:/// --hiveconf hive.metastore.warehouse.dir=file://$BASE_DIR/hive_warehouse --hiveconf hive.exec.scratchdir=file:///tmp/hive_scratch --hiveconf hive.exec.parallel=true --hiveconf hive.vectorized.execution.enabled=false --hiveconf mapreduce.framework.name=local --hiveconf mapreduce.map.memory.mb=2048 --hiveconf mapreduce.reduce.memory.mb=2048"

# --- 4. PREPARAZIONE STRUTTURA ---
mkdir -p results/analysis_31/{hive,spark_sql,mapreduce}
mkdir -p results/analysisis_32/{hive,spark_sql,mapreduce}
mkdir -p results/analysisis_33/{spark_core,spark_sql,mapreduce}
mkdir -p benchmarks
mkdir -p "$BASE_DIR/hive_warehouse" /tmp/hive_scratch
chmod 1777 /tmp/hive_scratch 2>/dev/null
chmod 1777 "$BASE_DIR/hive_warehouse" 2>/dev/null

echo "Percentuale,Analisi,Tecnologia,Tempo_Secondi" > benchmarks/benchmarks.csv
PERCENTUALI=(10 25 50 75 100 150)

# INTESTAZIONI MANUALI PER TUTTI I FILE
HEADER_31="codice,aeroporto_partenza,numero_voli,ritardo_minimo,ritardo_massimo,ritardo_medio,tasso_cancellazione,mese"
HEADER_32="aeroporto_partenza,mese,numero_ritardi_basso,dep_avg_basso,arr_avg_basso,numero_ritardi_medio,dep_avg_medio,arr_avg_medio,numero_ritardo_alto,dep_avg_alto,arr_avg_alto,cause_maggiori"
HEADER_33="aeroporto_partenza,compagnia,numero_voli,ritardo_medio_partenza,ritardo_medio_arrivo,tasso_cancellazione,differenza,classifica"
# Filtro per pulire le righe in cui Spark legge l'intestazione come se fosse un volo
FILTRO_PULIZIA="^OK$|^Time taken|op_unique_carrier|origin|aeroporto_partenza|codice"

if [ ! -d "$BASE_DIR/metastore_db" ]; then
    "$HIVE_HOME/bin/schematool" -dbType derby -initSchema > /dev/null 2>&1
fi

esegui_e_cronometra() {
    local P=$1
    local ANALISI=$2
    local TECH=$3
    local CMD_BENCH=$4
    local CMD_SAVE=$5
    
    echo "-> Eseguendo $ANALISI con $TECH ($P%)..."
    START=$(date +%s)
    
    if [ "$P" -eq 100 ]; then
        eval "$CMD_SAVE" 2>>hive_run.log
    else
        eval "$CMD_BENCH" > /dev/null 2>&1
    fi
    
    END=$(date +%s)
    echo "$P%,$ANALISI,$TECH,$((END - START))" >> benchmarks/benchmarks.csv
}

# --- 5. LOOP PRINCIPALE ---
for P in "${PERCENTUALI[@]}"
do
    echo "========================================"
    echo "=== Elaborazione Dataset $P% ==="
    echo "========================================"
    
    DATASET_CSV="$BASE_DIR/data/cleaned/dataset_$P.csv"
    LOCAL_DATASET_URI="file://$DATASET_CSV"
    
    rm -rf "$BASE_DIR/tmp_csv_db" && mkdir -p "$BASE_DIR/tmp_csv_db"
    cp "$DATASET_CSV" "$BASE_DIR/tmp_csv_db/data.csv"
    CSV_DB_PATH="file://$BASE_DIR/tmp_csv_db"

    # Genera file SQL combinati (setup + query) per Hive — una sola sessione Derby per evitare lock
    cat "$BASE_DIR/analysisis_31/hive/setup_table.sql" \
        "$BASE_DIR/analysisis_31/hive/hive_3_1.sql" > /tmp/hive_run_31.sql
    cat "$BASE_DIR/analysisis_32/hive/setup_table.sql" \
        "$BASE_DIR/analysisis_32/hive/hive_3_2.sql" > /tmp/hive_run_32.sql

    # --- ANALISI 3.1 ---
    CMD_H31="\"$HIVE_HOME/bin/hive\" $HIVE_SETTINGS --hiveconf DATA_PATH='$CSV_DB_PATH' -S -f '/tmp/hive_run_31.sql'"
    esegui_e_cronometra "$P" "3.1" "Hive" "$CMD_H31" "echo '$HEADER_31' > temp_hive_31.csv && $CMD_H31 | tr '\t' ',' | grep -vE '$FILTRO_PULIZIA' >> temp_hive_31.csv"

    CMD_S31="\"$SPARK_HOME/bin/spark-sql\" $HIVE_SETTINGS --hiveconf DATA_PATH='$CSV_DB_PATH' -S -f '$BASE_DIR/analysisis_31/spark_sql/spark_sql_3_1.sql'"
    esegui_e_cronometra "$P" "3.1" "Spark_SQL" "$CMD_S31" "echo '$HEADER_31' > temp_spark_sql_31.csv && $CMD_S31 | tr '\t' ',' | grep -vE '$FILTRO_PULIZIA' >> temp_spark_sql_31.csv"

    CMD_M31="cat '$DATASET_CSV' | python3 '$BASE_DIR/analysisis_31/mapreduce/mapper.py' | sort | python3 '$BASE_DIR/analysisis_31/mapreduce/reducer.py'"
    esegui_e_cronometra "$P" "3.1" "MapReduce" "$CMD_M31" "echo '$HEADER_31' > temp_mr_31.csv && $CMD_M31 >> temp_mr_31.csv"

    # --- ANALISI 3.2 ---
    CMD_H32="\"$HIVE_HOME/bin/hive\" $HIVE_SETTINGS --hiveconf DATA_PATH='$CSV_DB_PATH' -S -f '/tmp/hive_run_32.sql'"
    esegui_e_cronometra "$P" "3.2" "Hive" "$CMD_H32" "echo '$HEADER_32' > temp_hive_32.csv && $CMD_H32 | tr '\t' ',' | grep -vE '$FILTRO_PULIZIA' >> temp_hive_32.csv"

    CMD_S32="\"$SPARK_HOME/bin/spark-sql\" $HIVE_SETTINGS --hiveconf DATA_PATH='$CSV_DB_PATH' -S -f '$BASE_DIR/analysisis_32/spark_sql/spark_sql_3_2.sql'"
    esegui_e_cronometra "$P" "3.2" "Spark_SQL" "$CMD_S32" "echo '$HEADER_32' > temp_spark_sql_32.csv && $CMD_S32 | tr '\t' ',' | grep -vE '$FILTRO_PULIZIA' >> temp_spark_sql_32.csv"

    CMD_M32="cat '$DATASET_CSV' | python3 '$BASE_DIR/analysisis_32/mapreduce/mapper_3_2.py' | sort | python3 '$BASE_DIR/analysisis_32/mapreduce/reducer_3_2.py'"
    esegui_e_cronometra "$P" "3.2" "MapReduce" "$CMD_M32" "echo '$HEADER_32' > temp_mr_32.csv && $CMD_M32 >> temp_mr_32.csv"

    # --- ANALISI 3.3 ---
    CMD_C33="rm -rf '$BASE_DIR/temp_spark_core_out' && \"$SPARK_HOME/bin/spark-submit\" '$BASE_DIR/analysisis_33/spark_core/spark_core_3_3_.py' '$LOCAL_DATASET_URI' 'file://$BASE_DIR/temp_spark_core_out'"
    esegui_e_cronometra "$P" "3.3" "Spark_Core" "$CMD_C33" "$CMD_C33 && echo '$HEADER_33' > temp_spark_core_33.csv && cat '$BASE_DIR'/temp_spark_core_out/part-* | grep -vE '$FILTRO_PULIZIA' >> temp_spark_core_33.csv"

    CMD_S33="\"$SPARK_HOME/bin/spark-sql\" $HIVE_SETTINGS --hiveconf DATA_PATH='$CSV_DB_PATH' -S -f '$BASE_DIR/analysisis_33/spark_sql/spark_sql_3_3.sql'"
    esegui_e_cronometra "$P" "3.3" "Spark_SQL" "$CMD_S33" "echo '$HEADER_33' > temp_spark_sql_33.csv && $CMD_S33 | tr '\t' ',' | grep -vE '$FILTRO_PULIZIA' >> temp_spark_sql_33.csv"

    CMD_M33="cat '$DATASET_CSV' | python3 '$BASE_DIR/analysisis_33/mapreduce/mapper_3_3.py' | sort | python3 '$BASE_DIR/analysisis_33/mapreduce/reducer_3_3.py'"
    esegui_e_cronometra "$P" "3.3" "MapReduce" "$CMD_M33" "echo '$HEADER_33' > temp_mr_33.csv && $CMD_M33 >> temp_mr_33.csv"

    # --- SALVATAGGIO DEFINITIVO (SOLO AL 100%) ---
    if [ "$P" -eq 100 ]; then
        echo "=> Salvataggio dei risultati 100% in /results..."
        
        cp temp_hive_31.csv results/analysis_31/hive/hive_full_results.csv
        head -n 11 temp_hive_31.csv > results/analysis_31/hive/hive_top_10results.csv
        
        cp temp_spark_sql_31.csv results/analysis_31/spark_sql/spark_sql_full_results.csv
        head -n 11 temp_spark_sql_31.csv > results/analysis_31/spark_sql/spark_sql_top_10results.csv
        
        cp temp_mr_31.csv results/analysis_31/mapreduce/mapreduce_full_results.csv
        head -n 11 temp_mr_31.csv > results/analysis_31/mapreduce/mapreduce_top_10results.csv

        cp temp_hive_32.csv results/analysisis_32/hive/hive_full_results.csv
        head -n 11 temp_hive_32.csv > results/analysisis_32/hive/hive_top_10results.csv
        
        cp temp_spark_sql_32.csv results/analysisis_32/spark_sql/spark_sql_full_results.csv
        head -n 11 temp_spark_sql_32.csv > results/analysisis_32/spark_sql/spark_sql_top_10results.csv
        
        cp temp_mr_32.csv results/analysisis_32/mapreduce/mapreduce_full_results.csv
        head -n 11 temp_mr_32.csv > results/analysisis_32/mapreduce/mapreduce_top_10results.csv

        cp temp_spark_core_33.csv results/analysisis_33/spark_core/spark_core_full_results.csv
        head -n 11 temp_spark_core_33.csv > results/analysisis_33/spark_core/spark_core_top_10results.csv
        
        cp temp_spark_sql_33.csv results/analysisis_33/spark_sql/spark_sql_full_results.csv
        head -n 11 temp_spark_sql_33.csv > results/analysisis_33/spark_sql/spark_sql_top_10results.csv
        
        cp temp_mr_33.csv results/analysisis_33/mapreduce/mapreduce_full_results.csv
        head -n 11 temp_mr_33.csv > results/analysisis_33/mapreduce/mapreduce_top_10results.csv
    fi
    
    # Pulizia a fine loop
    rm -rf temp_spark_core_out temp_*.csv tmp_csv_db /tmp/hive_run_31.sql /tmp/hive_run_32.sql
done

echo "✅ OPERAZIONE COMPLETATA! Risultati CSV salvati solo per il 100%."