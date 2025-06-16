import os
import yaml
import time
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
import tensorflow as tf
from tensorflow.keras.models import Sequential, load_model
from tensorflow.keras.layers import LSTM, Dense, Dropout
from tensorflow.keras.callbacks import EarlyStopping
import requests
import logging
import json

# Configuração de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('predictive-analytics')

class N8nPredictor:
    def __init__(self):
        self.config = self._load_config()
        self.model = None
        self.scaler = None
        self.prometheus_url = os.getenv('PROMETHEUS_URL')
        self.model_update_interval = int(os.getenv('MODEL_UPDATE_INTERVAL', 3600))
        self.prediction_window = int(os.getenv('PREDICTION_WINDOW', 86400))
        
    def _load_config(self):
        """Carrega configuração do modelo"""
        with open('/app/config/config.yaml', 'r') as f:
            return yaml.safe_load(f)
    
    def _fetch_metrics(self, start_time, end_time):
        """Busca métricas do Prometheus"""
        metrics_data = {}
        for feature in self.config['features']:
            query = f'avg_over_time({feature}[5m])'
            response = requests.get(
                f'{self.prometheus_url}/api/v1/query_range',
                params={
                    'query': query,
                    'start': start_time,
                    'end': end_time,
                    'step': '5m'
                }
            )
            if response.status_code == 200:
                data = response.json()
                if data['status'] == 'success':
                    values = [float(v[1]) for v in data['data']['result'][0]['values']]
                    metrics_data[feature] = values
            else:
                logger.error(f'Erro ao buscar métrica {feature}: {response.text}')
        
        return pd.DataFrame(metrics_data)
    
    def _prepare_sequences(self, data, sequence_length=12):
        """Prepara sequências para o modelo LSTM"""
        sequences = []
        targets = []
        
        for i in range(len(data) - sequence_length):
            sequences.append(data[i:(i + sequence_length)])
            targets.append(data[i + sequence_length])
        
        return np.array(sequences), np.array(targets)
    
    def _build_model(self, input_shape):
        """Constrói o modelo LSTM"""
        model = Sequential()
        
        for i, units in enumerate(self.config['model']['layers']):
            if i == 0:
                model.add(LSTM(units, input_shape=input_shape, return_sequences=True))
            else:
                model.add(LSTM(units, return_sequences=False))
            
            model.add(Dropout(self.config['model']['dropout']))
        
        model.add(Dense(len(self.config['features'])))
        model.compile(optimizer='adam', loss='mse')
        
        return model
    
    def train_model(self):
        """Treina o modelo com dados históricos"""
        end_time = datetime.now()
        start_time = end_time - timedelta(days=7)
        
        # Busca dados históricos
        data = self._fetch_metrics(start_time.timestamp(), end_time.timestamp())
        
        # Prepara dados
        X, y = self._prepare_sequences(data.values)
        
        # Constrói e treina o modelo
        self.model = self._build_model((X.shape[1], X.shape[2]))
        
        early_stopping = EarlyStopping(
            patience=self.config['training']['early_stopping_patience'],
            restore_best_weights=True
        )
        
        self.model.fit(
            X, y,
            batch_size=self.config['training']['batch_size'],
            epochs=self.config['training']['epochs'],
            validation_split=self.config['training']['validation_split'],
            callbacks=[early_stopping]
        )
        
        # Salva o modelo
        self.model.save('/app/models/predictor_model.h5')
        logger.info('Modelo treinado e salvo com sucesso')
    
    def load_model(self):
        """Carrega modelo salvo"""
        try:
            self.model = load_model('/app/models/predictor_model.h5')
            logger.info('Modelo carregado com sucesso')
            return True
        except:
            logger.warning('Modelo não encontrado, será necessário treinar um novo')
            return False
    
    def predict(self):
        """Realiza predições"""
        end_time = datetime.now()
        start_time = end_time - timedelta(hours=1)
        
        # Busca dados recentes
        data = self._fetch_metrics(start_time.timestamp(), end_time.timestamp())
        
        if len(data) < 12:
            logger.error('Dados insuficientes para predição')
            return None
        
        # Prepara sequência
        sequence = data.values[-12:].reshape(1, 12, len(self.config['features']))
        
        # Realiza predição
        prediction = self.model.predict(sequence)
        
        # Analisa resultados
        alerts = []
        for i, feature in enumerate(self.config['features']):
            predicted_value = prediction[0][i]
            threshold = self.config['thresholds'].get(f'{feature}_warning')
            
            if threshold and predicted_value > threshold:
                alerts.append({
                    'feature': feature,
                    'predicted_value': float(predicted_value),
                    'threshold': threshold,
                    'timestamp': datetime.now().isoformat()
                })
        
        return alerts
    
    def send_alerts(self, alerts):
        """Envia alertas"""
        if not alerts:
            return
        
        # Prepara mensagem
        message = "⚠️ Alertas de Predição:\n\n"
        for alert in alerts:
            message += f"• {alert['feature']}:\n"
            message += f"  - Valor previsto: {alert['predicted_value']:.2f}\n"
            message += f"  - Threshold: {alert['threshold']}\n"
            message += f"  - Timestamp: {alert['timestamp']}\n\n"
        
        # Envia para Slack
        if self.config['notifications']['slack_webhook']:
            try:
                requests.post(
                    self.config['notifications']['slack_webhook'],
                    json={'text': message}
                )
            except Exception as e:
                logger.error(f'Erro ao enviar alerta para Slack: {e}')
        
        # Registra alertas
        logger.warning(message)
    
    def run(self):
        """Loop principal"""
        logger.info('Iniciando serviço de análise preditiva')
        
        while True:
            try:
                # Carrega ou treina modelo
                if not self.model:
                    if not self.load_model():
                        self.train_model()
                
                # Realiza predições
                alerts = self.predict()
                if alerts:
                    self.send_alerts(alerts)
                
                # Atualiza modelo periodicamente
                if time.time() % self.model_update_interval < 60:
                    logger.info('Atualizando modelo')
                    self.train_model()
                
                # Aguarda próximo ciclo
                time.sleep(60)
                
            except Exception as e:
                logger.error(f'Erro no loop principal: {e}')
                time.sleep(60)

if __name__ == '__main__':
    predictor = N8nPredictor()
    predictor.run() 