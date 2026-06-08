# profile.d/android.sh -- Android SDK.
# shellcheck shell=bash
export ANDROID_HOME="$HOME/Android/Sdk"
path::append "$ANDROID_HOME/cmdline-tools/latest/bin"
path::append "$ANDROID_HOME/emulator"
path::append "$ANDROID_HOME/platform-tools"
