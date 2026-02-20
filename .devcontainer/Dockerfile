FROM gmeligio/flutter-android:3.27.4

# Accept Android SDK licenses
RUN yes | flutter doctor --android-licenses 2>/dev/null || true

# Enable required platforms
RUN flutter config --enable-android
RUN flutter config --enable-linux-desktop

# Pre-cache Flutter dependencies
RUN flutter precache --android

# Install additional tools
USER root
RUN apt-get update && apt-get install -y --no-install-recommends     adb     && rm -rf /var/lib/apt/lists/*
USER flutter

WORKDIR /workspace
