# Convierte strengths a % con 1 decimal
module Stats
  class WinProbabilityCalculator
    def call(strengths)
      total = strengths.values.sum
      return {} unless total.positive?
      strengths.transform_values { |v| (v / total * 100.0).round(1) }
    end
  end
end
