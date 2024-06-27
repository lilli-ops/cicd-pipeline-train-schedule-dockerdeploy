# Use an official Node.js runtime as a parent image
FROM node:18-buster

# Set environment variables for nvm and npm
ENV NVM_DIR /root/.nvm
ENV NPM_CONFIG_CACHE /root/.npm
ENV JAVA_HOME /usr/lib/jvm/java-11-openjdk-11.0.23.0.9-2.el7_9.x86_64
ENV PATH $JAVA_HOME/bin:$PATH

# Install required packages and Java 11
USER root
RUN apt-get update && \
    apt-get install -y wget gnupg curl && \
    wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | apt-key add - && \
    echo "deb https://packages.adoptium.net/artifactory/deb focal main" > /etc/apt/sources.list.d/adoptium.list && \
    apt-get update && \
    apt-get install -y temurin-11-jdk

# Install nvm and Node.js
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash && \
    . $NVM_DIR/nvm.sh && \
    nvm install 18.17.0 && \
    nvm use 18.17.0 && \
    npm install -g npm@latest

# Set the working directory to /usr/src/app
WORKDIR /usr/src/app

# Copy package.json and package-lock.json to the working directory
COPY package*.json ./

# Install any needed packages
RUN npm install

# Copy the rest of the application source code to the working directory
COPY . .

# Ensure the correct permissions for all files
RUN chown -R root:root /usr/src/app $NVM_DIR $NPM_CONFIG_CACHE && \
    chmod -R 777 /usr/src/app $NVM_DIR $NPM_CONFIG_CACHE

# Make port 8080 available to the world outside this container
EXPOSE 8080

# Define environment variable
ENV NODE_ENV production

# Run the app
CMD [ "npm", "start" ]
