--- a/Jenkinsfile.groovy
+++ b/Jenkinsfile.groovy
@@ -16,6 +16,7 @@
         
         // Docker Hub Credentials
         DOCKER_HUB_CREDENTIALS = 'docker-hub-credentials' // Jenkins credentialsId
+        DB_PASSWORD_CREDENTIALS = 'db-password' // Jenkins credentialsId for DB password
         
         // Kubernetes Configuration
         KUBECONFIG_CREDENTIALS = 'kubeconfig-credentials' // Jenkins credentialsId for kubeconfig
@@ -150,25 +151,18 @@
             steps {
                 echo '💾 Deploying PostgreSQL database with Helm...'
                 script {
-                    sh """
-                        # Check if database release exists
-                        if helm list -n ${KUBERNETES_NAMESPACE} | grep -q ; then
-                            echo "Database release exists, upgrading..."
-                            helm upgrade   \
-                                --namespace  \
-                                --set auth.password="MeoStationery2025!" \
-                                --wait --timeout=300s
-                        else
-                            echo "Installing new database release..."
-                            helm install   \
-                                --namespace  \
-                                --set auth.password="MeoStationery2025!" \
-                                --wait --timeout=300s
-                        fi
-                        
-                        # Verify database deployment
-                        kubectl get pods -n  -l app.kubernetes.io/name=postgres
-                        kubectl get svc -n  -l app.kubernetes.io/name=postgres
-                    """
+                    // Use withCredentials to securely load the database password
+                    withCredentials([string(credentialsId: "", variable: 'DB_PASSWORD')]) {
+                        sh """
+                            echo "Deploying/Upgrading database release ''..."
+                            helm upgrade --install   \
+                                --namespace  \
+                                --set-string auth.password="$DB_PASSWORD" \
+                                --wait --timeout=300s
+                            
+                            echo "Verifying database deployment..."
+                            kubectl get pods,svc -n  -l app.kubernetes.io/name=postgres
+                        """
+                    }
                 }
             }
         }
@@ -178,24 +172,16 @@
             steps {
                 echo "🚀 Deploying Backend Application with Helm..."
                 script {
-                    sh """
-                        # Check if backend release exists
-                        if helm list -n  | grep -q ; then
-                            echo "Backend release exists, upgrading..."
-                            helm upgrade   \
-                                --namespace  \
-                                --set workload.image=: \
-                                --wait --timeout=300s
-                        else
-                            echo "Installing new backend release..."
-                            helm install   \
-                                --namespace  \
-                                --set workload.image=: \
-                                --wait --timeout=300s
-                        fi
-                        
-                        # Verify backend deployment
-                        kubectl get pods -n  -l app.kubernetes.io/name=meo-stationery-backend
-                    """
+                    // The 'helm upgrade --install' command simplifies the logic by handling both install and upgrade cases.
+                    sh """
+                        echo "Deploying/Upgrading backend release ''..."
+                        helm upgrade --install   \
+                            --namespace  \
+                            --set workload.image=: \
+                            --wait --timeout=300s
+                        
+                        echo "Verifying backend deployment..."
+                        kubectl get pods -n  -l app.kubernetes.io/name=meo-stationery-backend
+                    """
                 }
             }
         }

--- a/Jenkinsfile.groovy
+++ b/Jenkinsfile.groovy
@@ -16,6 +16,7 @@
         
         // Docker Hub Credentials
         DOCKER_HUB_CREDENTIALS = 'docker-hub-credentials' // Jenkins credentialsId
+        DB_PASSWORD_CREDENTIALS = 'db-password' // Jenkins credentialsId for DB password
         
         // Kubernetes Configuration
         KUBECONFIG_CREDENTIALS = 'kubeconfig-credentials' // Jenkins credentialsId for kubeconfig
