expose:
  ingress:
    className: nginx
    annotations:
      cert-manager.io/cluster-issuer: ${CLUSTER_ISSUER}
      kubernetes.io/tls-acme: "true"
      nginx.ingress.kubernetes.io/proxy-buffering: "off"
      nginx.ingress.kubernetes.io/proxy-request-buffering: "off"
      nginx.ingress.kubernetes.io/ssl-redirect: "false"
    hosts:
      core: harbor.${DOMAIN}
  tls:
    enabled: true
    certSource: secret
    secret:
      secretName: harbor-ingress
externalURL: https://harbor.${DOMAIN}
harborAdminPassword: ${HARBOR_PASSWORD}
chartmuseum:
  enabled: false
clair:
  enabled: false
notary:
  enabled: false
trivy:
  enabled: false
jobservice:
  jobLogger: stdout
registry:
  relativeurls: true
