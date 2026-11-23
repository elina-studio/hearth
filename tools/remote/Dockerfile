FROM python:3.12-alpine
RUN apk add --no-cache openssl && pip install --no-cache-dir "qrcode[pil]" || true
WORKDIR /app
COPY server.py lastfm.py lyrics.py web.py index.html /app/
COPY web /app/web
ENV PYTHONUNBUFFERED=1
CMD ["python", "/app/server.py"]
