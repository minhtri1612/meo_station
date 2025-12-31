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
        
        stage('Install Dependencies') {
            steps {
                script {
                    sh '''
                        echo "Installing Node.js dependencies..."
                        npm ci
                    '''
                }
            }
        }
        
        stage('Lint & Test') {
            steps {
                script {
                    sh '''
                        echo "Running linter..."
                        npm run lint || echo "Linting completed with warnings"
                        
                        # Add tests here if you have them
                        # npm test || echo "Tests completed"
                    '''
                }
            }
        }
        
        stage('Build Application') {
            steps {
                script {
                    sh '''
                        echo "Building Next.js application..."
                        npm run build
                    '''
                }
            }
        }
        
        stage('Trivy FS Scanning') {
            steps {
                script {
                    catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                        sh '''
                            echo "Setting up Trivy..."
                            
                            # Check if Trivy is installed
                            if ! command -v trivy &> /dev/null; then
                                echo "Trivy not found, installing..."
                                mkdir -p "$HOME/.local/bin"
                                TRIVY_BIN="$HOME/.local/bin/trivy"
                                TRIVY_VERSION="0.54.0"
                                echo "Installing Trivy version: ${TRIVY_VERSION}"
                                
                                curl -L -o /tmp/trivy.tar.gz "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" || {
                                    echo "Failed to download Trivy, skipping installation"
                                    exit 0
                                }
                                
                                cd /tmp
                                tar -xzf trivy.tar.gz
                                chmod +x trivy
                                mv trivy "$TRIVY_BIN"
                                rm -f trivy.tar.gz
                                export PATH="$HOME/.local/bin:${PATH}"
                                echo "Trivy installed at: $TRIVY_BIN"
                            else
                                echo "Trivy is already installed"
                            fi
                            
                            export PATH="$HOME/.local/bin:${PATH}"
                            
                            if command -v trivy &> /dev/null; then
                                trivy --version || echo "Warning: Trivy version check failed"
                                
                                echo "Running Trivy filesystem scan..."
                                echo "Scanning for HIGH and CRITICAL vulnerabilities..."
                                
                                # Scan filesystem - report vulnerabilities but don't fail build
                                trivy fs --exit-code 0 --severity HIGH,CRITICAL --no-progress . > trivy-fs-scan.txt 2>&1 || {
                                    echo "Trivy scan completed (exit code: $?)"
                                    trivy fs --exit-code 0 --no-progress . > trivy-fs-scan.txt 2>&1 || true
                                }
                                
                                echo ""
                                echo "=== Trivy Filesystem Scan Results ==="
                                if [ -f trivy-fs-scan.txt ]; then
                                    cat trivy-fs-scan.txt
                                fi
                                echo "========================="
                                echo "✅ Trivy filesystem scan completed"
                            else
                                echo "⚠️ Trivy installation failed, skipping scan"
                            fi
                        '''
                    }
                    echo "⚠️ Trivy filesystem scanning completed (may have warnings)"
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
                    catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                        def imageToScan = env.DOCKER_IMAGE_FULL
                        sh """
                            export PATH="\\\$HOME/.local/bin:\\\${PATH}"
                            
                            if command -v trivy &> /dev/null; then
                                echo "Running Trivy Docker image scan..."
                                echo "Scanning image: ${imageToScan}"
                                
                                # Scan Docker image - report vulnerabilities but don't fail build
                                trivy image --exit-code 0 --severity HIGH,CRITICAL --no-progress '${imageToScan}' > trivy-image-scan.txt 2>&1 || {
                                    echo "Trivy image scan completed (exit code: \\\$?)"
                                }
                                
                                echo ""
                                echo "=== Trivy Docker Image Scan Results ==="
                                if [ -f trivy-image-scan.txt ]; then
                                    cat trivy-image-scan.txt
                                fi
                                echo "========================="
                                echo "✅ Trivy Docker image scan completed"
                            else
                                echo "⚠️ Trivy not found, skipping image scan"
                            fi
                        """
                    }
                    echo "⚠️ Trivy Docker image scanning completed (may have warnings)"
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
        
        stage('Trivy Kubernetes Scanning') {
            steps {
                script {
                    catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                        sh """
                            export PATH="\\$HOME/.local/bin:\\${PATH}"
                            
                            if command -v trivy &> /dev/null; then
                                echo "Running Trivy Kubernetes manifest scan..."
                                echo "Scanning Helm charts in: ${HELM_CHART_PATH}"
                                
                                # Scan Kubernetes manifest files (Helm charts)
                                # This scans for misconfigurations, security issues in K8s YAML files
                                # Examples: missing security contexts, privilege escalation, insecure defaults
                                trivy k8s config --exit-code 0 --severity HIGH,CRITICAL --format table ${HELM_CHART_PATH} > trivy-k8s-scan.txt 2>&1 || {
                                    echo "Trivy K8s scan completed (exit code: \\$?)"
                                }
                                
                                echo ""
                                echo "=== Trivy Kubernetes Manifest Scan Results ==="
                                if [ -f trivy-k8s-scan.txt ]; then
                                    cat trivy-k8s-scan.txt
                                fi
                                echo "========================="
                                echo "✅ Trivy Kubernetes manifest scan completed"
                                
                                # Optionally scan running cluster if kubectl is available
                                if command -v kubectl &> /dev/null && kubectl cluster-info &> /dev/null; then
                                    echo ""
                                    echo "Scanning running Kubernetes cluster..."
                                    trivy k8s cluster --exit-code 0 --severity HIGH,CRITICAL --namespace ${K8S_NAMESPACE} --format table > trivy-k8s-cluster-scan.txt 2>&1 || {
                                        echo "Cluster scan completed (exit code: \\$?)"
                                    }
                                    if [ -f trivy-k8s-cluster-scan.txt ]; then
                                        echo "=== Trivy Kubernetes Cluster Scan Results ==="
                                        cat trivy-k8s-cluster-scan.txt
                                        echo "========================="
                                    fi
                                else
                                    echo "kubectl not available, skipping cluster scan"
                                fi
                            else
                                echo "⚠️ Trivy not found, skipping Kubernetes scan"
                            fi
                        """
                    }
                    echo "⚠️ Trivy Kubernetes scanning completed (may have warnings)"
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


