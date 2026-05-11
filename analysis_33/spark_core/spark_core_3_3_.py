from pyspark import SparkContext, SparkConf
import sys


def parse_csv_line(line):
    tokens = line.split(",")
    if len(tokens) < 10 or line.startswith("month"):
        return None
    try:
        origin = tokens[4]
        carrier = tokens[2]
        dep_delay = float(tokens[6]) if tokens[6] else None
        arr_delay = float(tokens[7]) if tokens[7] else None
        cancelled = int(tokens[8])
        return (origin, carrier, dep_delay, arr_delay, cancelled)
    except ValueError:
        return None


def main():
    if len(sys.argv) != 3:
        print("Usage: spark_core_3_3.py <input_file.csv> <output_dir>")
        sys.exit(-1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    conf = SparkConf().setAppName("Analysis 3.3 - Spark Core")
    sc = SparkContext(conf=conf)

    parsed_rdd = sc.textFile(input_path).map(parse_csv_line).filter(lambda x: x is not None)

    # Media globale dell'aeroporto: solo voli non cancellati con dep_delay presente
    airport_stats = parsed_rdd \
        .filter(lambda x: x[4] == 0 and x[2] is not None) \
        .map(lambda x: (x[0], (x[2], 1))) \
        .reduceByKey(lambda a, b: (a[0] + b[0], a[1] + b[1])) \
        .mapValues(lambda v: v[0] / v[1])

    def map_carrier_stats(x):
        origin, carrier, dep_delay, arr_delay, cancelled = x
        # count totale voli, cancellati, e somme separate per dep/arr (escludendo NULL)
        dep_sum = dep_delay if (cancelled == 0 and dep_delay is not None) else 0.0
        dep_cnt = 1 if (cancelled == 0 and dep_delay is not None) else 0
        arr_sum = arr_delay if (cancelled == 0 and arr_delay is not None) else 0.0
        arr_cnt = 1 if (cancelled == 0 and arr_delay is not None) else 0
        return ((origin, carrier), (1, cancelled, dep_sum, dep_cnt, arr_sum, arr_cnt))

    carrier_stats = parsed_rdd.map(map_carrier_stats) \
        .reduceByKey(lambda a, b: (a[0]+b[0], a[1]+b[1], a[2]+b[2], a[3]+b[3], a[4]+b[4], a[5]+b[5])) \
        .mapValues(lambda v: (
            v[0],
            round(v[2] / v[3], 2) if v[3] > 0 else 0.0,
            round(v[4] / v[5], 2) if v[5] > 0 else 0.0,
            round((v[1] * 100.0) / v[0], 1)
        )).map(lambda x: (x[0][0], (x[0][1], x[1][0], x[1][1], x[1][2], x[1][3])))

    joined_rdd = carrier_stats.join(airport_stats)

    def calc_diff(x):
        origin = x[0]
        carrier, num_flights, c_avg_dep, c_avg_arr, canc_rate = x[1][0]
        diff = round(c_avg_dep - x[1][1], 2)
        return (origin, (carrier, num_flights, c_avg_dep, c_avg_arr, canc_rate, diff))

    diff_rdd = joined_rdd.map(calc_diff)

    def rank_no_format(x):
        origin = x[0]
        carriers_list = list(x[1])
        # Ordina per ritardo medio partenza ascendente (miglior performance prima)
        carriers_list.sort(key=lambda item: item[2])
        out = []
        for rank, c in enumerate(carriers_list, 1):
            out.append((origin, c[0], c[1], c[2], c[3], c[4], c[5], rank))
        return out

    ranked_rdd = diff_rdd.groupByKey().flatMap(rank_no_format)

    # Ordinamento globale per (aeroporto, classifica) per allineare a MapReduce/Spark SQL
    sorted_rdd = ranked_rdd.sortBy(lambda x: (x[0], x[7]))

    final_rdd = sorted_rdd.map(
        lambda x: f"{x[0]},{x[1]},{x[2]},{x[3]:.2f},{x[4]:.2f},{x[5]:.1f},{x[6]:.2f},{x[7]}"
    )

    # coalesce(1) per produrre un singolo file con ordinamento globale rispettato
    final_rdd.coalesce(1).saveAsTextFile(output_path)
    sc.stop()


if __name__ == "__main__":
    main()
