import sys
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName('NYC taxi vendor count').getOrCreate()
df = spark.read.parquet(sys.argv[1])
df.filter(df["VendorID"].isNotNull()).select("VendorID").groupBy("VendorID").count().show()
exit()