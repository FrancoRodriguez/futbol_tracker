module ApplicationHelper
  def date_in_spanish(date, format = :full)
    days   = [ "Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado" ]
    months = [ "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
              "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre" ]

    day_week = days[date.wday]
    day      = date.day
    month    = months[date.month - 1]
    year     = date.year

    case format
    when :day
      day_week
    when :short
      "#{day} de #{month}"
    when :short_with_year
      "#{day} de #{month} de #{year}"
    else # :full
      "#{day_week} #{day} de #{month} del #{year}"
    end
  end

  def month_year_spanish(date)
    month = %w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre]
    name_month = month[date.month - 1].capitalize
    "#{name_month} #{date.year}"
  end
end
