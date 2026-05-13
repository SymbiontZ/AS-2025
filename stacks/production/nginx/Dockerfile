FROM nginx:latest

# Install iproute2 for static route setup at container start
RUN apt-get update && apt-get install -y iproute2 && rm -rf /var/lib/apt/lists/*
