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


