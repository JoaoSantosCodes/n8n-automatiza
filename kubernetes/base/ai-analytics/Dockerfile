FROM python:3.9-slim

# Instala dependências do sistema
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Define diretório de trabalho
WORKDIR /app

# Copia requirements
COPY requirements.txt .

# Instala dependências Python
RUN pip install --no-cache-dir -r requirements.txt

# Copia código
COPY predictor.py .

# Define variáveis de ambiente
ENV PYTHONUNBUFFERED=1 \
    PROMETHEUS_URL="http://prometheus:9090" \
    MODEL_UPDATE_INTERVAL=3600 \
    PREDICTION_WINDOW=86400

# Executa o predictor
CMD ["python", "predictor.py"] 