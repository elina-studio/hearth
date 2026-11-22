FROM python:3.12-alpine
RUN apk add --no-cache openssl
WORKDIR /app
COPY server.py index.html /app/
ENV PYTHONUNBUFFERED=1
CMD ["python", "/app/server.py"]
