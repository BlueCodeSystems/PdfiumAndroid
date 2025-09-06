APP_STL := c++_shared
APP_CPPFLAGS += -fexceptions -std=c++11

#For ANativeWindow support
APP_PLATFORM = android-28

APP_ABI :=  armeabi-v7a \
            arm64-v8a \
            x86 \
            x86_64
