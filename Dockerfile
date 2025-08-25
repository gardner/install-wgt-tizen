FROM vitalets/tizen-webos-sdk

COPY entrypoint.sh profile.xml ./

# Install jq for parsing JSON responses
RUN apt update && apt install jq -y && rm -rf /var/lib/apt/lists/* && rm -rf /var/cache/apt/*
RUN chown developer:developer entrypoint.sh
RUN chmod +x entrypoint.sh

# Default environment variables (can be overridden)
ENV GITHUB_REPO=jeppevinkel/jellyfin-tizen-builds
ENV WGT_FILE=Jellyfin
ENV RELEASE_TAG=latest
ENV CERTIFICATE_PASSWORD=

ENTRYPOINT [ "/home/developer/entrypoint.sh" ]