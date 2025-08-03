.PHONY: app redis rails

app: redis rails

redis:
	@echo "🔧 Iniciando Redis..."
	@brew services start redis

rails:
	@echo "🚀 Iniciando servidor Rails..."
	@bin/rails server
