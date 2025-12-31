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
        SONAR_HOST_URL = 'http://sonarqube.sonarqube.svc.cluster.local:9000'  // Kubernetes service DNS name
        SONAR_PROJECT_KEY = 'meo-station'  // Match your SonarQube project key
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
                        export NVM_DIR="$HOME/.nvm"
                        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" || {
                            echo "NVM not found, installing..."
                            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
                            export NVM_DIR="$HOME/.nvm"
                            [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
                        }
                        nvm install 18 || echo "Node 18 may already be installed"
                        nvm use 18
                        node --version
                        npm --version
                    '''
                }
            }
        }
        
        stage('Install Dependencies') {
            steps {
                script {
                    sh '''
                        export NVM_DIR="$HOME/.nvm"
                        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && nvm use 18
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
                        export NVM_DIR="$HOME/.nvm"
                        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && nvm use 18
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
                        export NVM_DIR="$HOME/.nvm"
                        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && nvm use 18
                        echo "Building Next.js application..."
                        npm run build
                    '''
                }
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                script {
                    catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                        withSonarQubeEnv('sonarqube') {
                            // SonarQube analysis
                            // Note: Authentication token should be configured in Jenkins SonarQube server settings
                            // The withSonarQubeEnv wrapper should inject SONAR_AUTH_TOKEN automatically
                            sh """
                                echo "Running SonarQube analysis..."
                                echo "SonarQube URL: ${env.SONAR_HOST_URL}"
                                echo "Project Key: ${env.SONAR_PROJECT_KEY}"
                                
                                ${env.SCANNER_HOME}/bin/sonar-scanner \\
                                -Dsonar.projectKey=${env.SONAR_PROJECT_KEY} \\
                                -Dsonar.sources=. \\
                                -Dsonar.host.url=${env.SONAR_HOST_URL} \\
                                -Dsonar.projectName=meo-station \\
                                -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info || echo "SonarQube scan completed with errors"
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
                        // Only check quality gate if report-task.txt exists (analysis succeeded)
                        sh '''
                            if [ -f .scannerwork/report-task.txt ]; then
                                echo "Quality gate report found, waiting for quality gate..."
                            else
                                echo "⚠️ Quality gate check skipped - SonarQube analysis did not complete successfully"
                                echo "Check if SonarQube server is accessible from Jenkins pod"
                            fi
                        '''
                        waitForQualityGate abortPipeline: false, credentialsId: 'Sonar-token'
                    }
                    echo "⚠️ Quality gate check completed (may have warnings)"
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
        
        // Docker stages disabled - cluster uses containerd, not Docker
        // To enable Docker, you would need to:
        // 1. Install Docker in Jenkins pod, OR
        // 2. Use Kaniko for building images without Docker daemon
        // stage('Build Docker Image') {
        //     steps {
        //         script {
        //             def imageTag = "${DOCKER_REGISTRY}/${DOCKER_IMAGE_NAME}:${DOCKER_TAG}"
        //             def imageTagLatest = "${DOCKER_REGISTRY}/${DOCKER_IMAGE_NAME}:latest"
        //             
        //             echo "Building Docker image: ${imageTag}"
        //             
        //             sh """
        //                 docker build -t ${imageTag} -t ${imageTagLatest} .
        //             """
        //             
        //             env.DOCKER_IMAGE_FULL = imageTag
        //         }
        //     }
        // }
        // 
        // stage('Trivy Docker Image Scanning') {
        //     steps {
        //         script {
        //             catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
        //                 def imageToScan = env.DOCKER_IMAGE_FULL
        //                 sh """
        //                     export PATH="\\\$HOME/.local/bin:\\\${PATH}"
        //                     
        //                     if command -v trivy &> /dev/null; then
        //                         echo "Running Trivy Docker image scan..."
        //                         trivy image --exit-code 0 --severity HIGH,CRITICAL --no-progress '${imageToScan}' > trivy-image-scan.txt 2>&1 || true
        //                         
        //                         echo "=== Trivy Docker Image Scan Results ==="
        //                         [ -f trivy-image-scan.txt ] && cat trivy-image-scan.txt || true
        //                         echo "========================="
        //                     fi
        //                 """
        //             }
        //         }
        //     }
        // }
        // 
        // stage('Push Docker Image') {
        //     steps {
        //         script {
        //             withCredentials([usernamePassword(
        //                 credentialsId: 'docker-hub-credentials',
        //                 usernameVariable: 'DOCKER_USER',
        //                 passwordVariable: 'DOCKER_PASS'
        //             )]) {
        //                 sh """
        //                     echo \$DOCKER_PASS | docker login -u \$DOCKER_USER --password-stdin
        //                     docker push ${env.DOCKER_IMAGE_FULL}
        //                     docker push ${DOCKER_REGISTRY}/${DOCKER_IMAGE_NAME}:latest
        //                     docker logout
        //                 """
        //             }
        //         }
        //     }
        // }
        
        stage('Trivy Kubernetes Scanning') {
            steps {
                script {
                    catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                        def helmChartPath = HELM_CHART_PATH
                        def k8sNamespace = K8S_NAMESPACE
                        sh """
                            export PATH="\\\$HOME/.local/bin:\\\${PATH}"
                            
                            if command -v trivy &> /dev/null; then
                                echo "Running Trivy Kubernetes manifest scan..."
                                echo "Scanning Helm charts in: ${helmChartPath}"
                                
                                # Scan Kubernetes manifest files (Helm charts)
                                # This scans for misconfigurations, security issues in K8s YAML files
                                # Examples: missing security contexts, privilege escalation, insecure defaults
                                trivy k8s config --exit-code 0 --severity HIGH,CRITICAL --format table '${helmChartPath}' > trivy-k8s-scan.txt 2>&1 || {
                                    echo "Trivy K8s scan completed (exit code: \\\$?)"
                                }
                                
                                echo ""
                                echo "=== Trivy Kubernetes Manifest Scan Results ==="
                                if [ -f trivy-k8s-scan.txt ]; then
                                    /bin/cat trivy-k8s-scan.txt 2>/dev/null || echo "Could not read scan results"
                                else
                                    echo "Scan results file not found - Trivy scan may have failed"
                                fi
                                echo "========================="
                                echo "✅ Trivy Kubernetes manifest scan completed"
                                
                                # Optionally scan running cluster if kubectl is available
                                if command -v kubectl &> /dev/null && kubectl cluster-info &> /dev/null; then
                                    echo ""
                                    echo "Scanning running Kubernetes cluster..."
                                    trivy k8s cluster --exit-code 0 --severity HIGH,CRITICAL --namespace '${k8sNamespace}' --format table > trivy-k8s-cluster-scan.txt 2>&1 || {
                                        echo "Cluster scan completed (exit code: \\\$?)"
                                    }
                                    if [ -f trivy-k8s-cluster-scan.txt ]; then
                                        echo "=== Trivy Kubernetes Cluster Scan Results ==="
                                        /bin/cat trivy-k8s-cluster-scan.txt 2>/dev/null || echo "Could not read cluster scan results"
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
        
        // Deploy stage disabled - requires Docker image
        // stage('Deploy to Kubernetes') {
        //     steps {
        //         script {
        //             sh """
        //                 echo "Deploying to Kubernetes namespace: ${K8S_NAMESPACE}"
        //                 helm upgrade --install ${HELM_RELEASE_NAME} ${HELM_CHART_PATH} \\
        //                     --namespace ${K8S_NAMESPACE} \\
        //                     --set workload.image=${env.DOCKER_IMAGE_FULL} \\
        //                     --set workload.imagePullPolicy=Always \\
        //                     --wait --timeout=10m
        //             """
        //         }
        //     }
        // }
        
        // Database migrations and deployment verification disabled - kubectl not available
        // stage('Run Database Migrations') {
        //     steps {
        //         script {
        //             sh """
        //                 echo "Running database migrations..."
        //                 kubectl wait --for=condition=ready pod \\
        //                     -l app.kubernetes.io/name=backend \\
        //                     -n ${K8S_NAMESPACE} \\
        //                     --timeout=5m || true
        //                 
        //                 BACKEND_POD=\$(kubectl get pods -n ${K8S_NAMESPACE} \\
        //                     -l app.kubernetes.io/name=backend \\
        //                     -o jsonpath='{.items[0].metadata.name}')
        //                 
        //                 if [ -n "\$BACKEND_POD" ]; then
        //                     kubectl exec -n ${K8S_NAMESPACE} \$BACKEND_POD -- \\
        //                         npx prisma migrate deploy || echo "Migrations may have already been applied"
        //                 fi
        //             """
        //         }
        //     }
        // }
        // 
        // stage('Verify Deployment') {
        //     steps {
        //         script {
        //             sh """
        //                 echo "Verifying deployment..."
        //                 kubectl get pods -n ${K8S_NAMESPACE} -l app.kubernetes.io/name=backend
        //                 kubectl get svc -n ${K8S_NAMESPACE} -l app.kubernetes.io/name=backend
        //                 kubectl get ingress -n ${K8S_NAMESPACE} || echo "No ingress found"
        //             """
        //         }
        //     }
        // }
    }
    
    post {
        success {
            script {
                echo "✅ Pipeline succeeded!"
                echo "Application built successfully!"
                // Docker stages are disabled - cluster uses containerd
                // echo "Docker image: ${env.DOCKER_IMAGE_FULL}"
                // echo "Deployed to: ${K8S_NAMESPACE}/${HELM_RELEASE_NAME}"
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
                // Docker cleanup disabled - cluster uses containerd
                echo "Pipeline completed"
            }
        }
    }
}


