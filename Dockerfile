# ── Stage 1: Build Flutter web ────────────────────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:3.35.4 AS flutter_build

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter build web --release --base-href /

# ── Stage 2: Python backend + serve Flutter ───────────────────────────────────
FROM python:3.11-slim

WORKDIR /app

# Install Python dependencies
COPY backend/requirements.txt ./backend/requirements.txt
RUN pip install --no-cache-dir -r backend/requirements.txt

# Copy backend
COPY backend/ ./backend/

# Copy built Flutter web app
COPY --from=flutter_build /app/build/web ./backend/web/

# Create uploads directory
RUN mkdir -p /app/backend/user_uploads

# Expose port
EXPOSE 5000

WORKDIR /app/backend

CMD ["python", "api_server.py"]
