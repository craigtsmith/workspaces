FROM alpine:3.21

ARG USER=coder
ARG UID=1000

# System packages (alphabetical for layer caching)
RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    direnv \
    docker \
    docker-cli-compose \
    eza \
    fzf \
    git \
    github-cli \
    gum \
    jq \
    openssh-client \
    python3 \
    shadow \
    starship \
    stow \
    sudo \
    tmux \
    zoxide \
    zsh

# Create user with sudo access
RUN useradd -m -s /bin/zsh -u ${UID} ${USER} \
    && echo "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${USER}

USER ${USER}
WORKDIR /home/${USER}

# nvm (Node Version Manager)
ENV NVM_DIR=/home/${USER}/.nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash \
    && . "$NVM_DIR/nvm.sh" && nvm install --lts

# uv (Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# bun (JavaScript runtime)
RUN curl -fsSL https://bun.sh/install | bash

# Shell configuration
ENV PATH="/home/${USER}/.local/bin:/home/${USER}/.bun/bin:${PATH}"
ENV SHELL=/bin/zsh

ENTRYPOINT ["/bin/bash"]
