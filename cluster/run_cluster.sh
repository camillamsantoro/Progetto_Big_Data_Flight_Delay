#!/bin/bash
#
# RUN_CLUSTER.SH — esegue le 9 analisi su 6 dataset (10/25/50/75/100/150 %)
# in modalità distribuita su un cluster AWS EMR.
#
# DA ESEGUIRE SUL NODO MASTER EMR (via SSH).
#
# Prerequisiti sul master:
#   - hadoop, hive, spark-sql, spark-submit, aws CLI in PATH (preinstallati su EMR)
#   - python3 disponibile su tutti i nodi (default su emr-6.x)
#   - codice analisi sincronizzato in CWD da s3://$S3_BUCKET/code/ (lo fa lo script)
#
# Uso:
#   S3_BUCKET=<bucket> bash run_cluster.sh
#
# Output:
#   - benchmarks_cluster.csv         (Percentuale, Analisi, Tecnologia, Tempo_Secondi)
#   - s3://$S3_BUCKET/results/...    (full + top10 di ogni job al 100%)
#   - s3://$S3_BUCKET/benchmarks_cluster.csv

set -uo pipefail

# ============================================================
# Config
# ============================================================
S3_BUCKET="${S3_BUCKET:?ERRORE: imposta S3_BUCKET=<nome-bucket>}"
HADOOP_STREAMING_JAR="$(find /usr/lib/hadoop -name 'hadoop-streaming*.jar' 2>/dev/null | head -1)"
[ -z "$HADOOP_STREAMING_JAR" ] && { echo "ERRORE: hadoop-streaming.jar non trovato"; exit 1; }

HDFS_DATA="hdfs:///flight-delay/data"
HDFS_TMP="hdfs:///flight-delay/tmp"

PERCENTUALI=(10 25 50 75 100 150)

# Header degli output (identici al locale)
HEADER_31="codice,aeroporto_partenza,numero_voli,ritardo_minimo,ritardo_massimo,ritardo_medio,tasso_cancellazione,mese"
HEADER_32="aeroporto_partenza,mese,numero_ritardi_basso,dep_avg_basso,arr_avg_basso,numero_ritardi_medio,dep_avg_medio,arr_avg_medio,numero_ritardo_alto,dep_avg_alto,arr_avg_alto,cause_maggiori"
HEADER_33="aeroporto_partenza,compagnia,numero_voli,ritardo_medio_partenza,ritardo_medio_arrivo,tasso_cancellazione,differenza,classifica"
FILTRO_PULIZIA="^OK$|^Time taken|op_unique_carrier|origin|aeroporto_partenza|codice"

# ============================================================
# Sync codice da S3 al master (CWD)
# ============================================================
echo "========================================"
echo "Sync codice da s3://$S3_BUCKET/code/"
echo "========================================"
aws s3 sync "s3://$S3_BUCKET/code/" . --only-show-errors

# ============================================================
# Inizializza HDFS: copia i dataset da S3 a HDFS UNA SOLA VOLTA
# ============================================================
echo ""
echo "========================================"
echo "Copio i dataset da S3 a HDFS"
echo "========================================"
hadoop fs -mkdir -p "$HDFS_DATA" "$HDFS_TMP"
for P in "${PERCENTUALI[@]}"; do
    if hadoop fs -test -e "$HDFS_DATA/dataset_${P}.csv"; then
        echo "  dataset_${P}.csv già su HDFS ✓"
    else
        hadoop distcp -overwrite "s3a://$S3_BUCKET/data/dataset_${P}.csv" "$HDFS_DATA/" 2>/dev/null \
            || hadoop fs -cp "s3a://$S3_BUCKET/data/dataset_${P}.csv" "$HDFS_DATA/"
        echo "  dataset_${P}.csv copiato ✓"
    fi
    # Hive richiede una directory come LOCATION: prepara dir per-percentage
    hadoop fs -mkdir -p "$HDFS_DATA/staging_${P}"
    hadoop fs -cp -f "$HDFS_DATA/dataset_${P}.csv" "$HDFS_DATA/staging_${P}/data.csv"
done

# ============================================================
# Init benchmark
# ============================================================
echo "Percentuale,Analisi,Tecnologia,Tempo_Secondi" > benchmarks_cluster.csv

# ============================================================
# Helper: misura il tempo di un comando e logga su CSV
# Args: P ANALISI TECH "comando da eseguire"
# ============================================================
cron() {
    local P="$1" ANA="$2" TECH="$3" CMD="$4"
    echo "-> [$P%] $ANA / $TECH"
    local START END
    START=$(date +%s)
    eval "$CMD" >/dev/null 2>>cluster_run.log || echo "  (warning: exit code non-zero, vedi cluster_run.log)"
    END=$(date +%s)
    echo "${P}%,$ANA,$TECH,$((END - START))" >> benchmarks_cluster.csv
}

