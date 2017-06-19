#!/bin/bash

# exit if the command line is empty
if [ $# -eq 0 ]; then
  echo "Usage: $0 LIBRARY..."
  exit 0
fi

# binary directory
BIN_DIR="$(dirname "$PWD")/bin"

# temporary installation directory for dependencies
INSTALL_DIR="$PWD/deps"

# Mac OS X global settings
MACOSX_ARCH="i386"
MACOSX_VERSION="10.6"
MACOSX_SDK_PATH="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.7.sdk"

# number of parallel jobs used for building
MAKEFLAGS="-j4"

# flags for manual building with gcc; build universal binaries for luasocket
MACOSX_FLAGS="-arch $MACOSX_ARCH -mmacosx-version-min=$MACOSX_VERSION"
if [ -d "$MACOSX_SDK_PATH" ]; then
  echo "Building with $MACOSX_SDK_PATH"
  MACOSX_FLAGS="$MACOSX_FLAGS -isysroot $MACOSX_SDK_PATH"
fi
BUILD_FLAGS="-O2 -arch x86_64 -dynamiclib -undefined dynamic_lookup $MACOSX_FLAGS -I $INSTALL_DIR/include -L $INSTALL_DIR/lib"

# paths configuration
WXWIDGETS_BASENAME="wxWidgets"
WXWIDGETS_URL="https://github.com/pkulchenko/wxWidgets.git"

WXLUA_BASENAME="wxlua"
WXLUA_URL="https://github.com/pkulchenko/wxlua.git"

LUASOCKET_BASENAME="luasocket-3.0-rc1"
LUASOCKET_FILENAME="v3.0-rc1.zip"
LUASOCKET_URL="https://github.com/diegonehab/luasocket/archive/$LUASOCKET_FILENAME"

LUASEC_BASENAME="luasec-0.6"
LUASEC_FILENAME="$LUASEC_BASENAME.zip"
LUASEC_URL="https://github.com/brunoos/luasec/archive/$LUASEC_FILENAME"

LFS_BASENAME="v_1_6_3"
LFS_FILENAME="$LFS_BASENAME.tar.gz"
LFS_URL="https://github.com/keplerproject/luafilesystem/archive/$LFS_FILENAME"

LPEG_BASENAME="lpeg-1.0.0"
LPEG_FILENAME="$LPEG_BASENAME.tar.gz"
LPEG_URL="http://www.inf.puc-rio.br/~roberto/lpeg/$LPEG_FILENAME"

LEXLPEG_BASENAME="scintillua_3.6.5-1"
LEXLPEG_FILENAME="$LEXLPEG_BASENAME.zip"
LEXLPEG_URL="https://foicica.com/scintillua/download/$LEXLPEG_FILENAME"

WXWIDGETSDEBUG="--disable-debug"
WXLUABUILD="MinSizeRel"

# iterate through the command line arguments
for ARG in "$@"; do
  case $ARG in
  5.2)
    BUILD_LUA=true
    BUILD_52=true
    ;;
  5.3)
    BUILD_LUA=true
    BUILD_53=true
    BUILD_FLAGS="$BUILD_FLAGS -DLUA_COMPAT_APIINTCASTS"
    ;;
  jit)
    BUILD_LUA=true
    BUILD_JIT=true
    ;;
  wxwidgets)
    BUILD_WXWIDGETS=true
    ;;
  lua)
    BUILD_LUA=true
    ;;
  wxlua)
    BUILD_WXLUA=true
    ;;
  luasec)
    BUILD_LUASEC=true
    ;;
  luasocket)
    BUILD_LUASOCKET=true
    ;;
  lfs)
    BUILD_LFS=true
    ;;
  lpeg)
    BUILD_LPEG=true
    ;;
  lexlpeg)
    BUILD_LEXLPEG=true
    ;;
  debug)
    WXWIDGETSDEBUG="--enable-debug=max"
    WXLUABUILD="Debug"
    ;;
  all)
    BUILD_WXWIDGETS=true
    BUILD_LUA=true
    BUILD_WXLUA=true
    BUILD_LUASOCKET=true
    BUILD_LUASEC=true
    BUILD_LFS=true
    BUILD_LPEG=true
    ;;
  *)
    echo "Error: invalid argument $ARG"
    exit 1
    ;;
  esac
done

# check for g++
if [ ! "$(which g++)" ]; then
  echo "Error: g++ isn't found. Please install GNU C++ compiler."
  exit 1
fi

# check for cmake
if [ ! "$(which cmake)" ]; then
  echo "Error: cmake isn't found. Please install CMake and add it to PATH."
  exit 1
