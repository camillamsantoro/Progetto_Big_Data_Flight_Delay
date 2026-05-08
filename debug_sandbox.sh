#!/bin/bash

# ==========================================
# SCRIPT DI DEBUG RAPIDO (Dataset 10%)
# ==========================================

export HADOOP_HOME="/Users/camillamariasantoro/hadoop-3.4.1"
export HIVE_HOME="/Users/camillamariasantoro/apache-hive-2.3.9-bin"
export SPARK_HOME="/Users/camillamariasantoro/spark-3.5.8-bin-hadoop3"
export BASE_DIR="/Users/camillamariasantoro/flight-delay-bigdata1"
export PATH="$HIVE_HOME/bin:$SPARK_HOME/bin:$HADOOP_HOME/bin:$PATH"

cd "$BASE_DIR" || exit 1

export SPARK_LOCAL_IP="127.0.0.1"
export HADOOP_OPTS="$HADOOP_OPTS -Djava.net.preferIPv4Stack=true"
export HADOOP_HEAPSIZE=2048

HIVE_SETTINGS="--hiveconf mapreduce.framework.name=local --hiveconf mapreduce.map.memory.mb=2048 --hiveconf mapreduce.reduce.memory.mb=2048"

DATASET_CSV="$BASE_DIR/data/cleaned/dataset_10.csv"
LOCAL_DATASET_URI="file://$DATASET_CSV"

echo "========================================"
echo "🛠 PREPARAZIONE AMBIENTE DI TEST..."
echo "========================================"
rm -rf "$BASE_DIR/tmp_csv_db" && mkdir -p "$BASE_DIR/tmp_csv_db"
cp "$DATASET_CSV" "$BASE_DIR/tmp_csv_db/data.csv"
CSV_DB_PATH="file://$BASE_DIR/tmp_csv_db"

if [ ! -d "$BASE_DIR/metastore_db" ]; then
    "$HIVE_HOME/bin/schematool" -dbType derby -initSchema > /dev/null 2>&1
fi

# Creiamo la tabella per Hive e Spark SQL
"$HIVE_HOME/bin/hive" $HIVE_SETTINGS --hiveconf DATA_PATH="$CSV_DB_PATH" -f "$BASE_DIR/analysisis_31/hive/setup_table.sql" > /dev/null 2>&1


# ==========================================
# 1. TEST HIVE (Testiamo la 3.1)
# ==========================================
echo ""
echo "🔴 1. TEST HIVE (Analisi 3.1) 🔴"
echo "Esecuzione in corso... (Mostro le prime 5 righe di output)"
"$HIVE_HOME/bin/hive" $HIVE_SETTINGS --hiveconf DATA_PATH="$CSV_DB_PATH" -S -f "$BASE_DIR/analysisis_31/hive/hive_3_1.sql" | tr '\t' ',' | grep -vE 'codice|aeroporto' | head -n 5


# ==========================================
# 2. TEST SPARK SQL (Testiamo la 3.2)
# ==========================================
echo ""
echo "🔵 2. TEST SPARK SQL (Analisi 3.2) 🔵"
echo "Esecuzione in corso... (Mostro le prime 5 righe di output)"
"$SPARK_HOME/bin/spark-sql" $HIVE_SETTINGS --hiveconf DATA_PATH="$CSV_DB_PATH" -S -f "$BASE_DIR/analysisis_32/spark_sql/spark_sql_3_2.sql" | tr '\t' ',' | grep -vE 'origin|NULL' | head -n 5


# ==========================================
# 3. TEST MAPREDUCE PYTHON (Testiamo la 3.1)
# ==========================================
echo ""
echo "🟢 3. TEST MAPREDUCE PYTHON (Analisi 3.1) 🟢"
echo "Esecuzione in corso... (Mostro le prime 5 righe di output)"
cat "$DATASET_CSV" | python3 "$BASE_DIR/analysisis_31/mapreduce/mapper.py" | sort | python3 "$BASE_DIR/analysisis_31/mapreduce/reducer.py" | head -n 5


# ==========================================
# 4. TEST SPARK CORE (Testiamo la 3.3)
# ==========================================
echo ""
echo "🟠 4. TEST SPARK CORE (Analisi 3.3) 🟠"
echo "Esecuzione in corso... (Mostro le prime 5 righe di output)"
rm -rf "$BASE_DIR/temp_debug_spark_core"
"$SPARK_HOME/bin/spark-submit" "$BASE_DIR/analysisis_33/spark_core/spark_core_3_3_.py" "$LOCAL_DATASET_URI" "file://$BASE_DIR/temp_debug_spark_core" 2>/dev/null
# Stampiamo il risultato
cat "$BASE_DIR"/temp_debug_spark_core/part-* | grep -vE 'aeroporto_partenza|NULL' | head -n 5
rm -rf "$BASE_DIR/temp_debug_spark_core"

echo ""
echo "✅ TEST DI DEBUG COMPLETATI!"