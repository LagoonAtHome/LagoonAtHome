auth:
  rootUser: admin
  rootPassword: "${MINIO_PASSWORD}"
defaultBuckets: 'lagoon-files,restores'
ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    cert-manager.io/cluster-issuer: ${CLUSTER_ISSUER}
    # S3 SigV4 signs the canonical request including headers; nginx must not buffer or
    # rewrite the body, and must not redirect (a 308 strips Authorization on follow).
    nginx.ingress.kubernetes.io/proxy-buffering: "off"
    nginx.ingress.kubernetes.io/proxy-request-buffering: "off"
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
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
