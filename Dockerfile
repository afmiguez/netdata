# SPDX-License-Identifier: GPL-3.0+
FROM alpine:edge as builder

# Install prerequisites
RUN apk --no-cache add alpine-sdk autoconf automake libmnl-dev build-base jq \
                       lm_sensors nodejs pkgconfig py-mysqldb python libuuid-devel \
                       py-psycopg2 py-yaml util-linux-dev zlib-devel curl bash \
                       netcat-openbsd autopoint libtool pkg-config

# Copy source
COPY netdata-installer.sh ./netdata-installer.sh
COPY functions.sh ./functions.sh

# Install source
RUN chmod +x ./netdata-installer.sh && \
    sync && sleep 1 && \
    ./netdata-installer.sh --dont-wait --dont-start-it

################################################################################
FROM alpine:edge

# Reinstall some prerequisites
RUN apk --no-cache add lm_sensors nodejs libuuid python py-mysqldb \
                       py-psycopg2 py-yaml netcat-openbsd jq curl fping

# Copy files over
COPY --from=builder /usr/share/netdata   /usr/share/netdata
COPY --from=builder /usr/libexec/netdata /usr/libexec/netdata
COPY --from=builder /var/cache/netdata   /var/cache/netdata
COPY --from=builder /var/lib/netdata     /var/lib/netdata
COPY --from=builder /usr/sbin/netdata    /usr/sbin/netdata
COPY --from=builder /etc/netdata         /etc/netdata

ARG NETDATA_UID=101
ARG NETDATA_GID=101

RUN \
    # fping from alpine apk is on a different location. Moving it.
    mv /usr/sbin/fping /usr/local/bin/fping && \
    chmod 4755 /usr/local/bin/fping && \
    mkdir -p /var/log/netdata && \
    # Add netdata user
    addgroup -g ${NETDATA_GID} -S netdata && \
    adduser -S -H -s /bin/sh -u ${NETDATA_GID} -h /etc/netdata -G netdata netdata && \
    # Apply the permissions as described in
    # https://github.com/firehol/netdata/wiki/netdata-security#netdata-directories
    chown -R root:netdata /etc/netdata && \
    chown -R netdata:netdata /var/cache/netdata /var/lib/netdata /usr/share/netdata && \
    chown root:netdata /usr/libexec/netdata/plugins.d/apps.plugin /usr/libexec/netdata/plugins.d/cgroup-network && \
    chmod 4750 /usr/libexec/netdata/plugins.d/cgroup-network /usr/libexec/netdata/plugins.d/apps.plugin && \
    chmod 0750 /var/lib/netdata /var/cache/netdata && \
    # Link log files to stdout
    ln -sf /dev/stdout /var/log/netdata/access.log && \
    ln -sf /dev/stdout /var/log/netdata/debug.log && \
    ln -sf /dev/stderr /var/log/netdata/error.log

EXPOSE 19999

CMD [ "/usr/sbin/netdata" , "-D", "-s", "/host", "-p", "19999"]
