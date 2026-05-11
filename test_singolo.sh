#!/bin/bash

# ==========================================
# SCRIPT DI TEST INTERATTIVO SINGOLO (10%)
# ==========================================

export HADOOP_HOME="/Users/camillamariasantoro/hadoop-3.4.1"
export HIVE_HOME="/Users/camillamariasantoro/apache-hive-2.3.9-bin"
export SPARK_HOME="/Users/camillamariasantoro/spark-3.5.8-bin-hadoop3"
export BASE_DIR="/Users/camillamariasantoro/flight-delay-bigdata1"
export PATH="$HIVE_HOME/bin:$SPARK_HOME/bin:$HADOOP_HOME/bin:$PATH"

# Python 3.11 per PySpark (cloudpickle in 3.5.8 non supporta Python 3.13+)
export PYSPARK_PYTHON="/opt/homebrew/opt/python@3.11/bin/python3.11"
export PYSPARK_DRIVER_PYTHON="$PYSPARK_PYTHON"

cd "$BASE_DIR" || exit 1

export SPARK_LOCAL_IP="127.0.0.1"
export HADOOP_OPTS="$HADOOP_OPTS -Djava.net.preferIPv4Stack=true"
export HADOOP_HEAPSIZE=2048

HIVE_SETTINGS="--hiveconf fs.defaultFS=file:/// --hiveconf hive.metastore.warehouse.dir=file://$BASE_DIR/hive_warehouse --hiveconf hive.exec.scratchdir=file:///tmp/hive_scratch --hiveconf mapreduce.framework.name=local --hiveconf mapreduce.map.memory.mb=2048 --hiveconf mapreduce.reduce.memory.mb=2048"
mkdir -p "$BASE_DIR/hive_warehouse" /tmp/hive_scratch
chmod 1777 /tmp/hive_scratch 2>/dev/null
chmod 1777 "$BASE_DIR/hive_warehouse" 2>/dev/null
FILTRO_PULIZIA="op_unique_carrier|origin|aeroporto_partenza|codice|NULL"

DATASET_CSV="$BASE_DIR/data/cleaned/dataset_10.csv"
LOCAL_DATASET_URI="file://$DATASET_CSV"

# --- MENU INTERATTIVO ---
echo "========================================"
echo "🛠 STRUMENTO DI DEBUG SINGOLO"
echo "========================================"
echo "Scegli la TECNOLOGIA che vuoi testare:"
echo "1) Hive"
echo "2) Spark SQL"
echo "3) MapReduce (Python)"
echo "4) Spark Core (Disponibile solo per Analisi 3.3)"
read -p "Inserisci il numero (1-4): " TECH_SCELTA

if [ "$TECH_SCELTA" != "4" ]; then
    echo ""
    echo "Scegli l'ANALISI che vuoi eseguire:"
    echo "1) Analisi 3.1"
    echo "2) Analisi 3.2"
    echo "3) Analisi 3.3"
    read -p "Inserisci il numero (1-3): " ANALISI_SCELTA
else
    ANALISI_SCELTA="3"
    echo "Hai scelto Spark Core -> Impostato automaticamente su Analisi 3.3"
fi

# --- PREPARAZIONE DATI ---
echo ""
echo ">> Preparazione del database di test (Dataset 10%)..."
rm -rf "$BASE_DIR/tmp_csv_db" && mkdir -p "$BASE_DIR/tmp_csv_db"
cp "$DATASET_CSV" "$BASE_DIR/tmp_csv_db/data.csv"
CSV_DB_PATH="file://$BASE_DIR/tmp_csv_db"

if [ ! -d "$BASE_DIR/metastore_db" ]; then
    "$HIVE_HOME/bin/schematool" -dbType derby -initSchema > /dev/null 2>&1
fi

# Genera file SQL combinati (setup + query) per Hive — una sola sessione Derby
cat "$BASE_DIR/analysis_31/hive/setup_table.sql" \
    "$BASE_DIR/analysis_31/hive/hive_3_1.sql" > /tmp/hive_run_31.sql
cat "$BASE_DIR/analysis_32/hive/setup_table.sql" \
    "$BASE_DIR/analysis_32/hive/hive_3_2.sql" > /tmp/hive_run_32.sql

echo ">> Database pronto! Avvio dell'elaborazione..."
echo "----------------------------------------"

# --- ESECUZIONE DELLA SCELTA ---

