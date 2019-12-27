IS_SUDO=""
ARCHICONDA_PYTHON="python3.7"

# edit the locale file if needed
if [ -n "$LOCALE_OVERRIDE" ]; then
    echo "Adding locale to the first line of pandas/__init__.py"
    rm -f pandas/__init__.pyc
    SEDC="3iimport locale\nlocale.setlocale(locale.LC_ALL, '$LOCALE_OVERRIDE')\n"
    sed -i "$SEDC" pandas/__init__.py
    echo "[head -4 pandas/__init__.py]"
    head -4 pandas/__init__.py
    echo
    sudo locale-gen "$LOCALE_OVERRIDE"
fi

if [ `uname -m` = 'aarch64' ]; then
   MINICONDA_DIR="$HOME/archiconda3"
   IS_SUDO="sudo"
else
   MINICONDA_DIR="$HOME/miniconda3"
fi

if [ -d "$MINICONDA_DIR" ]; then
    echo
    echo "rm -rf "$MINICONDA_DIR""
    rm -rf "$MINICONDA_DIR"
fi

echo "Install Miniconda"
UNAME_OS=$(uname)
if [[ "$UNAME_OS" == 'Linux' ]]; then
    if [[ "$BITS32" == "yes" ]]; then
        CONDA_OS="Linux-x86"
    else
        CONDA_OS="Linux-x86_64"
    fi
elif [[ "$UNAME_OS" == 'Darwin' ]]; then
    CONDA_OS="MacOSX-x86_64"
else
  echo "OS $UNAME_OS not supported"
  exit 1
fi

if [ `uname -m` = 'aarch64' ]; then
   wget -q "https://github.com/Archiconda/build-tools/releases/download/0.2.3/Archiconda3-0.2.3-Linux-aarch64.sh" -O archiconda.sh
   chmod +x archiconda.sh
   $IS_SUDO apt-get install python-dev
   $IS_SUDO apt-get install python3-pip
   $IS_SUDO apt-get install lib$ARCHICONDA_PYTHON-dev
   $IS_SUDO apt-get install xvfb
   export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib:/usr/local/lib:/usr/local/bin/python
   ./archiconda.sh -b
   echo "chmod MINICONDA_DIR"
   $IS_SUDO chmod -R 777 $MINICONDA_DIR
   $IS_SUDO cp $MINICONDA_DIR/bin/* /usr/bin/
   $IS_SUDO rm /usr/bin/lsb_release
else
   wget -q "https://repo.continuum.io/miniconda/Miniconda3-latest-$CONDA_OS.sh" -O miniconda.sh
   chmod +x miniconda.sh
   ./miniconda.sh -b
fi

export PATH=$MINICONDA_DIR/bin:$PATH
cp -r $MINICONDA_DIR/bin/ /usr/bin/ 
hash -r

echo
echo "which conda"
which conda

echo
echo "update conda"
conda config --set ssl_verify false
conda config --set quiet true --set always_yes true --set changeps1 false
$IS_SUDO conda install pip  # create conda to create a historical artifact for pip & setuptools
$IS_SUDO conda update -n base conda

echo "conda info -a"
conda info -a

echo
echo "set the compiler cache to work"
if [ -z "$NOCACHE" ] && [ "${TRAVIS_OS_NAME}" == "linux" ]; then
    echo "Using ccache"
    export PATH=/usr/lib/ccache:/usr/lib64/ccache:$PATH
    GCC=$(which gcc)
    echo "gcc: $GCC"
    CCACHE=$(which ccache)
    echo "ccache: $CCACHE"
    export CC='ccache gcc'
elif [ -z "$NOCACHE" ] && [ "${TRAVIS_OS_NAME}" == "osx" ]; then
    echo "Install ccache"
    brew install ccache > /dev/null 2>&1
    echo "Using ccache"
    export PATH=/usr/local/opt/ccache/libexec:$PATH
    gcc=$(which gcc)
    echo "gcc: $gcc"
    CCACHE=$(which ccache)
    echo "ccache: $CCACHE"
else
    echo "Not using ccache"
fi

echo "source deactivate"
source deactivate

echo "conda list (root environment)"
conda list

# Clean up any left-over from a previous build
# (note workaround for https://github.com/conda/conda/issues/2679:
#  `conda env remove` issue)
conda config --set always_yes yes --set changeps1 no
conda update -q conda
conda info -a
export PKGS="numpy scipy coverage nose pip"
if [ "$PANDAS_VERSION_STR" != "NONE" ]; then export PKGS="${PKGS} pandas${PANDAS_VERSION_STR}"; fi
conda create -q -n testenv python=$PYTHON_VERSION ${PKGS}
source activate testenv
