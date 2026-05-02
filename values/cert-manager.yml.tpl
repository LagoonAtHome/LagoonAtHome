installCRDs: true
ingressShim:
  defaultIssuerName: ${CLUSTER_ISSUER}
  defaultIssuerKind: ClusterIssuer
  defaultIssuerGroup: cert-manager.io