@@ -150,25 +151,18 @@
             steps {
                 echo '💾 Deploying PostgreSQL database with Helm...'
                 script {
-                    sh """
-                        # Check if database release exists
-                        if helm list -n ${KUBERNETES_NAMESPACE} | grep -q ; then
-                            echo "Database release exists, upgrading..."
-                            helm upgrade   \
-                                --namespace  \
-                                --set auth.password="MeoStationery2025!" \
-                                --wait --timeout=300s
-                        else
-                            echo "Installing new database release..."
-                            helm install   \
-                                --namespace  \
-                                --set auth.password="MeoStationery2025!" \
-                                --wait --timeout=300s
-                        fi
-                        
-                        # Verify database deployment
-                        kubectl get pods -n  -l app.kubernetes.io/name=postgres
-                        kubectl get svc -n  -l app.kubernetes.io/name=postgres
-                    """
+                    // Use withCredentials to securely load the database password
+                    withCredentials([string(credentialsId: "", variable: 'DB_PASSWORD')]) {
+                        sh """
+                            echo "Deploying/Upgrading database release ''..."
+                            helm upgrade --install   \
+                                --namespace  \
+                                --set-string auth.password="$DB_PASSWORD" \
+                                --wait --timeout=300s
+                            
+                            echo "Verifying database deployment..."
+                            kubectl get pods,svc -n  -l app.kubernetes.io/name=postgres
+                        """
+                    }
                 }
             }
         }
@@ -178,24 +172,16 @@
             steps {
                 echo "🚀 Deploying Backend Application with Helm..."
                 script {
-                    sh """
-                        # Check if backend release exists
-                        if helm list -n  | grep -q ; then
-                            echo "Backend release exists, upgrading..."
-                            helm upgrade   \
-                                --namespace  \
-                                --set workload.image=: \
-                                --wait --timeout=300s
-                        else
-                            echo "Installing new backend release..."
-                            helm install   \
-                                --namespace  \
-                                --set workload.image=: \
-                                --wait --timeout=300s
-                        fi
-                        
-                        # Verify backend deployment
-                        kubectl get pods -n  -l app.kubernetes.io/name=meo-stationery-backend
-                    """
+                    // The 'helm upgrade --install' command simplifies the logic by handling both install and upgrade cases.
+                    sh """
+                        echo "Deploying/Upgrading backend release ''..."
+                        helm upgrade --install   \
+                            --namespace  \
+                            --set workload.image=: \
+                            --wait --timeout=300s
+                        
+                        echo "Verifying backend deployment..."
+                        kubectl get pods -n  -l app.kubernetes.io/name=meo-stationery-backend
+                    """
                 }
             }
         }

--- a/Jenkinsfile.groovy
+++ b/Jenkinsfile.groovy
@@ -16,6 +16,7 @@
         
         // Docker Hub Credentials
         DOCKER_HUB_CREDENTIALS = 'docker-hub-credentials' // Jenkins credentialsId
+        DB_PASSWORD_CREDENTIALS = 'db-password' // Jenkins credentialsId for DB password
         
         // Kubernetes Configuration
         KUBECONFIG_CREDENTIALS = 'kubeconfig-credentials' // Jenkins credentialsId for kubeconfig
@@ -150,25 +151,18 @@
             steps {
                 echo '💾 Deploying PostgreSQL database with Helm...'
                 script {
-                    sh """
-                        # Check if database release exists
-                        if helm list -n ${KUBERNETES_NAMESPACE} | grep -q ; then
-                            echo "Database release exists, upgrading..."
-                            helm upgrade   \
-                                --namespace  \
-                                --set auth.password="MeoStationery2025!" \
-                                --wait --timeout=300s
-                        else
-                            echo "Installing new database release..."
-                            helm install   \
-                                --namespace  \
-                                --set auth.password="MeoStationery2025!" \
-                                --wait --timeout=300s
-                        fi
-                        
-                        # Verify database deployment
-                        kubectl get pods -n  -l app.kubernetes.io/name=postgres
-                        kubectl get svc -n  -l app.kubernetes.io/name=postgres
-                    """
+                    // Use withCredentials to securely load the database password
+                    withCredentials([string(credentialsId: "", variable: 'DB_PASSWORD')]) {
+                        sh """
+                            echo "Deploying/Upgrading database release ''..."
+                            helm upgrade --install   \
+                                --namespace  \
+                                --set-string auth.password="$DB_PASSWORD" \
+                                --wait --timeout=300s
+                            
+                            echo "Verifying database deployment..."
+                            kubectl get pods,svc -n  -l app.kubernetes.io/name=postgres
+                        """
+                    }
                 }
             }
         }
