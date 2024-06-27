pipeline {
    agent any

    environment {
        IMAGE_NAME = 'custom-node-java11:latest'
        NVM_DIR = "/root/.nvm"
        NPM_CONFIG_CACHE = "/root/.npm"
        JAVA_HOME = "/usr/lib/jvm/java-11-openjdk-11.0.23.0.9-2.el7_9.x86_64"
        PATH = "$JAVA_HOME/bin:$PATH"
    }

    stages {
        stage('Build Docker Image') {
            steps {
                script {
                    // Create Dockerfile
                    writeFile file: 'Dockerfile', text: '''
                    FROM node:18-buster

                    # Set environment variables for nvm and npm
                    ENV NVM_DIR /root/.nvm
                    ENV NPM_CONFIG_CACHE /root/.npm
                    ENV JAVA_HOME /usr/lib/jvm/java-11-openjdk-11.0.23.0.9-2.el7_9.x86_64
                    ENV PATH $JAVA_HOME/bin:$PATH

                    # Add the AdoptOpenJDK repository and install Java 11
                    USER root
                    RUN apt-get update && \
                        apt-get install -y wget gnupg && \
                        wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | apt-key add - && \
                        echo "deb https://packages.adoptium.net/artifactory/deb focal main" > /etc/apt/sources.list.d/adoptium.list && \
                        apt-get update && \
                        apt-get install -y temurin-11-jdk curl

                    # Install nvm and Node.js
                    RUN mkdir -p $NVM_DIR && \
                        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash && \
                        . $NVM_DIR/nvm.sh && \
                        nvm install 18.17.0 && \
                        nvm use 18.17.0 && \
                        npm install -g npm@latest

                    # Set the working directory to /usr/src/app
                    WORKDIR /usr/src/app

                    # Copy package.json and package-lock.json to the working directory
                    COPY package*.json ./

                    # Ensure the correct permissions for package files
                    RUN chown -R root:root /usr/src/app $NVM_DIR $NPM_CONFIG_CACHE && \
                        chmod -R 777 /usr/src/app $NVM_DIR $NPM_CONFIG_CACHE

                    # Install any needed packages
                    RUN npm install

                    # Copy the rest of the application source code to the working directory
                    COPY . .

                    # Ensure the correct permissions for all files
                    RUN chown -R root:root /usr/src/app && chmod -R 777 /usr/src/app

                    # Make port 8080 available to the world outside this container
                    EXPOSE 8080

                    # Define environment variable
                    ENV NODE_ENV production

                    # Run the app
                    CMD [ "npm", "start" ]
                    '''

                    // Build Docker image
                    sh 'docker build -t $IMAGE_NAME .'
                }
            }
        }

        stage('Run Setup') {
            agent {
                docker {
                    image "${env.IMAGE_NAME}"
                    args '-u root -p 8081:8080'
                }
            }
            steps {
                script {
                    // Install nvm and npm
                    sh '''
                        export NVM_DIR="/root/.nvm"
                        export NPM_CONFIG_CACHE="/root/.npm"
                        mkdir -p $NVM_DIR
                        mkdir -p $NPM_CONFIG_CACHE
                        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
                        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
                        nvm install 18.17.0
                        nvm use 18.17.0
                        npm install -g npm@latest
                        chown -R root:root $NVM_DIR $NPM_CONFIG_CACHE && chmod -R 777 $NVM_DIR $NPM_CONFIG_CACHE && \
                        chown -R 996:993 /root/.npm && chmod -R 777 /root/.npm
                    '''
                }
            }
        }

        stage('Build') {
            steps {
                echo 'Running build automation'
                sh './gradlew build --no-daemon'
                archiveArtifacts artifacts: 'dist/trainSchedule.zip'
            }
        }

        stage('Push Docker Image') {
            when {
                branch 'master'
            }
            steps {
                script {
                    docker.withRegistry('https://registry.hub.docker.com', 'docker_hub_login') {
                        sh 'docker tag $IMAGE_NAME lilli-ops/train-schedule:${env.BUILD_NUMBER}'
                        sh 'docker push lilli-ops/train-schedule:${env.BUILD_NUMBER}'
                        sh 'docker push lilli-ops/train-schedule:latest'
                    }
                }
            }
        }

        stage('DeployToProduction') {
            when {
                branch 'master'
            }
            steps {
                input 'Deploy to Production?'
                milestone(1)
                withCredentials([usernamePassword(credentialsId: 'webserver_login', usernameVariable: 'USERNAME', passwordVariable: 'USERPASS')]) {
                    script {
                        sh "sshpass -p '$USERPASS' ssh -o StrictHostKeyChecking=no $USERNAME@$prod_ip \"docker pull lilli-ops/train-schedule:${env.BUILD_NUMBER}\""
                        try {
                            sh "sshpass -p '$USERPASS' ssh -o StrictHostKeyChecking=no $USERNAME@$prod_ip \"docker stop train-schedule\""
                            sh "sshpass -p '$USERPASS' ssh -o StrictHostKeyChecking=no $USERNAME@$prod_ip \"docker rm train-schedule\""
                        } catch (err) {
                            echo "caught error: ${err}"
                        }
                        sh "sshpass -p '$USERPASS' ssh -o StrictHostKeyChecking=no $USERNAME@$prod_ip \"docker run --restart always --name train-schedule -p 8080:8080 -d willbla/train-schedule:${env.BUILD_NUMBER}\""
                    }
                }
            }
        }
    }
}
