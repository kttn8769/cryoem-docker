### Base image: DockerHub nvidia/cuda, CUDA v9.2, cuDNN v7, development package, CentOS7 
FROM nvidia/cuda:9.2-cudnn7-devel-centos7

### User account in Docker image
# username
ARG USER_NAME=""
# UID
ARG USER_ID=""
# GID
ARG GROUP_ID=""
# SSH public key
ARG USER_SSH_PUBKEY=""

### Software configs
ARG RELION_VERSION="3.0.5"
ARG RELION_BUILD_NUM_THREADS="12"
ARG GCTF_BIN_URL="https://www.mrc-lmb.cam.ac.uk/kzhang/Gctf/Gctf_v1.18_b2/bin/Gctf_v1.18_b2_sm61_cu9.2"
ARG GCTF_LIB_URL="https://www.mrc-lmb.cam.ac.uk/kzhang/Gctf/Gctf_v1.18_b2/lib/libEMcore_sm61_cu9.2.so"

###############################################################################

# Install tools and dependencies
RUN yum groupinstall "Development tools" -y && \
    yum install -y \
            cmake \
            openmpi-devel \
            libX11-devel \
            fltk-fluid \
            fftw-devel \
            libtiff-devel \
            texlive-latex-bin \
            texlive-cm \
            texlive-dvips \
            ghostscript \
            evince \
            qpdfview \
            openssh-server \
            sudo \
            wget \
            xauth \
            vim

# SSH configuration
RUN sed -i "s/^.*PasswordAuthentication.*$/PasswordAuthentication no/" /etc/ssh/sshd_config && \
    sed -i "s/^.*X11Forwarding.*$/X11Forwarding yes/" /etc/ssh/sshd_config && \
    sed -i "s/^.*X11UseLocalhost.*$/X11UseLocalhost no/" /etc/ssh/sshd_config && \
    ssh-keygen -A

# Add user
RUN groupadd -g ${GROUP_ID} ${USER_NAME} && \
    useradd -u ${USER_ID} -g ${GROUP_ID} -m -G wheel ${USER_NAME} && \
    echo '%wheel ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    echo 'Defaults:%wheel !requiretty' >> /etc/sudoers

# User configuration
USER ${USER_NAME}
WORKDIR /home/${USER_NAME}
RUN mkdir .ssh && echo -e "${USER_SSH_PUBKEY}" >> .ssh/authorized_keys && \
    echo "export LIBGL_ALWAYS_INDIRECT=1" >> .bashrc && \
    echo 'export PATH=/usr/lib64/openmpi/bin:$PATH' >> .bashrc && \
    echo 'export LD_LIBRARY_PATH=/usr/lib64/openmpi/lib:$LD_LIBRARY_PATH' >> .bashrc

# Relion install
ENV PATH="/usr/lib64/openmpi/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/lib64/openmpi/lib:${LD_LIBRARY_PATH}"
WORKDIR /home/${USER_NAME}
RUN mkdir softwares && cd softwares && \
    git clone https://github.com/3dem/relion.git && \
    cd relion && \
    git checkout $RELION_VERSION && \
    mkdir build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=../install .. && \
    make -j ${BUILD_NUM_THREADS} && make install && \
    echo 'export PATH=${HOME}/softwares/relion/install/bin:$PATH' >> /home/${USER_NAME}/.bashrc

# Gctf install
WORKDIR /home/${USER_NAME}/softwares
RUN mkdir Gctf && cd Gctf && \
    wget ${GCTF_BIN_URL} && \
    wget ${GCTF_LIB_URL} && \
    chmod +x * && \
    echo 'export PATH=${HOME}/softwares/Gctf:$PATH'

# Auto start sshd (port 22)
USER root
EXPOSE 22
CMD [ "/usr/sbin/sshd", "-D" ]
