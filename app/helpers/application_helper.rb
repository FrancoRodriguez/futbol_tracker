module ApplicationHelper
  def date_in_spanish(date)
    days = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"]
    month = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]

    day_week = days[date.wday]
    day = date.day
    month = month[date.month - 1]
    year = date.year

    "#{day_week} #{day} de #{month} del #{year}"
  end

  def mes_anio_espanol(fecha)
    meses = %w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre]
    nombre_mes = meses[fecha.month - 1].capitalize
    "#{nombre_mes} #{fecha.year}"
  end
end
