# Upwork portfolio entry (copy-paste)

**Project title**
Private GKE setup with Terraform, keyless CI/CD and monitoring

**Your role**
DevOps Engineer

**Project description**
I built this to show the kind of GKE setup I work on day to day, as a public version without any client code.

Everything is in Terraform: the VPC, a private GKE cluster (nodes have no public IPs and go out through Cloud NAT), Artifact Registry and the IAM roles. State is kept in a GCS bucket.

GitHub Actions deploys to the cluster using Workload Identity Federation, so there are no service account keys stored anywhere. The pipeline builds the image, pushes it and runs helm upgrade. If the rollout fails, it rolls back on its own. The app itself reads its secret from Secret Manager through Workload Identity.

For monitoring I used kube-prometheus-stack with a Grafana dashboard and a few alerts (error rate, slow responses, no pods running). Deployments are zero downtime: readiness probes, a PDB and graceful shutdown.

The whole environment comes up or gets destroyed with one command, and it runs on Spot nodes to keep the cost low.

**Skills to tag**
Google Cloud Platform, Kubernetes, Terraform, CI/CD, DevOps, Docker, Grafana, Prometheus, Infrastructure as Code, GitHub

**Media to attach** (take these after deploying once)
1. Architecture diagram: screenshot the diagram from the README on GitHub.
2. The GitHub Actions deploy run, all green.
3. The Grafana "demo-app" dashboard.
4. Output of `kubectl get pods,hpa,pdb -n demo`.
5. GCP console: the GKE cluster page showing private nodes.

**Project URL**
https://github.com/Vivek-0311/gke-platform-showcase
