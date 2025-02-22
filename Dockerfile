###
# Coder
###

FROM fedora as code-server-builder
ENV EXTENSIONS_GALLERY='{"serviceUrl":"https://marketplace.visualstudio.com/_apis/public/gallery","cacheUrl":"https://vscode.blob.core.windows.net/gallery/index","itemUrl":"https://marketplace.visualstudio.com/items","controlUrl":"","recommendationsUrl":""}'
ENV PATH=${PATH}:/usr/local/deps/code-server/bin
RUN curl -fsSL https://code-server.dev/install.sh | sh -s -- --prefix=/usr/local/deps/code-server --method=standalone && \
  rm -rf ~/.cache
# Install Extensions
RUN /usr/local/deps/code-server/bin/code-server \
  --extensions-dir /usr/local/deps/code-server/extensions \
  --user-data-dir /usr/local/deps/code-server/data \
  --install-extension ms-vscode.cpptools-extension-pack \
  --install-extension llvm-vs-code-extensions.vscode-clangd \
  --install-extension ms-vscode.makefile-tools  \
  --install-extension VisualStudioExptTeam.vscodeintellicode  \
  --install-extension ms-vscode.powershell  \
  # Java
  --install-extension vscjava.vscode-java-pack  \
  --install-extension vscjava.vscode-gradle  \
  --install-extension redhat.vscode-quarkus  \
  # Python
  --install-extension ms-python.python  \
  --install-extension ms-toolsai.jupyter  \
  --install-extension ms-toolsai.vscode-jupyter-powertoys  \
  --install-extension ms-python.isort  \
  --install-extension ms-python.pylint  \
  --install-extension ms-python.black-formatter  \
  --install-extension ms-python.mypy-type-checker  \
  --install-extension charliermarsh.ruff \
  \
  --install-extension ms-kubernetes-tools.vscode-kubernetes-tools  \
  --install-extension ms-azuretools.vscode-docker  \
  --install-extension ms-dotnettools.vscode-dotnet-pack  \
  --install-extension ms-dotnettools.csdevkit \
  --install-extension esbenp.prettier-vscode  \
  --install-extension rust-lang.rust-analyzer  \
  --install-extension ms-vscode.hexeditor  \
  --install-extension eamodio.gitlens  \
  --install-extension ms-vscode.vs-keybindings


FROM fedora as rust-builder
ENV RUSTUP_HOME=/usr/local/rustup \
  CARGO_HOME=/usr/local/cargo
COPY --link --chown=${USER_UID}:${USER_GID} --chmod=0777 --from=rust:slim /usr/local/rustup ${RUSTUP_HOME}
COPY --link --chown=${USER_UID}:${USER_GID} --chmod=0777 --from=rust:slim /usr/local/cargo ${CARGO_HOME}
ENV PATH=${CARGO_HOME}/bin:$PATH
RUN rustup component add clippy rustfmt llvm-tools rust-analyzer


