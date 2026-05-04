# Nexus Admin API Base Kustomization

This directory contains the base Kubernetes manifests for deploying the Nexus Admin API.

## RBAC Configuration

The `nexus-adm-api` application is responsible for provisioning new environments (Tenants) in the Kubernetes cluster. To do this, it requires specific permissions to interact with the Kubernetes API.

The following RBAC resources are automatically applied via this Kustomization:

1. **ServiceAccount** (`serviceaccount.yaml`): The identity used by the `nexus-adm-api` pods.
2. **ClusterRole** (`clusterrole.yaml`): The broad set of permissions needed. Since the API creates resources (Namespaces, Deployments, Services, etc.) across the entire cluster, a `ClusterRole` is used instead of a standard `Role`.
3. **ClusterRoleBinding** (`clusterrolebinding.yaml`): Binds the `nexus-adm-api-sa` ServiceAccount to the `nexus-adm-api-clusterrole`.

### Troubleshooting Permissions
If you encounter a `403 Forbidden` error during environment provisioning (e.g., "User ... cannot create resource 'namespaces'"):
1. Ensure that the ServiceAccount is correctly mounted in the `deployment.yaml` under `spec.template.spec.serviceAccountName: nexus-adm-api-sa`.
2. Ensure the ClusterRole and ClusterRoleBinding are applied correctly in the cluster:
   ```bash
   kubectl get clusterrole nexus-adm-api-clusterrole
   kubectl get clusterrolebinding nexus-adm-api-clusterrolebinding
   ```
3. If new resource types are needed in the future (e.g., creating `CronJobs`), you must add the corresponding API group and resource to `clusterrole.yaml` and reapply using `kubectl apply -k .`
