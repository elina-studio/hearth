FROM python:3.12-alpine
RUN apk add --no-cache openssl && pip install --no-cache-dir qrcode==8.2 pillow==13.0.0
WORKDIR /app
COPY server.py guard.py lastfm.py discover.py lyrics.py web.py index.html /app/
COPY web /app/web
ENV PYTHONUNBUFFERED=1
CMD ["python", "/app/server.py"]
