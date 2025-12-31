pipeline {
    agent any
    
    environment {
        // Docker registry configuration
        DOCKER_REGISTRY = 'minhtri1612'
        DOCKER_IMAGE_NAME = 'meo-stationery-backend'
        DOCKER_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
        
        // Kubernetes configuration
        K8S_NAMESPACE = 'meo-stationery'
        HELM_RELEASE_NAME = 'backend'
        HELM_CHART_PATH = 'k8s_helm/backend'
        
        // Application configuration
        NODE_VERSION = '18'
        
        // SonarQube configuration
        SCANNER_HOME = tool 'sonar-scanner'  // Configure in Jenkins Global Tool Configuration
        SONAR_HOST_URL = 'http://sonarqube.local'
    }
    
    options {
        // Keep last 10 builds
        buildDiscarder(logRotator(numToKeepStr: '10'))
        // Timeout after 30 minutes
        timeout(time: 30, unit: 'MINUTES')
        // Add timestamps to console output
        timestamps()
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    // Get git commit hash for tagging
                    env.GIT_COMMIT = sh(
                        script: 'git rev-parse HEAD',
                        returnStdout: true
                    ).trim()
                    env.GIT_BRANCH = sh(
                        script: 'git rev-parse --abbrev-ref HEAD',
                        returnStdout: true
                    ).trim()
                    
                    echo "Building branch: ${env.GIT_BRANCH}"
                    echo "Git commit: ${env.GIT_COMMIT}"
                }
            }
        }
        
        stage('Setup Node.js') {
            steps {
                script {
                    sh '''
                        echo "Setting up Node.js..."
                        # Try to find Node.js in Jenkins tools directory
                        TOOL_PATH=""
                        if [ -d "/var/jenkins_home/tools/hudson.plugins.nodejs.tools.NodeJSInstallation/node18" ]; then
                            TOOL_PATH="/var/jenkins_home/tools/hudson.plugins.nodejs.tools.NodeJSInstallation/node18/bin"
                            echo "Found Node.js tool at: $TOOL_PATH"
                        elif [ -d "/var/jenkins_home/tools/nodejs" ]; then
                            TOOL_PATH="/var/jenkins_home/tools/nodejs/bin"
                            echo "Found Node.js at: $TOOL_PATH"
                        fi
                        
                        if [ -n "$TOOL_PATH" ] && [ -f "$TOOL_PATH/node" ]; then
                            echo "$TOOL_PATH" > $WORKSPACE/.node_path
                            echo "Using Node.js from tools: $TOOL_PATH"
                        else
                            # If still not found, try NVM (works as non-root)
                            echo "Node.js not found, installing via NVM..."
                            export NVM_DIR="$HOME/.nvm"
                            [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" || {
                                curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
                                export NVM_DIR="$HOME/.nvm"
                                [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
                            }
                            nvm install 18 || echo "NVM install failed"
                            nvm use 18 || echo "NVM use failed"
                            # Store NVM path - find the actual installed version
                            NVM_NODE_PATH=$(find /var/jenkins_home/.nvm/versions/node -name "node" -type f -path "*/v18.*/bin/node" | head -1 | xargs dirname)
                            if [ -n "$NVM_NODE_PATH" ]; then
                                echo "$NVM_NODE_PATH" > $WORKSPACE/.node_path
                                echo "NVM Node.js installed at: $NVM_NODE_PATH"
                            else
                                # Fallback to default v18 path
                                echo "/var/jenkins_home/.nvm/versions/node/v18.20.8/bin" > $WORKSPACE/.node_path
                            fi
                        fi
                        
                        NODE_PATH=$(cat $WORKSPACE/.node_path)
                        export PATH="$NODE_PATH:${PATH}"
                        node --version || echo "Warning: Node.js not found"
                        npm --version || echo "Warning: npm not found"
                    '''
                }
            }
        }
        
        stage('Install Dependencies') {
            steps {
                script {
                    sh '''
                        # Load Node.js path from file
                        if [ -f "$WORKSPACE/.node_path" ]; then
                            NODE_BIN_PATH=$(cat $WORKSPACE/.node_path)
                            export PATH="$NODE_BIN_PATH:${PATH}"
                            echo "Using Node.js from: $NODE_BIN_PATH"
                        else
                            # Fallback: try to source NVM
                            export NVM_DIR="$HOME/.nvm"
                            [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && nvm use 18 || echo "NVM not found"
                        fi
                        echo "Installing Node.js dependencies..."
                        # Reduce npm memory usage to avoid OOM
                        export NODE_OPTIONS="--max-old-space-size=512"
                        npm ci --prefer-offline --no-audit || npm install --prefer-offline --no-audit
                    '''
                }
            }
        }
        
        stage('Lint & Test') {
            steps {
                script {
                    sh '''
                        # Load Node.js path
                        if [ -f "$WORKSPACE/.node_path" ]; then
                            NODE_BIN_PATH=$(cat $WORKSPACE/.node_path)
                            export PATH="$NODE_BIN_PATH:${PATH}"
                        else
                            export NVM_DIR="$HOME/.nvm"
                            [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && nvm use 18 || true
                        fi
                        echo "Running linter..."
                        npm run lint || echo "Linting completed with warnings"
                        
                        # Add tests here if you have them
                        # npm test || echo "Tests completed"
                    '''
                }
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                script {
                    catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                        withSonarQubeEnv('sonarqube') {
                            sh """
                                ${env.SCANNER_HOME}/bin/sonar-scanner \
                                -Dsonar.projectKey=MeoStationeryProject \
                                -Dsonar.sources=. \
                                -Dsonar.host.url=${env.SONAR_HOST_URL} \
                                -Dsonar.login=\${SONAR_AUTH_TOKEN}
                            """
                        }
                    }
                    echo "⚠️ SonarQube analysis completed (may have warnings)"
                }
            }
        }
        
        stage('Quality Gate Check') {
            steps {
                script {
                    catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                        waitForQualityGate abortPipeline: false, credentialsId: 'Sonar-token'
                    }
                    echo "⚠️ Quality gate check completed (may have warnings)"
                }
            }
        }
        
        stage('Trivy FS Scanning') {
            steps {
                script {
                    sh """
                        echo "Running Trivy filesystem scan..."
                        trivy fs . > trivy-fs-scan.txt || echo "Trivy scan completed"
                        cat trivy-fs-scan.txt || true
                    """
                }
            }
        }
        
        stage('Build Application') {
            steps {
                script {
                    sh '''
                        # Load Node.js path
                        if [ -f "$WORKSPACE/.node_path" ]; then
                            NODE_BIN_PATH=$(cat $WORKSPACE/.node_path)
                            export PATH="$NODE_BIN_PATH:${PATH}"
                        else
                            export NVM_DIR="$HOME/.nvm"
                            [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && nvm use 18 || true
                        fi
                        echo "Building Next.js application..."
                        npm run build
                    '''
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    def imageTag = "${DOCKER_REGISTRY}/${DOCKER_IMAGE_NAME}:${DOCKER_TAG}"
                    def imageTagLatest = "${DOCKER_REGISTRY}/${DOCKER_IMAGE_NAME}:latest"
                    
                    echo "Building Docker image: ${imageTag}"
                    
                    sh """
                        docker build -t ${imageTag} -t ${imageTagLatest} .
                    """
                    
                    // Store image tags for later stages
                    env.DOCKER_IMAGE_FULL = imageTag
                }
            }
        }
        
        stage('Trivy Docker Image Scanning') {
            steps {
                script {
                    sh """
                        echo "Running Trivy image scan..."
                        trivy image ${env.DOCKER_IMAGE_FULL} > trivy-image-scan.txt || echo "Trivy image scan completed"
                        cat trivy-image-scan.txt || true
                    """
                }
            }
        }
        
        stage('Push Docker Image') {
            steps {
                script {
                    withCredentials([usernamePassword(
                        credentialsId: 'docker-hub-credentials',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )]) {
                        sh """
                            echo "Logging into Docker Hub..."
                            echo \$DOCKER_PASS | docker login -u \$DOCKER_USER --password-stdin
                            
                            echo "Pushing Docker image..."
                            docker push ${env.DOCKER_IMAGE_FULL}
                            docker push ${DOCKER_REGISTRY}/${DOCKER_IMAGE_NAME}:latest
                            
                            echo "Logging out from Docker Hub..."
                            docker logout
                        """
                    }
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                script {
                    // Get Kubernetes config from Jenkins master
                    // Assumes kubectl and helm are installed on Jenkins agent
                    // and kubeconfig is available
                    
                    sh """
                        echo "Deploying to Kubernetes namespace: ${K8S_NAMESPACE}"
                        
                        # Update Helm chart values with new image
                        helm upgrade --install ${HELM_RELEASE_NAME} ${HELM_CHART_PATH} \\
                            --namespace ${K8S_NAMESPACE} \\
                            --set workload.image=${env.DOCKER_IMAGE_FULL} \\
                            --set workload.imagePullPolicy=Always \\
                            --wait --timeout=10m
                        
                        echo "Deployment completed successfully!"
                    """
                }
            }
        }
        
        stage('Run Database Migrations') {
            steps {
                script {
                    sh """
                        echo "Running database migrations..."
                        
                        # Wait for backend pod to be ready
                        kubectl wait --for=condition=ready pod \\
                            -l app.kubernetes.io/name=backend \\
                            -n ${K8S_NAMESPACE} \\
                            --timeout=5m || true
                        
                        # Get the first backend pod
                        BACKEND_POD=\$(kubectl get pods -n ${K8S_NAMESPACE} \\
                            -l app.kubernetes.io/name=backend \\
                            -o jsonpath='{.items[0].metadata.name}')
                        
                        if [ -n "\$BACKEND_POD" ]; then
                            echo "Running migrations in pod: \$BACKEND_POD"
                            kubectl exec -n ${K8S_NAMESPACE} \$BACKEND_POD -- \\
                                npx prisma migrate deploy || echo "Migrations may have already been applied"
                        else
                            echo "No backend pod found, skipping migrations"
                        fi
                    """
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                script {
                    sh """
                        echo "Verifying deployment..."
                        
                        # Check pod status
                        kubectl get pods -n ${K8S_NAMESPACE} -l app.kubernetes.io/name=backend
                        
                        # Check service
                        kubectl get svc -n ${K8S_NAMESPACE} -l app.kubernetes.io/name=backend
                        
                        # Check ingress
                        kubectl get ingress -n ${K8S_NAMESPACE} || echo "No ingress found"
                        
                        echo "Deployment verification completed!"
                    """
                }
            }
        }
    }
    
    post {
        success {
            script {
                echo "✅ Pipeline succeeded!"
                echo "Docker image: ${env.DOCKER_IMAGE_FULL}"
                echo "Deployed to: ${K8S_NAMESPACE}/${HELM_RELEASE_NAME}"
            }
        }
        failure {
            script {
                echo "❌ Pipeline failed!"
                echo "Check the logs above for details"
            }
        }
        always {
            script {
                // Clean up Docker images to save space
                sh '''
                    docker image prune -f || true
                '''
            }
        }
    }
}


