class WeatherService
  def initialize(lat: 40.3536054, lon: -3.5310879)
    #Rivas Vaciamadrid default lat, lon
    @client = OpenWeatherClient.new(lat: lat, lon: lon)
  end

  attr_reader :client

  def forecast_for(date)
    Rails.cache.fetch("weather-#{date}", expires_in: 24.hours) do
      forecast_now(date)
    end
  rescue => e
    Rails.logger.error("Error en WeatherService: #{e.message}")
    nil
  end

  def forecast_now(date)
    data = client.forecast
    return nil unless data

    forecasts = data["list"].select do |entry|
      entry_time = Time.parse(entry["dt_txt"])
      entry_date = entry_time.to_date

      entry_date == date && entry_time.hour.between?(20, 21)
    end

    forecast = forecasts.min_by do |entry|
      (Time.parse(entry["dt_txt"]).hour - 20.5).abs  # más cerca de 20:30
    end

    return nil unless forecast

    {
      temp: forecast["main"]["temp"].round,
      feels_like: forecast["main"]["feels_like"].round,
      weather: forecast["weather"][0]["description"].capitalize,
      icon: forecast["weather"][0]["icon"],
      wind: "#{forecast["wind"]["speed"].round} km/h",
      humidity: "#{forecast["main"]["humidity"]}%",
      rain_chance: "#{(forecast["pop"].to_f * 100).round}%",
      clouds: "#{forecast["clouds"]["all"]}%",
      forecast_time: Time.parse(forecast["dt_txt"]).strftime("%H:%M")
    }
  end
end
