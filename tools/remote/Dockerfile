FROM python:3.12-alpine
RUN apk add --no-cache openssl && pip install --no-cache-dir "qrcode[pil]" || true
WORKDIR /app
COPY server.py lastfm.py lyrics.py index.html /app/
ENV PYTHONUNBUFFERED=1
CMD ["python", "/app/server.py"]
