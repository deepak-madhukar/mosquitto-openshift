FROM alpine:3.11

RUN addgroup -g 1000 mygroup && \
    adduser -G mygroup -u 1000 -h /myuser -D myuser && \
    chown -R myuser:mygroup /myuser && \
    apk --no-cache add mosquitto 

WORKDIR /myuser

# Copy files
COPY config/mosquitto.conf /myuser/mosquitto.conf
COPY certs/ /myuser/
COPY auth/passwd /myuser/passwd
COPY scripts/start.sh /myuser/start.sh

RUN chmod +x /myuser/start.sh

USER myuser

EXPOSE 1883 8883

ENTRYPOINT ["/myuser/start.sh"]
