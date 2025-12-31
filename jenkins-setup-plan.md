# Jenkins CI/CD Setup Plan for Meo Stationery

## Architecture Overview

```
┌─────────────┐
│   GitHub    │ (or GitLab/Bitbucket)
│  Repository │
└──────┬──────┘
       │ Push/PR
       ↓
┌─────────────┐
│   Jenkins   │ CI Pipeline:
│             │ 1. Clone code
│  (Running   │ 2. npm install
│   in K8s)   │ 3. npm run lint
│             │ 4. npm test (if tests exist)
│             │ 5. Build Docker image
│             │ 6. Push to ECR/Docker Hub
└──────┬──────┘
       │ Image Tag
       ↓
┌─────────────┐     ┌─────────────┐
│    ECR /    │────→│   ArgoCD    │ (Auto-syncs)
│ Docker Hub  │     │   GitOps    │
└─────────────┘     └──────┬──────┘
                           │ Deploy
                           ↓
                    ┌─────────────┐
                    │ Kubernetes  │
                    │   Cluster   │
                    └─────────────┘
```

## Implementation Steps

### 1. Install Jenkins on Kubernetes

Create Jenkins deployment:
- Jenkins Master (StatefulSet with PVC)
- Jenkins Agents (Kubernetes plugin for dynamic pods)
- Service + Ingress for access

### 2. Configure Jenkins

**Required Plugins:**
- Kubernetes Plugin (for K8s agents)
- Docker Pipeline Plugin
- Git Plugin
- GitHub/GitLab Plugin (webhooks)
- Blue Ocean (modern UI)
- Pipeline Plugin

**Credentials:**
- AWS credentials (for ECR push)
- Docker Hub credentials (if using Docker Hub)
- GitHub/Git personal access token
- Kubernetes credentials

### 3. Create Jenkinsfile (Pipeline as Code)

**Jenkinsfile Stages:**
```groovy
pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = 'your-ecr-registry'
        IMAGE_NAME = 'meo-stationery'
        K8S_NAMESPACE = 'meo-stationery'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Install Dependencies') {
            steps {
                sh 'npm ci'
            }
        }
        
        stage('Lint') {
            steps {
                sh 'npm run lint'
            }
        }
        
        stage('Test') {
            steps {
                sh 'npm test' // if tests exist
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    def imageTag = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
                    sh """
                        docker build -t ${IMAGE_NAME}:${imageTag} .
                        docker tag ${IMAGE_NAME}:${imageTag} ${DOCKER_REGISTRY}/${IMAGE_NAME}:${imageTag}
                        docker tag ${IMAGE_NAME}:${imageTag} ${DOCKER_REGISTRY}/${IMAGE_NAME}:latest
                    """
                }
            }
        }
        
        stage('Push to Registry') {
            steps {
                script {
                    withAWS(credentials: 'aws-credentials') {
                        sh 'aws ecr get-login-password | docker login --username AWS --password-stdin ${DOCKER_REGISTRY}'
                        sh 'docker push ${DOCKER_REGISTRY}/${IMAGE_NAME}:${imageTag}'
                        sh 'docker push ${DOCKER_REGISTRY}/${IMAGE_NAME}:latest'
                    }
                }
            }
        }
        
        stage('Update Helm Values') {
            steps {
                script {
                    // Update image tag in values.yaml
                    sh """
                        sed -i 's|imageTag:.*|imageTag: ${imageTag}|' k8s_helm/backend/values.yaml
                        git config user.name "Jenkins"
                        git config user.email "jenkins@meo-stationery"
                        git add k8s_helm/backend/values.yaml
                        git commit -m "Update image tag to ${imageTag}" || true
                        git push origin HEAD:${env.BRANCH_NAME} || true
                    """
                }
            }
        }
        
        // ArgoCD will auto-sync after git push
        // OR deploy directly with kubectl/helm:
        
        stage('Deploy to K8s') {
            steps {
                script {
                    withKubeConfig([credentialsId: 'k8s-credentials']) {
                        sh """
                            kubectl set image deployment/backend \
                                backend=${DOCKER_REGISTRY}/${IMAGE_NAME}:${imageTag} \
                                -n ${K8S_NAMESPACE}
                        """
                    }
                }
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline succeeded!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}
```

### 4. Integration with ArgoCD

**Option A: GitOps Approach (Recommended)**
- Jenkins updates `values.yaml` with new image tag
- Pushes to Git
- ArgoCD detects change and auto-deploys

**Option B: Direct Deployment**
- Jenkins deploys directly using `kubectl` or `helm`
- Bypasses ArgoCD (less GitOps-y)

### 5. Webhook Configuration

**GitHub Webhook:**
- URL: `http://jenkins.local/github-webhook/`
- Events: Push, Pull Request
- Triggers Jenkins pipeline automatically

## Resource Requirements

**Jenkins Master:**
- CPU: 500m-1000m
- Memory: 1Gi-2Gi
- Storage: 10Gi (for builds, plugins)

**Jenkins Agents (Dynamic):**
- Created per build
- 1 CPU, 2Gi memory per agent
- Auto-deleted after build

## Security Considerations

1. **Secrets Management:**
   - Use Kubernetes Secrets
   - Jenkins Credentials Plugin
   - HashiCorp Vault (optional)

2. **RBAC:**
   - Limited Kubernetes permissions
   - ServiceAccount with minimal privileges

3. **Network:**
   - Private registry access
   - Kubernetes API access

## Benefits

✅ **Automated Testing**: Run tests on every commit
✅ **Fast Feedback**: Developers know if code breaks
✅ **Consistent Builds**: Same environment every time
✅ **Docker Image Building**: Automated image creation
✅ **Deployment Automation**: One-click deployments
✅ **Integration with Existing Stack**: Works with ArgoCD

## Alternative: GitHub Actions (Simpler)

If you don't need Jenkins-specific features, consider:
- **GitHub Actions**: Free, integrated with GitHub
- **GitLab CI**: If using GitLab
- **CircleCI/Travis CI**: Cloud-based alternatives

## Installation Commands

```bash
# Install Jenkins via Helm
helm repo add jenkins https://charts.jenkins.io
helm repo update

helm install jenkins jenkins/jenkins \
  --namespace jenkins \
  --create-namespace \
  --set controller.serviceType=ClusterIP \
  --set controller.ingress.enabled=true \
  --set controller.ingress.hostName=jenkins.local

# Get admin password
kubectl exec --namespace jenkins -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password && echo
```

## Next Steps

1. Decide: Jenkins or GitHub Actions?
2. Choose registry: ECR, Docker Hub, or other?
3. Create Jenkinsfile in repository
4. Install Jenkins on cluster
5. Configure webhooks
6. Test pipeline