fi

# check for git
if [ ! "$(which git)" ]; then
  echo "Error: git isn't found. Please install console GIT client."
  exit 1
fi

# check for wget
if [ ! "$(which wget)" ]; then
  echo "Error: wget isn't found. Please install GNU Wget."
  exit 1
fi

# create the installation directory
mkdir -p "$INSTALL_DIR" || { echo "Error: cannot create directory $INSTALL_DIR"; exit 1; }

LUAV="51"
LUAS=""
LUA_BASENAME="lua-5.1.5"

if [ $BUILD_52 ]; then
  LUAV="52"
  LUAS=$LUAV
  LUA_BASENAME="lua-5.2.4"
fi

LUA_FILENAME="$LUA_BASENAME.tar.gz"
LUA_URL="http://www.lua.org/ftp/$LUA_FILENAME"

if [ $BUILD_53 ]; then
  LUAV="53"
  LUAS=$LUAV
  LUA_BASENAME="lua-5.3.1"
  LUA_FILENAME="$LUA_BASENAME.tar.gz"
  LUA_URL="http://www.lua.org/ftp/$LUA_FILENAME"
fi

if [ $BUILD_JIT ]; then
  LUA_BASENAME="luajit"
  LUA_URL="https://github.com/pkulchenko/luajit.git"
fi

# build Lua
if [ $BUILD_LUA ]; then
  if [ $BUILD_JIT ]; then
    git clone "$LUA_URL" "$LUA_BASENAME"
    (cd "$LUA_BASENAME"; git checkout v2.0.4)
  else
    wget -c "$LUA_URL" -O "$LUA_FILENAME" || { echo "Error: failed to download Lua"; exit 1; }
    tar -xzf "$LUA_FILENAME"
  fi
  cd "$LUA_BASENAME"

  if [ $BUILD_JIT ]; then
    make BUILDMODE=dynamic LUAJIT_SO=liblua.dylib TARGET_DYLIBPATH=liblua.dylib CC="gcc -m32" CCOPT="$MACOSX_FLAGS -DLUAJIT_ENABLE_LUA52COMPAT" || { echo "Error: failed to build Lua"; exit 1; }
    make install PREFIX="$INSTALL_DIR"
    cp "src/luajit" "$INSTALL_DIR/bin/lua"
    cp "src/liblua.dylib" "$INSTALL_DIR/lib"
  else
    sed -i "" 's/PLATS=/& macosx_dylib/' Makefile

    # -O1 fixes this issue with for Lua 5.2 with i386: http://lua-users.org/lists/lua-l/2013-05/msg00070.html
    printf "macosx_dylib:\n" >> src/Makefile
    printf "\t\$(MAKE) LUA_A=\"liblua$LUAS.dylib\" AR=\"\$(CC) -dynamiclib $MACOSX_FLAGS -o\" RANLIB=\"strip -u -r\" \\\\\n" >> src/Makefile
    printf "\tMYCFLAGS=\"-O1 -DLUA_USE_LINUX $MACOSX_FLAGS\" MYLDFLAGS=\"$MACOSX_FLAGS\" MYLIBS=\"-lreadline\" lua\n" >> src/Makefile
    printf "\t\$(MAKE) MYCFLAGS=\"-DLUA_USE_LINUX $MACOSX_FLAGS\" MYLDFLAGS=\"$MACOSX_FLAGS\" luac\n" >> src/Makefile
    make macosx_dylib || { echo "Error: failed to build Lua"; exit 1; }
    make install INSTALL_TOP="$INSTALL_DIR"
    mv "$INSTALL_DIR/bin/lua" "$INSTALL_DIR/bin/lua$LUAS"
    cp src/liblua$LUAS.dylib "$INSTALL_DIR/lib"
  fi
  strip -u -r "$INSTALL_DIR/bin/lua$LUAS"
  [ -f "$INSTALL_DIR/lib/liblua$LUAS.dylib" ] || { echo "Error: liblua$LUAS.dylib isn't found"; exit 1; }
  cd ..
  rm -rf "$LUA_FILENAME" "$LUA_BASENAME"
fi