# ================= HIVE =================
if [ "$TECH_SCELTA" == "1" ]; then
    if [ "$ANALISI_SCELTA" == "1" ]; then
        "$HIVE_HOME/bin/hive" $HIVE_SETTINGS --hiveconf DATA_PATH="$CSV_DB_PATH" -S -f "/tmp/hive_run_31.sql" 2>>hive_run.log | tr '\t' ',' | grep -vE "$FILTRO_PULIZIA|^OK$|^Time taken" | head -n 10
    elif [ "$ANALISI_SCELTA" == "2" ]; then
        "$HIVE_HOME/bin/hive" $HIVE_SETTINGS --hiveconf DATA_PATH="$CSV_DB_PATH" -S -f "/tmp/hive_run_32.sql" 2>>hive_run.log | tr '\t' ',' | grep -vE "$FILTRO_PULIZIA|^OK$|^Time taken" | head -n 10
    elif [ "$ANALISI_SCELTA" == "3" ]; then
        echo "Errore: Non hai un file hive_3_3.sql. (Hai usato Hive per la 3.3?)"
    fi

# ============== SPARK SQL ===============
elif [ "$TECH_SCELTA" == "2" ]; then
    # Nascondiamo i warning lunghi di Spark in console
    export SPARK_SUBMIT_OPTS="-Dlog4j.configuration=file://$SPARK_HOME/conf/log4j2.properties"
    if [ "$ANALISI_SCELTA" == "1" ]; then
        "$SPARK_HOME/bin/spark-sql" $HIVE_SETTINGS --hiveconf DATA_PATH="$CSV_DB_PATH" -S -f "$BASE_DIR/analysis_31/spark_sql/spark_sql_3_1.sql" 2>/dev/null | tr '\t' ',' | grep -vE "$FILTRO_PULIZIA" | head -n 10
    elif [ "$ANALISI_SCELTA" == "2" ]; then
        "$SPARK_HOME/bin/spark-sql" $HIVE_SETTINGS --hiveconf DATA_PATH="$CSV_DB_PATH" -S -f "$BASE_DIR/analysis_32/spark_sql/spark_sql_3_2.sql" 2>/dev/null | tr '\t' ',' | grep -vE "$FILTRO_PULIZIA" | head -n 10
    elif [ "$ANALISI_SCELTA" == "3" ]; then
        "$SPARK_HOME/bin/spark-sql" $HIVE_SETTINGS --hiveconf DATA_PATH="$CSV_DB_PATH" -S -f "$BASE_DIR/analysis_33/spark_sql/spark_sql_3_3.sql" 2>/dev/null | tr '\t' ',' | grep -vE "$FILTRO_PULIZIA" | head -n 10
    fi

# ============== MAPREDUCE ===============
elif [ "$TECH_SCELTA" == "3" ]; then
    if [ "$ANALISI_SCELTA" == "1" ]; then
        cat "$DATASET_CSV" | python3 "$BASE_DIR/analysis_31/mapreduce/mapper.py" | sort | python3 "$BASE_DIR/analysis_31/mapreduce/reducer.py" 2>/dev/null | head -n 10
    elif [ "$ANALISI_SCELTA" == "2" ]; then
        cat "$DATASET_CSV" | python3 "$BASE_DIR/analysis_32/mapreduce/mapper_3_2.py" | sort | python3 "$BASE_DIR/analysis_32/mapreduce/reducer_3_2.py" 2>/dev/null | head -n 10
    elif [ "$ANALISI_SCELTA" == "3" ]; then
        cat "$DATASET_CSV" | python3 "$BASE_DIR/analysis_33/mapreduce/mapper_3_3.py" | sort | python3 "$BASE_DIR/analysis_33/mapreduce/reducer_3_3.py" 2>/dev/null | head -n 10
    fi

# ============== SPARK CORE ==============
elif [ "$TECH_SCELTA" == "4" ]; then
    rm -rf "$BASE_DIR/temp_debug_spark_core"
    "$SPARK_HOME/bin/spark-submit" "$BASE_DIR/analysis_33/spark_core/spark_core_3_3_.py" "$LOCAL_DATASET_URI" "file://$BASE_DIR/temp_debug_spark_core" > /dev/null 2>&1
    cat "$BASE_DIR"/temp_debug_spark_core/part-* 2>/dev/null | grep -vE "$FILTRO_PULIZIA" | head -n 10
    rm -rf "$BASE_DIR/temp_debug_spark_core"

else
    echo "❌ Scelta non valida!"
fi

echo "----------------------------------------"
echo "✅ Test concluso."