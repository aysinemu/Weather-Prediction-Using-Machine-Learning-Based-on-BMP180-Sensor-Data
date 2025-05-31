import pandas as pd

df = pd.read_csv("./data/hcm_weather.csv")

df = df[["temperature_C", "pressure_mb", "description"]]

weather_mapping = {
    "Moderate or heavy rain shower": 0,
    "Moderate rain at times": 1,
    "Patchy rain possible": 2,
    "Heavy rain at times": 3,
    "Overcast": 4,
    "Sunny": 5,
    "Partly cloudy": 6,
    "Cloudy": 7,
    "Light rain shower": 8,
    "Patchy light rain": 9,
    "Light drizzle": 10
}

df["description"] = df["description"].map(weather_mapping)

df["description"] = df["description"].apply(lambda x: 1 if x in [0, 8, 10] else 0)

df.to_csv("/home/pi/Desktop/App/BMP180-Driver/ai/data/weather_opti_labeled.csv", index=False)
