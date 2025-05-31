import pandas as pd

# Đọc file CSV
# df = pd.read_csv("./data/hcm_weather.csv")
# df = pd.read_csv("./data/weather_labeled.csv")
df = pd.read_csv("./data/weather_opti_labeled.csv")

unique_descriptions = df["description"].unique()

for i, desc in enumerate(unique_descriptions):
    print(f"{i}: {desc}")
