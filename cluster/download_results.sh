#!/bin/bash
#
# Scarica i risultati e il benchmark dal bucket S3 al laptop locale.
# Da eseguire DOPO che `run_cluster.sh` sul master EMR è terminato.
#
# Uso: bash cluster/download_results.sh <bucket-name>
#
# Output locale:
#   - results_cluster/                              ← risultati 100% (full + top10)
#   - benchmarks_cluster/benchmarks_cluster.csv     ← tempi cluster
#   - benchmarks_cluster/charts_cluster/            ← cartella vuota, popolata da
#                                                     benchmarks_cluster/generate_charts_cluster.py

set -euo pipefail

S3_BUCKET="${1:?Uso: bash $0 <bucket-name>}"
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "========================================"
echo "Download da s3://$S3_BUCKET/"
echo "========================================"

mkdir -p "$BASE_DIR/results_cluster" \
         "$BASE_DIR/benchmarks_cluster/charts_cluster"

echo ">> Risultati (mirror della struttura locale results/)..."
aws s3 sync "s3://$S3_BUCKET/results/" "$BASE_DIR/results_cluster/" --only-show-errors

echo ">> Benchmark cluster..."
aws s3 cp "s3://$S3_BUCKET/benchmarks_cluster.csv" \
    "$BASE_DIR/benchmarks_cluster/benchmarks_cluster.csv" --only-show-errors

echo ""
echo "✅ Download completato:"
echo "    Risultati:   $BASE_DIR/results_cluster/"
echo "    Benchmark:   $BASE_DIR/benchmarks_cluster/benchmarks_cluster.csv"
echo "    (Charts dir: $BASE_DIR/benchmarks_cluster/charts_cluster/)"
echo ""
echo "Prima riga benchmark:"
head -2 "$BASE_DIR/benchmarks_cluster/benchmarks_cluster.csv" 2>/dev/null || echo "  (file non trovato)"
echo ""
echo "Numero righe benchmark (atteso 55 = header + 54 job):"
wc -l "$BASE_DIR/benchmarks_cluster/benchmarks_cluster.csv" 2>/dev/null || echo "  (file non trovato)"
echo ""
echo "Per generare i grafici:"
echo "    python3 benchmarks_cluster/generate_charts_cluster.py"
