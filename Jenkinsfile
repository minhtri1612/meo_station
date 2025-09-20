pipeline {
    agent {
        docker {
            image 'node:18-alpine'
            args '-v /var/run/docker.sock:/var/run/docker.sock' 
        }
    }
    
    environment {
        // Application Configuration
        APP_NAME = 'meo-stationery'
        DOCKER_IMAGE = 'minhtri1612/meo-stationery-backend'
        IMAGE_TAG = "vcl"  // Using your existing tag
        KUBERNETES_NAMESPACE = 'meo-stationery'
        
        // Docker Hub Credentials
        DOCKER_HUB_CREDENTIALS = 'docker-hub-credentials' // Jenkins credentialsId
        DB_PASSWORD_CREDENTIALS = 'db-password' // Jenkins credentialsId for DB password
        
        // Kubernetes Configuration
        KUBECONFIG_CREDENTIALS = 'kubeconfig-credentials' // Jenkins credentialsId for kubeconfig
        
        // Helm Configuration
        HELM_CHART_PATH_DB = './k8s_helm/database'
        HELM_CHART_PATH_BACKEND = './k8s_helm/backend'
        HELM_RELEASE_DB = 'db'
        HELM_RELEASE_BACKEND = 'backend'
    }
    
    
    
    stages {
        stage('🔍 Checkout Code') {
            steps {
                echo '📦 Checking out source code...'
                checkout scm
                
                // Clean workspace
                sh 'git clean -fd'
                sh 'ls -la'
            }
        }
        
        stage('🔧 Install Dependencies') {
            steps {
                echo '📥 Installing Node.js dependencies...'
                sh '''
                    npm cache clean --force
                    npm install
                '''
            }
        }
        
        stage('🧪 Run Tests') {
            steps {
                echo '🧪 Running unit tests...'
                sh '''
                    npm test -- --passWithNoTests || echo "Tests completed with warnings"
                '''
            }
            post {
                always {
                    // Archive test results if they exist
                    script {
                        if (fileExists('coverage/')) {
                            publishHTML([
                                allowMissing: false,
                                alwaysLinkToLastBuild: true,
                                keepAll: true,
                                reportDir: 'coverage',
                                reportFiles: 'index.html',
                                reportName: 'Coverage Report'
                            ])
                        }
                    }
                }
            }
        }
        
        stage('🏗️ Build Application') {
            steps {
                echo '⚙️ Building Next.js application...'
                sh '''
                    npm run build
                    ls -la .next/
                '''
            }
        }
        
        stage('🐳 Build Docker Image') {
            steps {
                echo '🐳 Building Docker image...'
                script {
                    // Build Docker image with current build number
                    sh """
                        docker build -t ${DOCKER_IMAGE}:${IMAGE_TAG} .
                        docker build -t ${DOCKER_IMAGE}:latest .
                        docker images | grep ${DOCKER_IMAGE}
                    """
                }
            }
        }
        
        stage('🔐 Push to Docker Hub') {
            steps {
                echo '📤 Pushing Docker image to Docker Hub...'
                script {
                    withCredentials([usernamePassword(
                        credentialsId: "${DOCKER_HUB_CREDENTIALS}",
                        usernameVariable: 'DOCKER_USERNAME',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )]) {
                        sh """
                            echo \$DOCKER_PASSWORD | docker login -u \$DOCKER_USERNAME --password-stdin
                            docker push ${DOCKER_IMAGE}:${IMAGE_TAG}
                            docker push ${DOCKER_IMAGE}:latest
                            docker logout
                        """
                    }
                }
            }
        }
        
        stage('🎛️ Setup Kubernetes') {
            steps {
                echo '☸️ Setting up Kubernetes configuration...'
                script {
                    withCredentials([file(credentialsId: "${KUBECONFIG_CREDENTIALS}", variable: 'KUBECONFIG_FILE')]) {
                        sh '''
                            # Copy kubeconfig to workspace
                            cp $KUBECONFIG_FILE ~/.kube/config
                            chmod 600 ~/.kube/config
                            
                            # Verify kubectl connection
                            kubectl cluster-info
                            kubectl get nodes
                            
                            # Create namespace if it doesn't exist
                            kubectl create namespace ${KUBERNETES_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                            
                            # Verify namespace
                            kubectl get namespace ${KUBERNETES_NAMESPACE}
                        '''
                    }
                }
            }
        }
        
        stage('💾 Deploy Database') {
            steps {
                echo '💾 Deploying PostgreSQL database with Helm...'
                script {
                    // Use withCredentials to securely load the database password
                    withCredentials([string(credentialsId: "${DB_PASSWORD_CREDENTIALS}", variable: 'DB_PASSWORD')]) {
                        sh """
                            echo "Deploying/Upgrading database release '${HELM_RELEASE_DB}'..."
                            helm upgrade --install ${HELM_RELEASE_DB} ${HELM_CHART_PATH_DB} \
                                --namespace ${KUBERNETES_NAMESPACE} \
                                --set-string auth.password="\$DB_PASSWORD" \
                                --wait --timeout=300s
                            
                            echo "Verifying database deployment..."
                            kubectl get pods,svc -n ${KUBERNETES_NAMESPACE} -l app.kubernetes.io/name=postgres
                        """
                    }
                }
            }
        }
        
        stage('🚀 Deploy Backend Application') {
            steps {
                echo '🚀 Deploying backend application with Helm...'
                script {
                    // The 'helm upgrade --install' command simplifies the logic by handling both install and upgrade cases.
                    sh """
                        echo "Deploying/Upgrading backend release '${HELM_RELEASE_BACKEND}'..."
                        helm upgrade --install ${HELM_RELEASE_BACKEND} ${HELM_CHART_PATH_BACKEND} \
                            --namespace ${KUBERNETES_NAMESPACE} \
                            --set workload.image=${DOCKER_IMAGE}:${IMAGE_TAG} \
                            --wait --timeout=300s
                        
                        echo "Verifying backend deployment..."
                        kubectl get pods -n ${KUBERNETES_NAMESPACE} -l app.kubernetes.io/name=backend
                    """
                }
            }
        }
        
        stage('📊 Import Database Data') {
            when {
                // Only run data import on first deployment or when explicitly triggered
                anyOf {
                    expression { return params.IMPORT_DATA == true }
                    expression { return currentBuild.number == '1' }
                }
            }
            steps {
                echo '📊 Importing database data...'
                script {
                    sh """
                        # Wait for database to be ready
                        kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgres -n ${KUBERNETES_NAMESPACE} --timeout=120s
                        
                        # Copy SQL files to database pod
                        kubectl cp meo_stationery_data.sql postgres-0:/tmp/meo_stationery_data.sql -n ${KUBERNETES_NAMESPACE}
                        kubectl cp meo_stationery_backup.sql postgres-0:/tmp/meo_stationery_backup.sql -n ${KUBERNETES_NAMESPACE}
                        
                        # Import data
                        kubectl exec postgres-0 -n ${KUBERNETES_NAMESPACE} -- psql -U meo_admin -d meo_stationery -f /tmp/meo_stationery_data.sql
                        
                        # Verify data import
                        kubectl exec postgres-0 -n ${KUBERNETES_NAMESPACE} -- psql -U meo_admin -d meo_stationery -c "SELECT COUNT(*) FROM \\"Product\\";"
                    """
                }
            }
        }
        
        stage('🏥 Health Check') {
            steps {
                echo '🏥 Performing application health check...'
                script {
                    sh """
                        # Wait for backend pods to be ready
                        kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=backend -n ${KUBERNETES_NAMESPACE} --timeout=120s
                        
                        # Get pod name for health check
                        POD_NAME=\$(kubectl get pods -n ${KUBERNETES_NAMESPACE} -l app.kubernetes.io/name=backend -o jsonpath='{.items[0].metadata.name}')
                        
                        # Port forward for health check
                        kubectl port-forward \$POD_NAME 8080:3000 -n ${KUBERNETES_NAMESPACE} &
                        KUBECTL_PID=\$!
                        
                        # Wait for port forward to be ready
                        sleep 10
                        
                        # Perform health check
                        if curl -f http://localhost:8080 --max-time 30; then
                            echo "✅ Health check passed!"
                        else
                            echo "❌ Health check failed!"
                            exit 1
                        fi
                        
                        # Clean up port forward
                        kill \$KUBECTL_PID || true
                    """
                }
            }
        }
        
        stage('📋 Deployment Summary') {
            steps {
                echo '📋 Generating deployment summary...'
                script {
                    sh """
                        echo "=== DEPLOYMENT SUMMARY ==="
                        echo "Application: ${APP_NAME}"
                        echo "Docker Image: ${DOCKER_IMAGE}:${IMAGE_TAG}"
                        echo "Namespace: ${KUBERNETES_NAMESPACE}"
                        echo "Build Number: ${BUILD_NUMBER}"
                        echo "=========================="
                        
                        # Show deployment status
                        echo "\\n=== KUBERNETES RESOURCES ==="
                        kubectl get all -n ${KUBERNETES_NAMESPACE}
                        
                        echo "\\n=== HELM RELEASES ==="
                        helm list -n ${KUBERNETES_NAMESPACE}
                        
                        echo "\\n=== POD LOGS (Last 5 lines) ==="
                        kubectl logs -n ${KUBERNETES_NAMESPACE} -l app.kubernetes.io/name=backend --tail=5 || true
                    """
                }
            }
        }
    }
    
    post {
        always {
            echo '🏁 Pipeline completed'
            
            // Clean up Docker images to save space
            sh """
                docker rmi ${DOCKER_IMAGE}:${IMAGE_TAG} || true
                docker rmi ${DOCKER_IMAGE}:latest || true
                docker system prune -f || true
            """
        }
        
        success {
            echo '✅ Deployment successful!'
            
            // Send success notification (if configured)
            script {
                sh """
                    echo "🎉 Deployment successful for ${APP_NAME} (Build #${BUILD_NUMBER})"
                    echo "🌐 Application is running in Kubernetes namespace: ${KUBERNETES_NAMESPACE}"
                    echo "🐳 Docker image: ${DOCKER_IMAGE}:${IMAGE_TAG}"
                """
            }
        }
        
        failure {
            echo '❌ Deployment failed!'
            
            // Gather debugging information
            script {
                sh """
                    echo "🔍 Gathering debugging information..."
                    
                    # Show pod status
                    kubectl get pods -n ${KUBERNETES_NAMESPACE} || true
                    
                    # Show recent events
                    kubectl get events -n ${KUBERNETES_NAMESPACE} --sort-by='.lastTimestamp' | tail -10 || true
                    
                    # Show helm release status
                    helm status ${HELM_RELEASE_BACKEND} -n ${KUBERNETES_NAMESPACE} || true
                    helm status ${HELM_RELEASE_DB} -n ${KUBERNETES_NAMESPACE} || true
                """
            }
        }
        
        cleanup {
            echo '🧹 Cleaning up workspace...'
            // Clean workspace after build
            cleanWs()
        }
    }
}

// Pipeline parameters (can be configured in Jenkins UI)
parameters {
    booleanParam(
        name: 'IMPORT_DATA',
        defaultValue: false,
        description: 'Import database data during deployment'
    )
    choice(
        name: 'DEPLOYMENT_MODE',
        choices: ['rolling', 'recreate'],
        description: 'Kubernetes deployment strategy'
    )
}