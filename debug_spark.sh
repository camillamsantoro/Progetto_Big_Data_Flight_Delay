#!/bin/bash
export SPARK_HOME="/Users/camillamariasantoro/spark-3.5.8-bin-hadoop3"
export BASE_DIR="/Users/camillamariasantoro/flight-delay-bigdata1"
export SPARK_LOCAL_IP="127.0.0.1"

DATASET_CSV="$BASE_DIR/data/cleaned/dataset_10.csv"
LOCAL_DATASET_URI="file://$DATASET_CSV"

echo "========================================"
echo "🔴 DEBUG ERRORE SPARK CORE 3.3 🔴"
echo "========================================"
rm -rf "$BASE_DIR/temp_spark_core_out"
"$SPARK_HOME/bin/spark-submit" "$BASE_DIR/analysisis_33/spark_core/spark_core_3_3_.py" "$LOCAL_DATASET_URI" "$BASE_DIR/temp_spark_core_out"