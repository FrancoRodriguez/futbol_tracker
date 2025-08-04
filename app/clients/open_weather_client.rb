require 'net/http'
require 'json'

class OpenWeatherClient
  BASE_URL = "https://api.openweathermap.org/data/2.5/forecast"

  def initialize(lat:, lon:)
    @lat = lat
    @lon = lon
    @api_key = ENV["WEATHER_API_KEY"]
    @uri = URI(ENV["WEATHER_BASE_URL"])
  end

  attr_reader :lat, :lon, :api_key, :uri

  def forecast
    uri.query = URI.encode_www_form({ lat: , lon: , appid: api_key , units: 'metric', lang: 'es' })

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'futbol-tracker-app'

    response = Net::HTTP.get(uri)
    JSON.parse(response)
  rescue => e
    Rails.logger.error("Error en OpenWeatherClient: #{e.message}")
    nil
  end
end
