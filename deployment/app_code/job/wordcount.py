import sys
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName('Amazon reviews word count').getOrCreate()
df = spark.read.parquet(sys.argv[1])
df.select("product_category").groupBy("product_category").count().show()
exit()