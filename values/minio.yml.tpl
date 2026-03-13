auth:
  rootUser: admin
  rootPassword: "${MINIO_PASSWORD}"
defaultBuckets: 'lagoon-files,restores'
ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    cert-manager.io/cluster-issuer: ${CLUSTER_ISSUER}
  tls: true
  hostname: minio-api.${DOMAIN}
console:
  ingress:
    enabled: true
    ingressClassName: nginx
    tls: true
    annotations:
      cert-manager.io/cluster-issuer: ${CLUSTER_ISSUER}
    hostname: minio.${DOMAIN}
