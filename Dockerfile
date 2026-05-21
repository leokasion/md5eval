# Stage 1: Build & Dependencies
FROM python:3.11-slim AS builder

WORKDIR /app

# Install build dependencies if needed, and set up a venv
RUN  python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy only requirements first to leverage Docker's layer caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Stage 2: Final runtime image
FROM python:3.11-slim AS runner

WORKDIR /app

# Copy the virtual env from the builder stage
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy the application source code
COPY main.py .

# Hardening: Run as a non-privileged system user instead of root
RUN useradd -u 10001 -m appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

# Use uvicorn as the ASGI server production worker
CMD ["uvicorn", "main.:app", "--host", "0.0.0.0", "--port", "0.0.0.0"]
