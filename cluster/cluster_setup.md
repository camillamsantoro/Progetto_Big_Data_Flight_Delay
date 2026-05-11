# Esecuzione su cluster AWS EMR — Guida step-by-step

Documento operativo per eseguire il progetto Flight Delay su cluster AWS Academy/EMR.
Ogni passo è progettato per essere copia-incollabile.

---

## 0. Prerequisiti locali

Sul tuo Mac:

```bash
# AWS CLI (se non già installato)
brew install awscli

# Verifica
aws --version
```

---

## 1. Avvia AWS Academy Learner Lab e prendi le credenziali

1. Login su [AWS Academy](https://awsacademy.instructure.com/)
2. Apri il tuo Learner Lab → clicca **Start Lab** (cerchio verde)
3. Quando il pallino diventa verde, clicca **AWS Details** (link in alto)
4. Espandi **AWS CLI** → vedrai un blocco di credenziali. Copialo in `~/.aws/credentials`:

```ini
[default]
aws_access_key_id=ASIA...
aws_secret_access_key=...
aws_session_token=...
```

> ⚠️ Le credenziali Academy **scadono** dopo ~4 ore. Se ricevi un errore "expired token", torna ad Academy e ricopia le credenziali.

5. Imposta la regione (Academy usa `us-east-1`):

```bash
aws configure set region us-east-1
```

6. Verifica:

```bash
aws sts get-caller-identity
```

Deve restituire `Account` + `Arn`.

---

## 2. Crea il bucket S3 e carica dataset + codice

Scegli un nome bucket **globalmente unico** (es. `flight-delay-bigdata-tuonome-2026`):

```bash
cd /Users/camillamariasantoro/flight-delay-bigdata1
BUCKET=flight-delay-bigdata-tuonome-2026

bash cluster/upload_to_s3.sh "$BUCKET"
```

Lo script:
- crea il bucket (se non esiste)
- carica i 6 dataset CSV (10/25/50/75/100/150%)
- carica il codice (mapper/reducer Python + SQL files)
- carica `run_cluster.sh`

Verifica:

```bash
aws s3 ls "s3://$BUCKET/" --recursive --human-readable | head
```

---

## 3. Lancia il cluster EMR

### 3a. Da console AWS (più semplice)

1. EMR → **Create cluster**
2. **Name**: `flight-delay-cluster`
3. **Release**: `emr-6.15.0` (o il più recente disponibile in Academy)
4. **Applications**: spunta `Hadoop`, `Hive`, `Spark`
5. **Cluster configuration**:
   - **Primary**: 1× `m5.xlarge`
   - **Core**: 2× `m5.xlarge`
6. **Cluster scaling**: disattivato (statico, 3 nodi)
7. **Security configuration and EC2 key pair**: scegli (o crea) una key pair `.pem` per SSH
8. **Identity and Access Management (IAM)**:
   - **Service role**: `EMR_DefaultRole_V2` (o quello che Academy ti mette a disposizione)
   - **EC2 instance profile**: `EMR_EC2_DefaultRole_V2`
9. **Create cluster**

Aspetta ~8-10 minuti che lo stato diventi **Waiting**.

### 3b. Da CLI (alternativa)

```bash
aws emr create-cluster \
  --name flight-delay-cluster \
  --release-label emr-6.15.0 \
  --applications Name=Hadoop Name=Hive Name=Spark \
  --instance-type m5.xlarge \
  --instance-count 3 \
  --use-default-roles \
  --ec2-attributes KeyName=<NOME_KEYPAIR>
```

Salva il `ClusterId` restituito (es. `j-XXXXXXXX`).

---

## 4. SSH al nodo master

Dalla console EMR → cluster → tab **Summary** → **Primary node public DNS**.

Apri la porta 22 (security group del master): EMR di solito chiede di aggiungerla automaticamente la prima volta.

```bash
chmod 400 ~/<NOME_KEYPAIR>.pem
ssh -i ~/<NOME_KEYPAIR>.pem hadoop@<MASTER_DNS>
```

---

## 5. Esegui le analisi sul cluster

Dal master EMR:

```bash
# Scarica run_cluster.sh dal bucket
aws s3 cp s3://flight-delay-bigdata-tuonome-2026/code/run_cluster.sh .
chmod +x run_cluster.sh

# Esegui (sostituisci con il TUO bucket)
S3_BUCKET=flight-delay-bigdata-tuonome-2026 bash run_cluster.sh
```

Tempi attesi per il run completo (3 nodi m5.xlarge, 9 job × 6 dataset = 54 esecuzioni): **~30-50 minuti**.

Lo script:
- copia i CSV da S3 a HDFS (più veloce per i job)
- esegue Hive, Spark SQL, Spark Core (su YARN), MapReduce (Hadoop Streaming) per ogni dataset
- registra i tempi in `benchmarks_cluster.csv`
- pubblica i risultati 100% (full + top10) su `s3://<bucket>/results/`
- pubblica `benchmarks_cluster.csv` su `s3://<bucket>/`

Esci dal master (`exit` o Ctrl-D) quando lo script ha terminato.

---

## 6. Scarica i risultati sul laptop

```bash
cd /Users/camillamariasantoro/flight-delay-bigdata1
bash cluster/download_results.sh "$BUCKET"
```

Genera in locale:
- `results_cluster/` — full + top10 di ogni job al 100% (mirror di `results/`)
- `benchmarks_cluster/benchmarks_cluster.csv` — tempi cluster
- `benchmarks_cluster/charts_cluster/` — directory pronta per i grafici

---

## 7. Genera i grafici cluster

```bash
python3 benchmarks_cluster/generate_charts_cluster.py
```

Produce in `benchmarks_cluster/charts_cluster/`:
- `scalability_per_analysis.png`
- `comparison_100pct.png`
- `heatmap_times.png`

A questo punto puoi fare il confronto locale-vs-cluster:

```bash
diff <(sort benchmarks/benchmarks.csv) <(sort benchmarks_cluster/benchmarks_cluster.csv)
diff results/analysis_31/hive/hive_full_results.csv \
     results_cluster/analysis_31/hive/hive_full_results.csv
```

I dati 100% devono essere identici (modulo arrotondamento sui float).

---

## 8. ⚠️ TERMINA IL CLUSTER

**Critico**: se non termini, EMR continua a fatturare.

Da console: cluster → **Terminate**.

CLI:

```bash
aws emr list-clusters --active --query 'Clusters[].[Id,Name,Status.State]' --output table
aws emr terminate-clusters --cluster-ids j-XXXXXXXXX
```

Verifica:

```bash
aws emr list-clusters --active
# deve essere vuoto
```

Aggiungi anche `Stop Lab` su AWS Academy.

---

## 9. Stima costi

| Voce | Costo |
|------|-------|
| EMR + EC2 (3× m5.xlarge × ~1h) | ~$0.45-0.75 |
| S3 storage (~5 GB × pochi giorni) | ~$0.01 |
| S3 PUT/GET | ~$0.01 |
| Data transfer (intra-regione) | ~$0.00 |
| **Totale per esecuzione completa** | **< $1** |

Con $50 di crediti Academy → ampio margine.

---

## 10. Troubleshooting

| Sintomo | Causa probabile | Soluzione |
|---------|-----------------|-----------|
| `Unable to locate credentials` | Credenziali Academy scadute | Ricopia da AWS Academy → AWS Details |
| `Output directory already exists` | Output Hadoop preesistente | Lo script fa `hadoop fs -rm -r -f` prima — controlla i permessi |
| `Cannot find hadoop-streaming.jar` | EMR release diversa | Esegui `find /usr/lib -name 'hadoop-streaming*.jar'` sul master e aggiorna `HADOOP_STREAMING_JAR` |
| `python3: command not found` (sui worker) | EMR release vecchia | Usa `emr-6.x` o aggiungi una bootstrap action `yum install -y python3` |
| Spark Core 3.3 fallisce in cluster mode | YARN non vede il file Python | Cambia `--deploy-mode cluster` in `--deploy-mode client` (più lento ma più semplice) |
| Hive crash su Derby | EMR fornisce Glue Catalog di default → ok | Nessuna azione |
