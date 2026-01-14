FROM mcuadros/ofelia:latest
RUN apk add --no-cache docker-cli tini
ENTRYPOINT ["/sbin/tini", "--", "/usr/bin/ofelia"]
CMD ["daemon", "--docker"]