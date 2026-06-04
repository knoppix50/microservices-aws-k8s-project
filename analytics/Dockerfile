# Use a lightweight, official Python base image to reduce vulnerabilities
FROM python:3.10-slim

# Install essential system packages to enable the compilation of native PostgreSQL dependencies.
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory where the API code will reside
WORKDIR /app

# Copy the dependency list first to optimize layer caching usage in Docker
COPY requirements.txt .

# Install Python libraries without local caching to optimize image size
RUN pip install --no-cache-dir -r requirements.txt

# Copy the entire application source code to the container
COPY . .

# Inform Docker that the container internally exposes port 5153
EXPOSE 5153

# Default command to initialize the API when starting the container
CMD ["python", "app.py"]
