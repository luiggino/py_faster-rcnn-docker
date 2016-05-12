FROM ml_machine:7570ana2

MAINTAINER Luiggino Obreque Minio <luiggino.om@gmail.com>

# Link in our build files to the docker image
ADD src/ /tmp

# Docker no --net=host build command
#CMD "sh" "-c" "echo nameserver 8.8.8.8 > /etc/resolv.conf"

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get dist-upgrade -y && \
    apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        git \
        wget \
        libatlas-base-dev \
        libboost-all-dev \
        libgflags-dev \
        libgoogle-glog-dev \
        libhdf5-serial-dev \
        libleveldb-dev \
        liblmdb-dev \
        libopencv-dev \
        libprotobuf-dev \
        libsnappy-dev \
        protobuf-compiler \
        libopencv-dev \
        libbz2-dev \
        liblzma-dev \
        libtiff4-dev \
          libjpeg8-dev \
          libtiff4-dev \
          libjasper-dev \
          libpng12-dev  \
          libavcodec-dev \
          libavformat-dev \
          libswscale-dev \
          libv4l-dev \
          libgtk2.0-dev \
          unzip \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN cd /root && \
    wget http://tukaani.org/xz/xz-5.2.2.tar.gz && \
    tar zxfv xz-5.2.2.tar.gz && \
    cd xz-5.2.2 && \
	 ./configure --prefix=/usr \
		 --disable-rpath \
		   --enable-werror && \
	  make && \
    make install


RUN echo 'export PATH=/home/luiggino/anaconda2/bin:$PATH' > /etc/profile.d/conda.sh

USER luiggino
ENV PATH=/home/luiggino/anaconda2/bin:$PATH
RUN conda install -y -c https://conda.binstar.org/menpo opencv3

RUN mkdir /home/luiggino/py-faster-rcnn
ENV CAFFE_ROOT=/home/luiggino/py-faster-rcnn
WORKDIR $CAFFE_ROOT

# clone py-faster-rccn
RUN git clone --recursive https://github.com/rbgirshick/py-faster-rcnn.git .

ENV FRCN_ROOT=/home/luiggino/py-faster-rcnn

# We'll call the directory that you cloned Faster R-CNN into FRCN_ROOT
RUN cd $FRCN_ROOT && \
    git submodule update --init --recursive

# Build the Cython modules
RUN cd $FRCN_ROOT/lib && \
    sed -i -- 's/sm_35/sm_30/g' setup.py && \
    make

# Build Caffe and pycaffe
RUN cd $FRCN_ROOT/caffe-fast-rcnn && \
    cp /tmp/Makefile.config .

ENV PATH=/home/luiggino/anaconda2/bin:$PATH

RUN cd $FRCN_ROOT/caffe-fast-rcnn && \
    pip install -r python/requirements.txt

# make caffe
RUN cd $FRCN_ROOT/caffe-fast-rcnn && \
    make pycaffe -j"$(nproc)" && \
    make all -j"$(nproc)"

# Download pre-computed Faster R-CNN detectors
RUN cd $FRCN_ROOT/data && \
    /bin/bash -c "./data/scripts/fetch_faster_rcnn_models.sh"


# Beyond the demo: installation for training and testing models

# Download the training, validation, test data and VOCdevkit
RUN cd $FRCN_ROOT && \
    wget http://host.robots.ox.ac.uk/pascal/VOC/voc2007/VOCtrainval_06-Nov-2007.tar && \
    wget http://host.robots.ox.ac.uk/pascal/VOC/voc2007/VOCtest_06-Nov-2007.tar && \
    wget http://host.robots.ox.ac.uk/pascal/VOC/voc2007/VOCdevkit_08-Jun-2007.tar

# Extract all of these tars into one directory named VOCdevkit
RUN cd $FRCN_ROOT && \
    tar xvf VOCtrainval_06-Nov-2007.tar && \
    tar xvf VOCtest_06-Nov-2007.tar && \
    tar xvf VOCdevkit_08-Jun-2007.tar

# Create symlinks for the PASCAL VOC dataset
RUN ln -s $FRCN_ROOT/VOCdevkit $FRCN_ROOT/data/VOCdevkit2007

# Download pre-trained ImageNet models
# Pre-trained ImageNet models can be downloaded for the three networks described in the paper: ZF and VGG16.
RUN cd $FRCN_ROOT && \
    /bin/bash -c "./data/scripts/fetch_imagenet_models.sh"

USER luiggino
ENV HOME=/home/luiggino
ENV SHELL=/bin/bash
ENV USER=luiggino

ENV CAFFE_ROOT=/home/luiggino/py-faster-rcnn/caffe-fast-rcnn
ENV PYCAFFE_ROOT $CAFFE_ROOT/python
ENV PYTHONPATH $PYCAFFE_ROOT:$PYTHONPATH
ENV PATH $CAFFE_ROOT/build/tools:$PYCAFFE_ROOT:$PATH

WORKDIR /home/luiggino

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

CMD [ "/bin/bash" ]
