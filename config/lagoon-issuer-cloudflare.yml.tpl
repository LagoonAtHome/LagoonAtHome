apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token
  namespace: cert-manager
type: Opaque
stringData:
  api-token: ${CLOUDFLARE_API_TOKEN}
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: cloudflare-dns01
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${ACME_EMAIL}
    privateKeySecretRef:
      name: cloudflare-dns01
    solvers:
    - dns01:
        cloudflare:
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: api-token
