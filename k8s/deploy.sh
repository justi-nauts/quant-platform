#!/bin/bash

# Quantitative Research Platform - Kubernetes Deployment Script
# This script deploys your platform to EKS or any Kubernetes cluster

set -e

echo "🚀 Deploying Quantitative Research Platform to Kubernetes..."
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first:"
    echo "   https://kubernetes.io/docs/tasks/tools/install-kubectl/"
    exit 1
fi

# Check if eksctl is available
if ! command -v eksctl &> /dev/null; then
    echo "⚠️  eksctl not found. Installing eksctl..."
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    sudo mv /tmp/eksctl /usr/local/bin
fi

echo "📋 Deployment Steps:"
echo "1. Create EKS cluster (15-20 minutes)"
echo "2. Deploy all services (5-10 minutes)"  
echo "3. Get access URLs"
echo ""

# Step 1: Create EKS cluster
echo "📦 Creating EKS cluster..."
echo "⏳ This will take 15-20 minutes. Perfect time for coffee! ☕"
eksctl create cluster \
  --name quant-platform \
  --region us-east-1 \
  --nodes 2 \
  --node-type t3.medium \
  --managed

echo "✅ EKS cluster created successfully!"
echo ""

# Step 2: Create namespace
echo "🏗️  Creating namespace..."
kubectl apply -f k8s/namespace.yaml

# Step 3: Apply configuration
echo "🔐 Setting up configuration..."
echo "⚠️  IMPORTANT: Secrets must be created manually or via CI/CD"
echo "   This script does not create secrets - use GitHub Actions for production"

# Step 4: Create configmaps from local files
echo "📋 Creating database init script..."
kubectl create configmap db-init-script --from-file=init-db.sql -n quant-platform --dry-run=client -o yaml | kubectl apply -f -

echo "📊 Creating Airflow DAGs..."
kubectl create configmap airflow-dags --from-file=dags/ -n quant-platform --dry-run=client -o yaml | kubectl apply -f -

# Step 5: Deploy services in order
echo "🗄️  Deploying PostgreSQL..."
kubectl apply -f k8s/postgres.yaml

echo "🔴 Deploying Redis..."
kubectl apply -f k8s/redis.yaml

echo "⏳ Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/postgres -n quant-platform

echo "🌊 Deploying Airflow..."
echo "📦 Creating Airflow storage..."
kubectl apply -f k8s/airflow-storage.yaml

echo "🔐 Setting up Airflow RBAC..."
kubectl apply -f k8s/airflow-rbac.yaml

echo "📅 Deploying Airflow scheduler..."
kubectl apply -f k8s/airflow-scheduler.yaml

echo "🖥️  Deploying Airflow webserver..."
kubectl apply -f k8s/airflow-webserver.yaml

echo "🐘 Deploying pgAdmin..."
kubectl apply -f k8s/pgadmin.yaml

echo "⏳ Waiting for all services to be ready..."
kubectl wait --for=condition=available --timeout=600s deployment/airflow-scheduler -n quant-platform
kubectl wait --for=condition=available --timeout=600s deployment/airflow-webserver -n quant-platform
kubectl wait --for=condition=available --timeout=300s deployment/pgadmin -n quant-platform

echo ""
echo "✅ Deployment complete!"
echo ""

# Get access information
echo "🌐 Getting access information..."

echo ""
echo "🎉 Your Quantitative Research Platform is LIVE!"
echo ""
echo "🔒 Security Notice: This deployment uses ClusterIP services for security."
echo "   Access services via port-forwarding for secure connections."
echo ""
echo "⚠️  PRODUCTION SECURITY: For production deployments, override default credentials!"
echo "   Set your own secrets via GitHub repository secrets or environment variables."
echo ""
echo "📊 Airflow UI Access:"
echo "   kubectl port-forward -n quant-platform service/airflow 8080:8080"
echo "   Then visit: http://localhost:8080"
echo "   Username: Set via AIRFLOW_ADMIN_USERNAME secret"
echo "   Password: Set via AIRFLOW_ADMIN_PASSWORD secret"
echo ""
echo "🐘 pgAdmin Access:"
echo "   kubectl port-forward -n quant-platform service/pgadmin 5050:80"
echo "   Then visit: http://localhost:5050"
echo "   Email: Set via PGADMIN_EMAIL secret"
echo "   Password: Set via PGADMIN_PASSWORD secret"
echo ""

echo "🔧 Convenient Access:"
echo "   Connect to production: ./connect-prod.sh"
echo "   Disconnect from production: ./disconnect-prod.sh"
echo "   Or manual port-forward:"
echo "     kubectl port-forward -n quant-platform service/airflow 8081:8080"
echo "     kubectl port-forward -n quant-platform service/pgadmin 5051:5050"
echo ""
echo "📖 Documentation:"
echo "   Production access guide: PRODUCTION_ACCESS.md"
echo "   GitHub secrets setup: GITHUB_SECRETS_SETUP.md"
echo ""
echo "🔧 Useful commands:"
echo "   View all pods: kubectl get pods -n quant-platform"
echo "   View scheduler logs: kubectl logs -f deployment/airflow-scheduler -n quant-platform"
echo "   View webserver logs: kubectl logs -f deployment/airflow-webserver -n quant-platform"
echo "   Scale Airflow scheduler: kubectl scale deployment airflow-scheduler --replicas=2 -n quant-platform"
echo "   Scale Airflow webserver: kubectl scale deployment airflow-webserver --replicas=2 -n quant-platform"
echo "   Update DAGs: kubectl create configmap airflow-dags --from-file=dags/ -n quant-platform --dry-run=client -o yaml | kubectl apply -f -"
echo ""
echo "🧹 To cleanup everything: eksctl delete cluster --name quant-platform --region us-east-1"
echo ""
echo "🚀 Ready to start your quantitative research journey!" 