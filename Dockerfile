# This Dockerfile is designed to be the base for other Docker images, for example a Chipyard Docker image, or a SpinalHDL Docker image.
# It also contains rv32ic configuration for RiscBOY.
# It is hoped that it can become the base image for an improved Incore Semiconductors / Shakti setup, as well.
FROM archlinux

MAINTAINER jacobgadikian@gmail.com

# Installs dependencies, and ccache for later optomization
RUN pacman -Syyu --noconfirm ccache autoconf automake curl python3 mpc libusb mpfr tcl gmp gawk base-devel dtc pkg-config bison patchutils git flex texinfo gperf libtool patchutils bc zlib expat flex

# Handy Tools
RUN pacman -Syyu --noconfirm verilator iverilog

# Environment Variables:
# RISCV lets things know where the riscv tools are
# The path entry ensures that those tools are on your $PATH
ENV RISCV=/riscv-gnu-toolchain
ENV PATH=$PATH:/riscv-gnu-toolchain/bin

# RISCV-GNU-TOOLCHAIN
# BROKEN INTO THREE STEPS
# Builds rv32ic for RiscBOY
RUN git clone --recursive https://github.com/riscv/riscv-gnu-toolchain toolchain && \
        cd toolchain && \
        mkdir /riscv-gnu-toolchain && \
        chown root /riscv-gnu-toolchain && \
        ./configure --prefix=/riscv-gnu-toolchain --with-arch=rv32ic --with-abi=ilp32 && \
        make -j $(nproc) 1>/dev/null && \
        make clean

# RISCV-TESTS
# Was not actually able to get tools install to work, but it is enough to just install the tests explicitly.
# Seems OK to put them directly in $RISCV instead of $RISCV/target.  Will Still be on $PATH that way.
# May need to look into riscv compliance suite
# deletes cloned repo to save neglible space
RUN git clone https://github.com/riscv/riscv-tests/ && \
           cd riscv-tests && \
           git submodule update --init --recursive && \
           autoconf && \
           ./configure --prefix=$RISCV && \
           make -j $(nproc) 1>/dev/null && \
           make install && \
           cd .. && \
           rm -rf riscv-tests

RUN pacman -Syyu --noconfirm yosys boost cmake eigen

# Create builduser
RUN pacman -S --needed --noconfirm sudo && \
        useradd builduser -m && passwd -d builduser && \
         printf 'builduser ALL=(ALL) ALL\n' | tee -a /etc/sudoers


# Build and install icestorm
RUN sudo -u builduser bash -c 'cd ~ && git clone https://aur.archlinux.org/icestorm-git.git && cd icestorm-git && makepkg -si --noconfirm && cd .. && rm -rf icestorm-git'

# Build and install trellis
RUN sudo -u builduser bash -c 'cd ~ && git clone https://aur.archlinux.org/trellis-git.git && cd trellis-git && makepkg -si --noconfirm && cd .. && rm -rf trellis-git'

# Build and install nextpnr
RUN sudo -u builduser bash -c 'cd ~ && git clone https://aur.archlinux.org/nextpnr-git.git && cd nextpnr-git && makepkg -si --noconfirm && cd .. && rm -rf nextpnr-git'
