# .devcontainer/Dockerfile

ARG PYTHON_VERSION=3.11
FROM frappe/bench:py${PYTHON_VERSION}-latest

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    netcat-openbsd \
    mariadb-client \
    redis-tools \
    apt-utils && \
    rm -rf /var/lib/apt/lists/*

ENV NVM_DIR /home/frappe/.nvm
ENV NODE_VERSION 18
RUN mkdir -p ${NVM_DIR} && chown -R frappe:frappe ${NVM_DIR}
USER frappe
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash && \
    . ${NVM_DIR}/nvm.sh && \
    nvm install ${NODE_VERSION} && \
    nvm alias default ${NODE_VERSION} && \
    nvm use default && \
    npm install -g yarn

RUN echo '\nexport NVM_DIR="/home/frappe/.nvm"' >> /home/frappe/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm' >> /home/frappe/.bashrc && \
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion' >> /home/frappe/.bashrc

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sudo chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]