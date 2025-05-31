import pandas as pd

df = pd.read_csv("./data/hcm_weather.csv")

df = df[["temperature_C", "pressure_mb", "description"]]

weather_mapping = {
    "Moderate or heavy rain shower": 0,
    "Light rain shower": 1,
    "Patchy rain possible": 2,
    "Moderate rain at times": 3,
    "Cloudy": 4,
    "Heavy rain at times": 5,
    "Overcast": 6,
    "Patchy light rain": 7,
    "Partly cloudy": 8,
    "Sunny": 9,
    "Light drizzle": 10
}

df["description"] = df["description"].map(weather_mapping)

df.to_csv("/home/pi/Desktop/App/BMP180-Driver/ai/data/weather_labeled.csv", index=False)
