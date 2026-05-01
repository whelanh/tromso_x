FROM localhost/aurora:latest
COPY .build-out/aurora-ostree-final/. /ostree/repo
LABEL "com.redhat.bootc.DefaultRootFs"="xfs"
ENV OSTREE_REPO="/ostree/repo"
# Synchronize all markers
RUN version="6.19.11" &&     ostree --repo=/ostree/repo cat ${version} /usr/lib/os-release > /usr/lib/os-release &&     ln -sf ../usr/lib/os-release /etc/os-release &&     mkdir -p "/usr/lib/modules/${version}" &&     ostree --repo=/ostree/repo checkout --subpath="/usr/lib/modules/${version}" ${version} /tmp/mod-sync &&     cp -rT /tmp/mod-sync "/usr/lib/modules/${version}" &&     rm -rf /tmp/mod-sync
