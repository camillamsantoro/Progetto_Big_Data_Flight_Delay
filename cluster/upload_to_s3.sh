#!/bin/bash
#
# Carica dataset e codice su un bucket S3, da eseguire UNA VOLTA dal laptop locale
# prima di lanciare il cluster EMR.
#
# Uso:    bash cluster/upload_to_s3.sh <bucket-name>
# Esempio: bash cluster/upload_to_s3.sh flight-delay-bigdata-mariasantoro
#
# Prerequisito: aws CLI configurato con credenziali AWS Academy
# (aws configure  oppure  ~/.aws/credentials con sessione attiva)

set -euo pipefail

S3_BUCKET="${1:?Uso: bash $0 <bucket-name>  (deve essere globalmente unico su S3)}"
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "========================================"
echo "Upload dataset+codice su s3://$S3_BUCKET"
echo "========================================"

# Crea bucket (idempotente — ignora errore se esiste)
aws s3 mb "s3://$S3_BUCKET" 2>/dev/null || echo "  bucket già esistente, ok"

echo ""
echo ">> Carico i 6 dataset CSV..."
for P in 10 25 50 75 100 150; do
    SRC="$BASE_DIR/data/cleaned/dataset_${P}.csv"
    if [ ! -f "$SRC" ]; then
        echo "  ATTENZIONE: $SRC non esiste — skip"
        continue
    fi
    aws s3 cp "$SRC" "s3://$S3_BUCKET/data/dataset_${P}.csv" --only-show-errors
    echo "  dataset_${P}.csv ✓"
done

echo ""
echo ">> Carico il codice delle analisi..."
for ANA in analysisis_31 analysisis_32 analysisis_33; do
    aws s3 sync "$BASE_DIR/$ANA/" "s3://$S3_BUCKET/code/$ANA/" \
        --exclude "*.pyc" --exclude "__pycache__/*" --only-show-errors
    echo "  $ANA/ ✓"
done

echo ""
echo ">> Carico lo script run_cluster.sh..."
aws s3 cp "$BASE_DIR/cluster/run_cluster.sh" "s3://$S3_BUCKET/code/run_cluster.sh" --only-show-errors
echo "  run_cluster.sh ✓"

echo ""
echo "========================================"
echo "✅ Upload completato."
echo ""
echo "Contenuto bucket:"
aws s3 ls "s3://$S3_BUCKET/" --recursive --human-readable --summarize | tail -n 6
echo ""
echo "Prossimo step: lancia il cluster EMR e poi sul master esegui:"
echo "    aws s3 cp s3://$S3_BUCKET/code/run_cluster.sh ."
echo "    S3_BUCKET=$S3_BUCKET bash run_cluster.sh"
echo "========================================"