# build lexlpeg
if [ $BUILD_LEXLPEG ]; then
  # need wxwidgets/Scintilla and lua files
  git clone "$WXWIDGETS_URL" "$WXWIDGETS_BASENAME" || { echo "Error: failed to get wxWidgets"; exit 1; }
  wget --no-check-certificate -c "$LEXLPEG_URL" -O "$LEXLPEG_FILENAME" || { echo "Error: failed to download LexLPeg"; exit 1; }
  unzip "$LEXLPEG_FILENAME"
  cd "$LEXLPEG_BASENAME"

  mkdir -p "$INSTALL_DIR/lib/lua/$LUAD/"
  g++ $BUILD_FLAGS -o "$INSTALL_DIR/lib/lua/$LUAD/lexlpeg.dylib" \
    "-I../$WXWIDGETS_BASENAME/src/stc/scintilla/include" "-I../$WXWIDGETS_BASENAME/src/stc/scintilla/lexlib/" \
    -DSCI_LEXER -DLPEG_LEXER -DLPEG_LEXER_EXTERNAL \
    LexLPeg.cxx ../$WXWIDGETS_BASENAME/src/stc/scintilla/lexlib/{PropSetSimple.cxx,WordList.cxx,LexerModule.cxx,LexerSimple.cxx,LexerBase.cxx,Accessor.cxx}

  [ -f "$INSTALL_DIR/lib/lua/$LUAD/lexlpeg.dylib" ] || { echo "Error: LexLPeg.dylib isn't found"; exit 1; }

  cd ..
  rm -rf "$WXWIDGETS_BASENAME" "$LEXLPEG_BASENAME" "$LEXLPEG_FILENAME"
fi

# build wxWidgets
if [ $BUILD_WXWIDGETS ]; then
  git clone "$WXWIDGETS_URL" "$WXWIDGETS_BASENAME" || { echo "Error: failed to get wxWidgets"; exit 1; }
  cd "$WXWIDGETS_BASENAME"
  MINSDK=""
  if [ -d $MACOSX_SDK_PATH ]; then
    MINSDK="--with-macosx-sdk=$MACOSX_SDK_PATH"
  fi
  ./configure --prefix="$INSTALL_DIR" $WXWIDGETSDEBUG --disable-shared --enable-unicode \
    --enable-compat28 \
    --with-libjpeg=builtin --with-libpng=builtin --with-libtiff=no --with-expat=no \
    --with-zlib=builtin --disable-richtext \
    --enable-macosx_arch=$MACOSX_ARCH --with-macosx-version-min=$MACOSX_VERSION $MINSDK \
    --with-osx_cocoa CFLAGS="-Os" CXXFLAGS="-Os"

  PATTERN="defined( __WXMAC__ )\$"
  if [ "$(grep -c "$PATTERN" src/aui/tabart.cpp)" -ne "1" ]; then
    echo "Incorrect pattern for a fix in tabart.cpp."
    exit 1
  fi
  sed -i "" "s/$PATTERN/0/" src/aui/tabart.cpp

  make $MAKEFLAGS || { echo "Error: failed to build wxWidgets"; exit 1; }
  make install
  cd ..
  rm -rf "$WXWIDGETS_BASENAME"
fi

# build wxLua
if [ $BUILD_WXLUA ]; then
  git clone "$WXLUA_URL" "$WXLUA_BASENAME" || { echo "Error: failed to get wxWidgets"; exit 1; }
  cd "$WXLUA_BASENAME/wxLua"
  git checkout wxwidgets311

  MINSDK=""
  if [ -d $MACOSX_SDK_PATH ]; then
    MINSDK="CMAKE_OSX_SYSROOT=$MACOSX_SDK_PATH"
  fi
  # the following patches wxlua source to fix live coding support in wxlua apps
  # http://www.mail-archive.com/wxlua-users@lists.sourceforge.net/msg03225.html
  sed -i "" 's/\(m_wxlState = wxLuaState(wxlState.GetLuaState(), wxLUASTATE_GETSTATE|wxLUASTATE_ROOTSTATE);\)/\/\/ removed by ZBS build process \/\/ \1/' modules/wxlua/wxlcallb.cpp

  # remove "Unable to call an unknown method..." error as it leads to a leak
  # see http://sourceforge.net/p/wxlua/mailman/message/34629522/ for details
  sed -i "" -e '/Unable to call an unknown method/{N' -e 's/.*/    \/\/ removed by ZBS build process/' -e '}' modules/wxlua/wxlbind.cpp

  cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" -DCMAKE_BUILD_TYPE=$WXLUABUILD -DBUILD_SHARED_LIBS=FALSE \
    -DCMAKE_OSX_ARCHITECTURES=$MACOSX_ARCH -DCMAKE_OSX_DEPLOYMENT_TARGET=$MACOSX_VERSION $MINSDK \
    -DCMAKE_C_COMPILER=/usr/bin/gcc -DCMAKE_CXX_COMPILER=/usr/bin/g++ -DwxWidgets_CONFIG_EXECUTABLE="$INSTALL_DIR/bin/wx-config" \
    -DwxWidgets_COMPONENTS="stc;gl;html;aui;adv;core;net;base" \
    -DwxLuaBind_COMPONENTS="stc;gl;html;aui;adv;core;net;base" -DwxLua_LUA_LIBRARY_USE_BUILTIN=FALSE \
    -DwxLua_LUA_INCLUDE_DIR="$INSTALL_DIR/include" -DwxLua_LUA_LIBRARY="$INSTALL_DIR/lib/liblua.dylib" .
  (cd modules/luamodule; make $MAKEFLAGS) || { echo "Error: failed to build wxLua"; exit 1; }
  (cd modules/luamodule; make install)
  [ -f "$INSTALL_DIR/lib/libwx.dylib" ] || { echo "Error: libwx.dylib isn't found"; exit 1; }
  [ "$WXLUABUILD" != "Debug" ] && strip -u -r "$INSTALL_DIR/lib/libwx.dylib"
  cd ../..
  rm -rf "$WXLUA_BASENAME"
