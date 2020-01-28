FROM debian:buster

ARG CLOUD_SDK_VERSION=277.0.0
ENV CLOUD_SDK_VERSION=${CLOUD_SDK_VERSION}
ENV CLOUDSDK_PYTHON=python3
ENV PATH "$PATH:/opt/google-cloud-sdk/bin/"

RUN apt-get -qqy update && apt-get install -qqy \
        curl \
        dnsutils \
        gcc \
        jq \
        python3-dev \
        python3-pip \
        apt-transport-https \
        lsb-release \
        openssh-client \
        git \
        make \
        gnupg && \
    pip3 install -U crcmod
 RUN echo 'deb http://deb.debian.org/debian/ sid main' >> /etc/apt/sources.list && \
    export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" && \
    echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    apt-get update && \
    apt-get install -y google-cloud-sdk=${CLOUD_SDK_VERSION}-0 \
        kubectl && \
    gcloud --version && \
    kubectl version --client

ENV HOME="/var/lib/my-dyndns"

RUN groupadd -g 2000 my-dyndns && \
useradd -c "My DYNDNS (Google Cloud DNS)" -d /var/lib/my-dyndns -m -u 2000 -s /bin/bash -g my-dyndns my-dyndns
USER my-dyndns
WORKDIR /var/lib/my-dyndns


VOLUME ["/var/lib/my-dyndns/.config", "/var/lib/my-dyndns/.kube", "/etc/my-dyndns"]

ENV CLOUDSDK_CORE_PROJECT=""
ENV CLOUDSDK_COMPUTE_ZONE=""

ENV GCLOUD_SERVICE_ACCOUNT_KEY_FILE="/etc/my-dyndns/gcloud-service-account-key.json"
ENV GCLOUD_DNS_ZONE_ID=""
ENV DNS_RECORD_RRDATAS=""
ENV DNS_RECORD_TYPE="A"
ENV DNS_RECORD_TTL="60"

COPY ./public-ip-sync-google-clouddns.sh /usr/local/bin/public-ip-sync-google-clouddns
ENTRYPOINT [ "/usr/local/bin/public-ip-sync-google-clouddns" ]
