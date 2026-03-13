auth:
  rootUser: admin
  rootPassword: "${MINIO_PASSWORD}"
defaultBuckets: 'lagoon-files,restores'
ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    cert-manager.io/cluster-issuer: ${CLUSTER_ISSUER}
  hosts:
    - host: minio-api.${DOMAIN}
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - minio-api.${DOMAIN}
      secretName: minio-api-tls
consoleIngress:
  enabled: true
  ingressClassName: nginx
  annotations:
    cert-manager.io/cluster-issuer: ${CLUSTER_ISSUER}
  hosts:
    - host: minio.${DOMAIN}
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - minio.${DOMAIN}
      secretName: minio-console-tls