# ============================================================
# Helper: salva risultato 100% su S3 (full + top10 con header)
# ============================================================
save_to_s3() {
    local SRC_LOCAL="$1" HEADER="$2" S3_FULL="$3" S3_TOP10="$4"
    {
        echo "$HEADER"
        grep -vE "$FILTRO_PULIZIA" "$SRC_LOCAL" | tr '\t' ',' | sed 's/,$//'
    } > /tmp/full.csv
    head -n 11 /tmp/full.csv > /tmp/top10.csv
    aws s3 cp /tmp/full.csv  "$S3_FULL"  --only-show-errors
    aws s3 cp /tmp/top10.csv "$S3_TOP10" --only-show-errors
    rm -f /tmp/full.csv /tmp/top10.csv
}

# Concatena part-* di un output Hadoop (HDFS) in un file locale TSV/CSV.
# Su EMR i job MR usano >1 reducer per default: ogni part-NNNNN è ordinato
# internamente ma la concatenazione non lo è globalmente. Con SORT_OPTS si
# applica un sort finale per emulare l'output single-reducer (locale).
hdfs_collect() {
    local HDFS_DIR="$1" OUT_LOCAL="$2" SORT_OPTS="${3:-}"
    if [ -n "$SORT_OPTS" ]; then
        hadoop fs -cat "$HDFS_DIR/part-*" 2>/dev/null | sort $SORT_OPTS > "$OUT_LOCAL"
    else
        hadoop fs -cat "$HDFS_DIR/part-*" > "$OUT_LOCAL" 2>/dev/null
    fi
}