@@ -178,24 +172,16 @@
             steps {
                 echo "🚀 Deploying Backend Application with Helm..."
                 script {
-                    sh """
-                        # Check if backend release exists
-                        if helm list -n  | grep -q ; then
-                            echo "Backend release exists, upgrading..."
-                            helm upgrade   \
-                                --namespace  \
-                                --set workload.image=: \
-                                --wait --timeout=300s
-                        else
-                            echo "Installing new backend release..."
-                            helm install   \
-                                --namespace  \
-                                --set workload.image=: \
-                                --wait --timeout=300s
-                        fi
-                        
-                        # Verify backend deployment
-                        kubectl get pods -n  -l app.kubernetes.io/name=meo-stationery-backend
-                    """
+                    // The 'helm upgrade --install' command simplifies the logic by handling both install and upgrade cases.
+                    sh """
+                        echo "Deploying/Upgrading backend release ''..."
+                        helm upgrade --install   \
+                            --namespace  \
+                            --set workload.image=: \
+                            --wait --timeout=300s
+                        
+                        echo "Verifying backend deployment..."
+                        kubectl get pods -n  -l app.kubernetes.io/name=meo-stationery-backend
+                    """
                 }
             }
         }

--- a/Jenkinsfile.groovy
+++ b/Jenkinsfile.groovy
@@ -16,6 +16,7 @@
         
         // Docker Hub Credentials
         DOCKER_HUB_CREDENTIALS = 'docker-hub-credentials' // Jenkins credentialsId
+        DB_PASSWORD_CREDENTIALS = 'db-password' // Jenkins credentialsId for DB password
         
         // Kubernetes Configuration
         KUBECONFIG_CREDENTIALS = 'kubeconfig-credentials' // Jenkins credentialsId for kubeconfig
@@ -150,25 +151,18 @@
             steps {
                 echo '💾 Deploying PostgreSQL database with Helm...'
                 script {
-                    sh """
-                        # Check if database release exists
-                        if helm list -n ${KUBERNETES_NAMESPACE} | grep -q ; then
-                            echo "Database release exists, upgrading..."
-                            helm upgrade   \
-                                --namespace  \
-                                --set auth.password="MeoStationery2025!" \
-                                --wait --timeout=300s
-                        else
-                            echo "Installing new database release..."
-                            helm install   \
-                                --namespace  \
-                                --set auth.password="MeoStationery2025!" \
-                                --wait --timeout=300s
-                        fi
-                        
-                        # Verify database deployment
-                        kubectl get pods -n  -l app.kubernetes.io/name=postgres
-                        kubectl get svc -n  -l app.kubernetes.io/name=postgres
-                    """
+                    // Use withCredentials to securely load the database password
+                    withCredentials([string(credentialsId: "", variable: 'DB_PASSWORD')]) {
+                        sh """
+                            echo "Deploying/Upgrading database release ''..."
+                            helm upgrade --install   \
+                                --namespace  \
+                                --set-string auth.password="$DB_PASSWORD" \
+                                --wait --timeout=300s
+                            
+                            echo "Verifying database deployment..."
+                            kubectl get pods,svc -n  -l app.kubernetes.io/name=postgres
+                        """
+                    }
                 }
             }
         }
@@ -178,24 +172,16 @@
             steps {
                 echo "🚀 Deploying Backend Application with Helm..."
                 script {
-                    sh """
-                        # Check if backend release exists
-                        if helm list -n  | grep -q ; then
-                            echo "Backend release exists, upgrading..."
-                            helm upgrade   \
-                                --namespace  \
-                                --set workload.image=: \
-                                --wait --timeout=300s
-                        else
-                            echo "Installing new backend release..."
-                            helm install   \
-                                --namespace  \
-                                --set workload.image=: \
-                                --wait --timeout=300s
-                        fi
-                        
-                        # Verify backend deployment
-                        kubectl get pods -n  -l app.kubernetes.io/name=meo-stationery-backend
-                    """
+                    // The 'helm upgrade --install' command simplifies the logic by handling both install and upgrade cases.
+                    sh """
+                        echo "Deploying/Upgrading backend release ''..."
+                        helm upgrade --install   \
+                            --namespace  \
+                            --set workload.image=: \
+                            --wait --timeout=300s
+                        
+                        echo "Verifying backend deployment..."
+                        kubectl get pods -n  -l app.kubernetes.io/name=meo-stationery-backend
+                    """
                 }
             }
         }

