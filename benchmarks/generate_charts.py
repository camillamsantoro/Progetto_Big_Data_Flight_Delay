#!/usr/bin/env python3
"""
Genera grafici di confronto benchmark per il progetto Flight Delay.
Legge benchmarks/benchmarks.csv e produce 3 grafici in benchmarks/charts/.

Uso: python3 benchmarks/generate_charts.py
"""

import os
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.join(SCRIPT_DIR, "benchmarks.csv")
CHARTS_DIR = os.path.join(SCRIPT_DIR, "charts")
os.makedirs(CHARTS_DIR, exist_ok=True)

df = pd.read_csv(CSV_PATH, dtype={'Analisi': str})
# Normalizza: "10%" → 10
df['Pct'] = df['Percentuale'].str.replace('%', '').astype(int)

PERCENTUALI = sorted(df['Pct'].unique())
ANALISI = sorted(df['Analisi'].unique())
TECNOLOGIE = sorted(df['Tecnologia'].unique())

COLORS = {
    'Hive':       '#E67E22',
    'Spark_SQL':  '#2980B9',
    'Spark_Core': '#8E44AD',
    'MapReduce':  '#27AE60',
}
MARKERS = {
    'Hive':       'o',
    'Spark_SQL':  's',
    'Spark_Core': '^',
    'MapReduce':  'D',
}

# ── GRAFICO 1: Scalabilità — linechart per analisi ──────────────────────────
fig, axes = plt.subplots(1, 3, figsize=(16, 5), sharey=False)
fig.suptitle('Scalabilità: tempo di esecuzione al variare della dimensione del dataset',
             fontsize=13, fontweight='bold', y=1.02)

for i, analisi in enumerate(ANALISI):
    ax = axes[i]
    df_a = df[df['Analisi'] == analisi]
    for tech in TECNOLOGIE:
        df_t = df_a[df_a['Tecnologia'] == tech].sort_values('Pct')
        if df_t.empty:
            continue
        ax.plot(df_t['Pct'], df_t['Tempo_Secondi'],
                color=COLORS.get(tech, 'gray'),
                marker=MARKERS.get(tech, 'o'),
                linewidth=2, markersize=6,
                label=tech)
    ax.set_title(f'Analisi {analisi}', fontsize=11)
    ax.set_xlabel('Dimensione dataset (%)')
    ax.set_ylabel('Tempo (secondi)')
    ax.set_xticks(PERCENTUALI)
    ax.legend(fontsize=8)
    ax.grid(axis='y', linestyle='--', alpha=0.5)

plt.tight_layout()
out1 = os.path.join(CHARTS_DIR, 'scalability_per_analysis.png')
plt.savefig(out1, dpi=150, bbox_inches='tight')
plt.close()
print(f"[1] Salvato: {out1}")

# ── GRAFICO 2: Confronto tecnologie al 100% — grouped bar chart ─────────────
df_100 = df[df['Pct'] == 100]

fig, ax = plt.subplots(figsize=(10, 5))
fig.suptitle('Confronto tecnologie al 100% del dataset', fontsize=13, fontweight='bold')

x = np.arange(len(ANALISI))
techs_per_analisi = {a: sorted(df_100[df_100['Analisi'] == a]['Tecnologia'].unique()) for a in ANALISI}
all_techs = sorted(set(t for ts in techs_per_analisi.values() for t in ts))
n = len(all_techs)
width = 0.7 / n

for j, tech in enumerate(all_techs):
    vals = []
    for analisi in ANALISI:
        row = df_100[(df_100['Analisi'] == analisi) & (df_100['Tecnologia'] == tech)]
        vals.append(row['Tempo_Secondi'].values[0] if not row.empty else 0)
    offset = (j - n / 2 + 0.5) * width
    bars = ax.bar(x + offset, vals, width, label=tech,
                  color=COLORS.get(tech, 'gray'), alpha=0.85)
    for bar, v in zip(bars, vals):
        if v > 0:
            ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.3,
                    str(v), ha='center', va='bottom', fontsize=8)

ax.set_xticks(x)
ax.set_xticklabels([f'Analisi {a}' for a in ANALISI])
ax.set_ylabel('Tempo (secondi)')
ax.legend(title='Tecnologia', fontsize=9)
ax.grid(axis='y', linestyle='--', alpha=0.5)
plt.tight_layout()
out2 = os.path.join(CHARTS_DIR, 'comparison_100pct.png')
plt.savefig(out2, dpi=150, bbox_inches='tight')
plt.close()
print(f"[2] Salvato: {out2}")

# ── GRAFICO 3: Heatmap tempi ─────────────────────────────────────────────────
df['Label'] = df['Analisi'] + ' / ' + df['Tecnologia']
pivot = df.pivot_table(index='Label', columns='Pct', values='Tempo_Secondi', aggfunc='first')
pivot = pivot.reindex(sorted(pivot.index))

fig, ax = plt.subplots(figsize=(11, max(4, len(pivot) * 0.5 + 1)))
fig.suptitle('Heatmap tempi di esecuzione (secondi)', fontsize=13, fontweight='bold')
sns.heatmap(pivot, annot=True, fmt='.0f', cmap='YlOrRd',
            linewidths=0.5, linecolor='white',
            cbar_kws={'label': 'Tempo (s)'}, ax=ax)
ax.set_xlabel('Dimensione dataset (%)')
ax.set_ylabel('')
plt.tight_layout()
out3 = os.path.join(CHARTS_DIR, 'heatmap_times.png')
plt.savefig(out3, dpi=150, bbox_inches='tight')
plt.close()
print(f"[3] Salvato: {out3}")

print("\nGrafici generati con successo in benchmarks/charts/")
