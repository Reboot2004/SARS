FROM ghcr.io/cirruslabs/flutter:3.27.0

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# Install necessary dependencies
RUN apt-get update && apt-get install -y wget gnupg2

# Download and install Google Chrome
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
RUN sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
RUN apt-get update && apt-get install -y google-chrome-stable

# Install Xvfb
RUN apt-get install -y xvfb

# Set DISPLAY
ENV DISPLAY=:99

# Start Xvfb
RUN Xvfb :99 -screen 0 1024x768x24 &

# Expose port
EXPOSE 8080

# Run Flutter (using Chrome)
CMD ["flutter", "run", "-d", "chrome", "--web-port", "8080", "--no-sandbox"]