apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: registry-tls
  namespace: registry
spec:
  secretName: registry-tls
  issuerRef:
    name: lagoon-issuer
    kind: ClusterIssuer
  commonName: registry.${DOMAIN}
  dnsNames:
    - registry.${DOMAIN}
