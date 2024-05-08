FROM xychelsea/anaconda3:v22.11.1-gpu-jupyter
LABEL description="llama_index GPU Container w/ Jupyter Notebooks"

# $ docker build --network=host -t xychelsea/llama_index:latest-gpu-jupyter -f Dockerfile.nvidia-jupyter .
# $ docker run --rm --gpus=all -it -d -p 8888:8888 xychelsea/llama_index:latest-gpu-jupyter
# $ docker push xychelsea/llama_index:latest-gpu-jupyter

ENV ANACONDA_ENV=llama_index
ENV LLAMA_INDEX_PATH=/usr/local/llama_index
ENV LLAMA_INDEX_VERSION=v0.4.38

# Start as root
USER root

# Update packages
RUN apt-get update --fix-missing \
    && apt-get -y upgrade \
    && apt-get -y dist-upgrade

# Install dependencies
RUN apt-get install --no-install-recommends --no-install-suggests -y \
    git \
    curl 


# Install SQL-related dependencies
RUN apt-get install -y curl gnupg2 unixodbc-dev
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
RUN curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list > /etc/apt/sources.list.d/mssql-release.list
RUN apt-get update
RUN ACCEPT_EULA=Y apt-get install -y msodbcsql18

# Create llama_index directory
RUN mkdir -p ${LLAMA_INDEX_PATH} \
    && fix-permissions ${LLAMA_INDEX_PATH}

# Switch to user "anaconda"
USER ${ANACONDA_UID}
WORKDIR ${HOME}

# Update conda env
RUN conda update -c defaults conda

# add llama_index repository to docker image
RUN git clone https://github.com/jerryjliu/llama_index ${LLAMA_INDEX_PATH} \
    && git config --global --add safe.directory ${LLAMA_INDEX_PATH}

# checkout llama_index branch
WORKDIR ${LLAMA_INDEX_PATH}
RUN git checkout ${LLAMA_INDEX_VERSION}

# Add llama_index directory to home
RUN fix-permissions ${LLAMA_INDEX_PATH} \
    && ln -s ${LLAMA_INDEX_PATH} ${HOME}/llama_index

# create environment
RUN conda create -n ${ANACONDA_ENV} -c conda-forge \
    nb_conda_kernels=${JUPYTER_NB_CK_VERSION} \
    ipywidgets=${JUPYTER_IPYWIDGETS_VERSION}

# install dependencies
RUN conda install -n ${ANACONDA_ENV} -c conda-forge \
    aiohttp=3.8.4 \ 
    aiosignal=1.3.1 \
    async-timeout=4.0.2 \
    attrs=22.2.0 \
    backcall=0.2.0 \
    certifi=2022.12.7 \
    charset-normalizer=2.1.1 \
    dataclasses-json=0.5.7 \
    decorator=5.1.1 \
    dill=0.3.6 \
    executing=1.2.0 \
    flake8=6.0.0 \
    frozenlist=1.3.3 \
    greenlet=2.0.2 \
    iniconfig=2.0.0 \
    jedi=0.18.2 \
    lazy-object-proxy=1.9.0 \
    marshmallow=3.19.0 \
    marshmallow-enum=1.5.1 \
    matplotlib-inline=0.1.6 \
    mypy=0.991 \
    mypy_extensions=1.0.0 \
    numpy=1.24.2 \
    openpyxl \
    pandas=1.5.3 \
    pathspec=0.11.1 \
    parso=0.8.3 \
    pexpect=4.8.0 \
    pickleshare=0.7.5 \
    pip=23.0.1 \
    platformdirs=3.1.1 \
    pluggy=1.0.0 \
    prompt-toolkit=3.0.38 \
    ptyprocess=0.7.0 \
    pydantic=1.10.6 \
    pydocstyle=6.3.0 \
    pygments=2.14.0 \
    pyodbc \
    pytest-dotenv=0.5.2 \
    python-dotenv=1.0.0 \
    python=3.11.0 \
    pyyaml=6.0 \
    rake_nltk=1.0.6 \
    requests=2.28.2 \
    sqlalchemy \
    stack_data=0.6.2 \
    snowballstemmer=2.2.0 \
    tenacity=8.2.2 \
    tiktoken=0.3.2 \
    tomlkit=0.11.6 \
    types-docutils=0.19.1 \
    types-setuptools=67.1.0.0 \
    types-urllib3=1.26.25 \
    typing_inspect=0.8.0 \
    urllib3=1.26.15 \
    wcwidth=0.2.6 \
    wrapt=1.15.0 \
    yarl=1.8.2 -y


WORKDIR ${LLAMA_INDEX_PATH}

# Build llama_index
RUN conda run -n ${ANACONDA_ENV} pip install -r ${LLAMA_INDEX_PATH}/requirements.txt

RUN conda run -n ${ANACONDA_ENV} pip install llama-index \
    llama_index.llms.azure_openai \
    llama-index-llms-openai 

# Switch back to root
USER root

# Clean up anaconda
RUN conda clean -afy

# Clean packages and caches
RUN apt-get --purge -y autoremove git \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* \
    && rm -rvf /home/${ANACONDA_PATH}/.cache/yarn \
    && fix-permissions ${HOME} \
    && fix-permissions ${ANACONDA_PATH}

# Re-activate user "anaconda"
USER $ANACONDA_UID
WORKDIR $HOME

WORKDIR /app

COPY requirements.txt requirements.txt
# RUN apk add --no-cache build-base && \
#     pip install --user --no-cache-dir -r requirements.txt
RUN pip install --user --no-cache-dir -r requirements.txt

COPY . .

# # Production stage
# FROM python:3.8-alpine AS production

# WORKDIR /app

# COPY --from=build /root/.local /root/.local
# COPY . .

# ENV PATH=/root/.local/bin:$PATH

CMD ["python3", "./run.py"]
