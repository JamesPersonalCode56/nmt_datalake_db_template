FROM mcuadros/ofelia:0.3.20
RUN apk add --no-cache docker-cli tini bash
ENTRYPOINT ["/sbin/tini", "--", "/usr/bin/ofelia"]
CMD ["daemon", "--docker"]