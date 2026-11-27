FROM python:3.12-alpine
RUN apk add --no-cache openssl ffmpeg && pip install --no-cache-dir qrcode==8.2 pillow==13.0.0
WORKDIR /app
COPY server.py guard.py lastfm.py discover.py shelf.py lyrics.py web.py mix.py clips.py index.html /app/
COPY web /app/web
# the NucBox renderer's files, from the same commit: it updates itself from these (mix.renderer)
COPY viz /app/viz
ENV PYTHONUNBUFFERED=1
CMD ["python", "/app/server.py"]
