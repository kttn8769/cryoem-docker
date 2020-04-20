### Base image: DockerHub nvidia/cuda, CUDA v9.2, cuDNN v7, development package, CentOS7
FROM nvidia/cuda:9.2-cudnn7-devel-centos7

### User account in Docker image
# username
ARG USER_NAME=""
# groupname
ARG GROUP_NAME=""
# UID
ARG USER_ID=""
# GID
ARG GROUP_ID=""
# SSH public key
ARG USER_SSH_PUBKEY=""
# Specify GID of "vglusers" group if exists, else leave this empty
ARG VGLUSERS_GROUP_ID=""

### Software configs
# RELION
ARG RELION_VERSION="ver3.1"
# GCTF
ARG GCTF_BIN_URL="https://www.mrc-lmb.cam.ac.uk/kzhang/Gctf/Gctf_v1.18_b2/bin/Gctf_v1.18_b2_sm61_cu9.2"
ARG GCTF_LIB_URL="https://www.mrc-lmb.cam.ac.uk/kzhang/Gctf/Gctf_v1.18_b2/lib/libEMcore_sm61_cu9.2.so"
# EMAN2
ARG EMAN2_MINICONDA="Miniconda3-4.6.14-Linux-x86_64.sh"
ARG EMAN2_DEPENDENCY="eman-deps-dev=22.1"

###############################################################################

# Install tools and dependencies
RUN yum update -y && \
    yum groupinstall "Development tools" -y && \
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
            vim \
            libjpeg-turbo-devel \
            mesa-libGL-devel \
            mesa-libGLU-devel
# Node.js install for jupyter lab extension
RUN curl -sL https://rpm.nodesource.com/setup_12.x | bash - && \
    yum install -y nodejs

# SSH configuration
RUN sed -i "s/^.*PasswordAuthentication.*$/PasswordAuthentication no/" /etc/ssh/sshd_config && \
    sed -i "s/^.*X11Forwarding.*$/X11Forwarding yes/" /etc/ssh/sshd_config && \
    sed -i "s/^.*X11UseLocalhost.*$/X11UseLocalhost no/" /etc/ssh/sshd_config && \
    ssh-keygen -A

# Add user
RUN groupadd -g ${GROUP_ID} ${GROUP_NAME} && \
    useradd -u ${USER_ID} -g ${GROUP_ID} -m -G wheel ${USER_NAME} && \
    echo '%wheel ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    echo 'Defaults:%wheel !requiretty' >> /etc/sudoers

# Set vglusers if needed
RUN if [ "${VGLUSERS_GROUP_ID}" != "" ];then \
        groupadd -g ${VGLUSERS_GROUP_ID} vglusers && \
        usermod -aG vglusers ${USER_NAME}; fi

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
    make -j && make install && \
    echo 'export PATH=${HOME}/softwares/relion/install/bin:$PATH' >> /home/${USER_NAME}/.bashrc

# Gctf install
WORKDIR /home/${USER_NAME}/softwares
RUN mkdir Gctf && cd Gctf && \
    wget ${GCTF_BIN_URL} && \
    wget ${GCTF_LIB_URL} && \
    chmod +x * && \
    echo 'export PATH=${HOME}/softwares/Gctf:$PATH'

# EMAN2 install
WORKDIR /home/${USER_NAME}
RUN wget -q "https://repo.continuum.io/miniconda/${EMAN2_MINICONDA}" && \
    bash ./${EMAN2_MINICONDA} -b && \
    source miniconda3/etc/profile.d/conda.sh && \
    conda init bash && \
    conda config --set auto_activate_base False && \
    conda config --set auto_update_conda False && \
    conda create -y -n eman2 ${EMAN2_DEPENDENCY} -c cryoem -c defaults -c conda-forge && \
    conda activate eman2 && \
    conda install -y flake8 jupyterlab && \
    git clone https://github.com/cryoem/eman2.git && \
    cd eman2 && mkdir build && cd build && \
    cmake .. -DENABLE_OPTIMIZE_MACHINE=ON && \
    make -j && make install && make test
WORKDIR /home/${USER_NAME}
# Create script for running jupyterlab server
RUN echo "nohup jupyter-lab --ip=0.0.0.0 --no-browser --notebook-dir='/' --port 8888 &> .jupyterlab_eman2_log.txt < /dev/null &" > run_jupyterlab_eman2.sh && \
    chmod +x run_jupyterlab_eman2

# Auto start sshd (port 22)
USER root
EXPOSE 22
CMD [ "/usr/sbin/sshd", "-D" ]