fi

# build LuaSocket
if [ $BUILD_LUASOCKET ]; then
  wget --no-check-certificate -c "$LUASOCKET_URL" -O "$LUASOCKET_FILENAME" || { echo "Error: failed to download LuaSocket"; exit 1; }
  unzip "$LUASOCKET_FILENAME"
  cd "$LUASOCKET_BASENAME"
  mkdir -p "$INSTALL_DIR/lib/lua/$LUAV/"{mime,socket}
  gcc $BUILD_FLAGS -o "$INSTALL_DIR/lib/lua/$LUAV/mime/core.dylib" src/mime.c \
    || { echo "Error: failed to build LuaSocket"; exit 1; }
  gcc $BUILD_FLAGS -o "$INSTALL_DIR/lib/lua/$LUAV/socket/core.dylib" \
    src/{auxiliar.c,buffer.c,except.c,inet.c,io.c,luasocket.c,options.c,select.c,tcp.c,timeout.c,udp.c,usocket.c} \
    || { echo "Error: failed to build LuaSocket"; exit 1; }
  strip -u -r "$INSTALL_DIR/lib/lua/$LUAV/mime/core.dylib" "$INSTALL_DIR/lib/lua/$LUAV/socket/core.dylib"
  install_name_tool -id core.dylib "$INSTALL_DIR/lib/lua/$LUAV/socket/core.dylib"
  install_name_tool -id core.dylib "$INSTALL_DIR/lib/lua/$LUAV/mime/core.dylib"
  mkdir -p "$INSTALL_DIR/share/lua/$LUAV/socket"
  cp src/{ftp.lua,http.lua,smtp.lua,tp.lua,url.lua} "$INSTALL_DIR/share/lua/$LUAV/socket"
  cp src/{ltn12.lua,mime.lua,socket.lua} "$INSTALL_DIR/share/lua/$LUAV"
  [ -f "$INSTALL_DIR/lib/lua/$LUAV/mime/core.dylib" ] || { echo "Error: mime/core.dylib isn't found"; exit 1; }
  [ -f "$INSTALL_DIR/lib/lua/$LUAV/socket/core.dylib" ] || { echo "Error: socket/core.dylib isn't found"; exit 1; }
  cd ..
  rm -rf "$LUASOCKET_FILENAME" "$LUASOCKET_BASENAME"
fi

# build lfs
if [ $BUILD_LFS ]; then
  wget --no-check-certificate -c "$LFS_URL" -O "$LFS_FILENAME" || { echo "Error: failed to download lfs"; exit 1; }
  tar -xzf "$LFS_FILENAME"
  mv "luafilesystem-$LFS_BASENAME" "$LFS_BASENAME"
  cd "$LFS_BASENAME/src"
  mkdir -p "$INSTALL_DIR/lib/lua/$LUAD/"
  gcc $BUILD_FLAGS -o "$INSTALL_DIR/lib/lua/$LUAD/lfs.dylib" lfs.c \
    || { echo "Error: failed to build lfs"; exit 1; }
  [ -f "$INSTALL_DIR/lib/lua/$LUAD/lfs.dylib" ] || { echo "Error: lfs.dylib isn't found"; exit 1; }
  cd ../..
  rm -rf "$LFS_FILENAME" "$LFS_BASENAME"
fi