# Add PowerShell
FROM fedora as powershell-builder
COPY --link --chown=${USER_UID}:${USER_GID} --chmod=0777 --from=mcr.microsoft.com/powershell /opt/microsoft/powershell /usr/local/deps/powershell
RUN mv /usr/local/deps/powershell/*/* /usr/local/deps/powershell/


# Add Ninja
FROM alpine as ninja-builder
RUN wget https://github.com/ninja-build/ninja/releases/latest/download/ninja-linux.zip -O - | unzip -d /usr/local/ -

FROM fedora

# C++ Based tools
RUN dnf update --assumeyes && \
  dnf install --assumeyes \
  clang \
  clang-tools-extra \
  clang-analyzer \
  libcxx-devel \
  libcxxabi-devel \
  libcxx-static \
  libcxxabi-static \
  git-clang-format \
  cmake \
  nasm \
  bash \
  glibc-langpack-en \
  ca-certificates \
  curl \
  wget \
  vim \
  tar \
  nano \
  dos2unix \
  sudo \
  bash-completion \
  git \
  icu && \
  dnf clean all

# Make typing unicode characters in the terminal work.
ENV LC_ALL=en_US.UTF-8 \
  LANG=en_US.UTF-8

# Create a user for development
ARG USERNAME=coder
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

# Add a user `coder` so that you're not developing as the `root` user
RUN useradd ${USERNAME} \
  --create-home \
  --shell=/bin/bash \
  # --groups=docker \
  --uid=${USER_UID} \
  --user-group && \
  echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >>/etc/sudoers.d/nopasswd

USER ${USERNAME}
ENV USER=${USERNAME}
WORKDIR /home/${USERNAME}

# Add docker-compose
# Compose V2 as docker plugin
COPY --link --chown=${USER_UID}:${USER_GID} --chmod=0777 --from=docker:cli /usr/local/libexec/docker/cli-plugins/docker-compose /usr/local/libexec/docker/cli-plugins/docker-compose

# Add Node
COPY --link --chown=${USER_UID}:${USER_GID} --chmod=0777 --from=node:slim /usr/local /usr/local/deps/node
ENV PATH=/usr/local/deps/node/bin:$PATH

# Add Python
COPY --link --chown=${USER_UID}:${USER_GID} --chmod=0777 --from=python:slim /usr/local /usr/local

# Add GCC
COPY --link --chown=${USER_UID}:${USER_GID} --chmod=0777 --from=gcc:latest /usr/local /usr/local

# Add Java
ENV JAVA_HOME /opt/java/openjdk
ENV PATH ${JAVA_HOME}/bin:$PATH
COPY --link --chown=${USER_UID}:${USER_GID} --chmod=0777 --from=eclipse-temurin /opt/java/openjdk ${JAVA_HOME}

# Add .NET
COPY --link --chown=${USER_UID}:${USER_GID} --chmod=0777 --from=mcr.microsoft.com/dotnet/sdk /usr/share/dotnet /usr/local/deps/dotnet
ENV PATH=/usr/local/deps/dotnet:$PATH

# Add Rust
ENV RUSTUP_HOME=/usr/local/rustup \
  CARGO_HOME=/usr/local/cargo
COPY --link --chown=${USER_UID}:${USER_GID} --chmod=0777 --from=rust-builder /usr/local/rustup ${RUSTUP_HOME}
COPY --link --chown=${USER_UID}:${USER_GID} --chmod=0777 --from=rust-builder /usr/local/cargo ${CARGO_HOME}
ENV PATH=${CARGO_HOME}/bin:$PATH

# Add Code Server
ENV EXTENSIONS_GALLERY='{"serviceUrl":"https://marketplace.visualstudio.com/_apis/public/gallery","cacheUrl":"https://vscode.blob.core.windows.net/gallery/index","itemUrl":"https://marketplace.visualstudio.com/items","controlUrl":"","recommendationsUrl":""}'
COPY --chown=${USER_UID}:${USER_GID} --chmod=0777 --from=code-server-builder /usr/local/deps/code-server /usr/local/deps/code-server

# Add PowerShell
COPY --link --chown=${USER_UID}:${USER_GID} --chmod=0777 --from=powershell-builder /usr/local/deps/powershell /usr/local/deps/powershell
ENV PATH=/usr/local/deps/powershell:$PATH

# Add Ninja
COPY --link --chown=${USER_UID}:${USER_GID} --chmod=0777 --from=ninja-builder /usr/local/ninja /usr/local/bin/ninja

# Path to Coder IDE
WORKDIR /home/${USERNAME}/code

EXPOSE 8080

ENTRYPOINT ["/usr/local/deps/code-server/bin/code-server", "--bind-addr", "0.0.0.0:8080", "--disable-telemetry", "--disable-getting-started-override", "--extensions-dir", "/usr/local/deps/code-server/extensions", "--user-data-dir", "/usr/local/deps/code-server/data", "."]

HEALTHCHECK CMD \
  curl -f http://localhost:8080/healthz || exit 1