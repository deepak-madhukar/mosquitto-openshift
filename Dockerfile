FROM alpine:3.11

RUN addgroup -g 1000 mygroup && \
    adduser -G mygroup -u 1000 -h /myuser -D myuser && \
    chown -R myuser:mygroup /myuser && \
    apk --no-cache add mosquitto 

WORKDIR /myuser

# Copy configuration files
COPY config/mosquitto.conf /myuser/mosquitto.conf

# Copy certificates
COPY certs/ /myuser/certs/

# Copy authentication files
COPY auth/passwd /myuser/passwd

# Copy startup scripts
COPY scripts/start.sh /myuser/start.sh

USER myuser

EXPOSE 1883 8883

CMD ["/myuser/start.sh"]