# build lpeg
if [ $BUILD_LPEG ]; then
  wget --no-check-certificate -c "$LPEG_URL" -O "$LPEG_FILENAME" || { echo "Error: failed to download lpeg"; exit 1; }
  tar -xzf "$LPEG_FILENAME"
  cd "$LPEG_BASENAME"
  mkdir -p "$INSTALL_DIR/lib/lua/$LUAD/"
  gcc $BUILD_FLAGS -o "$INSTALL_DIR/lib/lua/$LUAD/lpeg.dylib" lptree.c lpvm.c lpcap.c lpcode.c lpprint.c \
    || { echo "Error: failed to build lpeg"; exit 1; }
  [ -f "$INSTALL_DIR/lib/lua/$LUAD/lpeg.dylib" ] || { echo "Error: lpeg.dylib isn't found"; exit 1; }
  cd ..
  rm -rf "$LPEG_FILENAME" "$LPEG_BASENAME"
fi

# build LuaSec
if [ $BUILD_LUASEC ]; then
  # build LuaSec
  wget --no-check-certificate -c "$LUASEC_URL" -O "$LUASEC_FILENAME" || { echo "Error: failed to download LuaSec"; exit 1; }
  unzip "$LUASEC_FILENAME"
  # the folder in the archive is "luasec-luasec-....", so need to fix
  mv "luasec-$LUASEC_BASENAME" $LUASEC_BASENAME
  cd "$LUASEC_BASENAME"
  gcc $BUILD_FLAGS -o "$INSTALL_DIR/lib/lua/$LUAD/ssl.dylib" \
    src/luasocket/{timeout.c,buffer.c,io.c,usocket.c} src/{context.c,x509.c,ssl.c} -Isrc \
    -lssl -lcrypto \
    || { echo "Error: failed to build LuaSec"; exit 1; }
  cp src/ssl.lua "$INSTALL_DIR/share/lua/$LUAD"
  mkdir -p "$INSTALL_DIR/share/lua/$LUAD/ssl"
  cp src/https.lua "$INSTALL_DIR/share/lua/$LUAD/ssl"
  [ -f "$INSTALL_DIR/lib/lua/$LUAD/ssl.dylib" ] || { echo "Error: ssl.dylib isn't found"; exit 1; }
  strip -u -r "$INSTALL_DIR/lib/lua/$LUAD/ssl.dylib"
  cd ..
  rm -rf "$LUASEC_FILENAME" "$LUASEC_BASENAME"
fi

# now copy the compiled dependencies to ZBS binary directory
mkdir -p "$BIN_DIR" || { echo "Error: cannot create directory $BIN_DIR"; exit 1; }

if [ $BUILD_LUA ]; then
  mkdir -p "$BIN_DIR/lua.app/Contents/MacOS"
  cp "$INSTALL_DIR/bin/lua$LUAS" "$BIN_DIR/lua.app/Contents/MacOS"
  cp "$INSTALL_DIR/bin/lua$LUAS" "$INSTALL_DIR/lib/liblua$LUAS.dylib" "$BIN_DIR"
fi
[ $BUILD_WXLUA ] && cp "$INSTALL_DIR/lib/libwx.dylib" "$BIN_DIR/clibs"
[ $BUILD_LFS ] && cp "$INSTALL_DIR/lib/lua/$LUAD/lfs.dylib" "$BIN_DIR/clibs$LUAS"
[ $BUILD_LPEG ] && cp "$INSTALL_DIR/lib/lua/$LUAD/lpeg.dylib" "$BIN_DIR/clibs$LUAS"
[ $BUILD_LEXLPEG ] && cp "$INSTALL_DIR/lib/lua/$LUAD/lexlpeg.dylib" "$BIN_DIR/clibs$LUAS"

if [ $BUILD_LUASOCKET ]; then
  mkdir -p "$BIN_DIR/clibs$LUAS/"{mime,socket}
  cp "$INSTALL_DIR/lib/lua/$LUAV/mime/core.dylib" "$BIN_DIR/clibs$LUAS/mime"
  cp "$INSTALL_DIR/lib/lua/$LUAV/socket/core.dylib" "$BIN_DIR/clibs$LUAS/socket"
fi

if [ $BUILD_LUASEC ]; then
  cp "$INSTALL_DIR/lib/lua/$LUAD/ssl.dylib" "$BIN_DIR/clibs$LUAS"
  cp "$INSTALL_DIR/share/lua/$LUAD/ssl.lua" ../lualibs
  cp "$INSTALL_DIR/share/lua/$LUAD/ssl/https.lua" ../lualibs/ssl
fi

echo "*** Build has been successfully completed ***"
exit 0
