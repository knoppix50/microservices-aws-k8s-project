# Use an official, public Amazon ECR Python base image to bypass Docker Hub rate limits
FROM public.ecr.aws/docker/library/python:3.10-slim

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

# Disable Python buffering so that logs are sent to CloudWatch in real time
ENV PYTHONUNBUFFERED=1
ENV OTEL_SDK_DISABLED=true
ENV OTEL_METRICS_EXPORTER=none
ENV OTEL_TRACES_EXPORTER=none

# Default command to initialize the API when starting the container
CMD ["python", "app.py"]
