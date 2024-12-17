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
end