# ============================================================
# Loop principale: per ogni percentuale, esegui tutti e 9 i job
# ============================================================
for P in "${PERCENTUALI[@]}"; do
    echo ""
    echo "========================================"
    echo "===   ELABORAZIONE DATASET ${P}%   ==="
    echo "========================================"

    DATA_FILE="$HDFS_DATA/dataset_${P}.csv"
    DATA_DIR="$HDFS_DATA/staging_${P}/"

    # ----------- File SQL combinati (setup + query) -----------
    cat analysis_31/hive/setup_table.sql analysis_31/hive/hive_3_1.sql > /tmp/h31.sql
    cat analysis_32/hive/setup_table.sql analysis_32/hive/hive_3_2.sql > /tmp/h32.sql

    # ============================================================
    # ANALISI 3.1
    # ============================================================
    cron "$P" 3.1 Hive \
        "hive -S --hiveconf DATA_PATH='$DATA_DIR' -f /tmp/h31.sql > /tmp/hive_31.tsv"

    cron "$P" 3.1 Spark_SQL \
        "spark-sql -S --hiveconf DATA_PATH='$DATA_DIR' -f analysis_31/spark_sql/spark_sql_3_1.sql > /tmp/ssql_31.tsv"

    hadoop fs -rm -r -f "$HDFS_TMP/mr_31_${P}" >/dev/null 2>&1
    cron "$P" 3.1 MapReduce \
        "hadoop jar '$HADOOP_STREAMING_JAR' \
            -input '$DATA_FILE' \
            -output '$HDFS_TMP/mr_31_${P}' \
            -mapper 'python3 mapper.py' \
            -reducer 'python3 reducer.py' \
            -file analysis_31/mapreduce/mapper.py \
            -file analysis_31/mapreduce/reducer.py"

    # ============================================================
    # ANALISI 3.2
    # ============================================================
    cron "$P" 3.2 Hive \
        "hive -S --hiveconf DATA_PATH='$DATA_DIR' -f /tmp/h32.sql > /tmp/hive_32.tsv"

    cron "$P" 3.2 Spark_SQL \
        "spark-sql -S --hiveconf DATA_PATH='$DATA_DIR' -f analysis_32/spark_sql/spark_sql_3_2.sql > /tmp/ssql_32.tsv"

    hadoop fs -rm -r -f "$HDFS_TMP/mr_32_${P}" >/dev/null 2>&1
    cron "$P" 3.2 MapReduce \
        "hadoop jar '$HADOOP_STREAMING_JAR' \
            -input '$DATA_FILE' \
            -output '$HDFS_TMP/mr_32_${P}' \
            -mapper 'python3 mapper_3_2.py' \
            -reducer 'python3 reducer_3_2.py' \
            -file analysis_32/mapreduce/mapper_3_2.py \
            -file analysis_32/mapreduce/reducer_3_2.py"

    # ============================================================
    # ANALISI 3.3
    # ============================================================
    hadoop fs -rm -r -f "$HDFS_TMP/sc_33_${P}" >/dev/null 2>&1
    cron "$P" 3.3 Spark_Core \
        "spark-submit --master yarn --deploy-mode cluster \
            analysis_33/spark_core/spark_core_3_3_.py \
            '$DATA_FILE' '$HDFS_TMP/sc_33_${P}'"

    cron "$P" 3.3 Spark_SQL \
        "spark-sql -S --hiveconf DATA_PATH='$DATA_DIR' -f analysis_33/spark_sql/spark_sql_3_3.sql > /tmp/ssql_33.tsv"

    hadoop fs -rm -r -f "$HDFS_TMP/mr_33_${P}" >/dev/null 2>&1
    cron "$P" 3.3 MapReduce \
        "hadoop jar '$HADOOP_STREAMING_JAR' \
            -input '$DATA_FILE' \
            -output '$HDFS_TMP/mr_33_${P}' \
            -mapper 'python3 mapper_3_3.py' \
            -reducer 'python3 reducer_3_3.py' \
            -file analysis_33/mapreduce/mapper_3_3.py \
            -file analysis_33/mapreduce/reducer_3_3.py"

    # ============================================================
    # SALVATAGGIO RISULTATI 100% SU S3
    # ============================================================
    if [ "$P" -eq 100 ]; then
        echo ""
        echo "=> Salvo i risultati 100% su s3://$S3_BUCKET/results/"

        # 3.1
        save_to_s3 /tmp/hive_31.tsv "$HEADER_31" \
            "s3://$S3_BUCKET/results/analysis_31/hive/hive_full_results.csv" \
            "s3://$S3_BUCKET/results/analysis_31/hive/hive_top_10results.csv"
        save_to_s3 /tmp/ssql_31.tsv "$HEADER_31" \
            "s3://$S3_BUCKET/results/analysis_31/spark_sql/spark_sql_full_results.csv" \
            "s3://$S3_BUCKET/results/analysis_31/spark_sql/spark_sql_top_10results.csv"
        hdfs_collect "$HDFS_TMP/mr_31_${P}" /tmp/mr_31.tsv "-t, -k1,1 -k2,2 -k8,8"
        save_to_s3 /tmp/mr_31.tsv "$HEADER_31" \
            "s3://$S3_BUCKET/results/analysis_31/mapreduce/mapreduce_full_results.csv" \
            "s3://$S3_BUCKET/results/analysis_31/mapreduce/mapreduce_top_10results.csv"

        # 3.2
        save_to_s3 /tmp/hive_32.tsv "$HEADER_32" \
            "s3://$S3_BUCKET/results/analysis_32/hive/hive_full_results.csv" \
            "s3://$S3_BUCKET/results/analysis_32/hive/hive_top_10results.csv"
        save_to_s3 /tmp/ssql_32.tsv "$HEADER_32" \
            "s3://$S3_BUCKET/results/analysis_32/spark_sql/spark_sql_full_results.csv" \
            "s3://$S3_BUCKET/results/analysis_32/spark_sql/spark_sql_top_10results.csv"
        hdfs_collect "$HDFS_TMP/mr_32_${P}" /tmp/mr_32.tsv "-t, -k1,1 -k2,2"
        save_to_s3 /tmp/mr_32.tsv "$HEADER_32" \
            "s3://$S3_BUCKET/results/analysis_32/mapreduce/mapreduce_full_results.csv" \
            "s3://$S3_BUCKET/results/analysis_32/mapreduce/mapreduce_top_10results.csv"

        # 3.3
        hdfs_collect "$HDFS_TMP/sc_33_${P}" /tmp/sc_33.tsv
        save_to_s3 /tmp/sc_33.tsv "$HEADER_33" \
            "s3://$S3_BUCKET/results/analysis_33/spark_core/spark_core_full_results.csv" \
            "s3://$S3_BUCKET/results/analysis_33/spark_core/spark_core_top_10results.csv"
        save_to_s3 /tmp/ssql_33.tsv "$HEADER_33" \
            "s3://$S3_BUCKET/results/analysis_33/spark_sql/spark_sql_full_results.csv" \
            "s3://$S3_BUCKET/results/analysis_33/spark_sql/spark_sql_top_10results.csv"
        hdfs_collect "$HDFS_TMP/mr_33_${P}" /tmp/mr_33.tsv "-t, -k1,1 -k8,8n"
        save_to_s3 /tmp/mr_33.tsv "$HEADER_33" \
            "s3://$S3_BUCKET/results/analysis_33/mapreduce/mapreduce_full_results.csv" \
            "s3://$S3_BUCKET/results/analysis_33/mapreduce/mapreduce_top_10results.csv"
    fi

    # Pulizia file temporanei locali
    rm -f /tmp/hive_31.tsv /tmp/hive_32.tsv /tmp/ssql_31.tsv /tmp/ssql_32.tsv \
          /tmp/ssql_33.tsv /tmp/mr_31.tsv /tmp/mr_32.tsv /tmp/mr_33.tsv /tmp/sc_33.tsv \
          /tmp/h31.sql /tmp/h32.sql
done

# ============================================================
# Finalizzazione: pubblica benchmark su S3
# ============================================================
echo ""
echo "========================================"
echo "✅ ESECUZIONE CLUSTER COMPLETATA"
echo "========================================"
aws s3 cp benchmarks_cluster.csv "s3://$S3_BUCKET/benchmarks_cluster.csv" --only-show-errors
echo "Benchmark pubblicato: s3://$S3_BUCKET/benchmarks_cluster.csv"
echo ""
echo "RICORDA: termina il cluster EMR per non bruciare crediti!"
echo "    aws emr terminate-clusters --cluster-ids <cluster-id>"
