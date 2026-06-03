# 1. Usar una imagen base ligera de Python
FROM python:3.10-slim

# 2. Instalar dependencias del sistema necesarias para compilar paquetes de Postgres
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# 3. Definir el directorio de trabajo dentro del contenedor
WORKDIR /app

# 4. Copiar e instalar los requerimientos primero para aprovechar la caché de Docker
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 5. Copiar el resto del código de la aplicación
COPY . .

# 6. Exponer el puerto interno que utiliza la aplicación (según vimos, el 5153)
EXPOSE 5153

# 7. Comando para arrancar la aplicación
CMD ["python", "app.py"]
