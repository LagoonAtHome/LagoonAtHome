lagoonSeedUsername: ${ADMIN_EMAIL}
lagoonSeedPassword: ${ADMIN_PASSWORD}
lagoonSeedOrganization: ${ORG_NAME}

s3BAASAccessKeyID: admin
s3BAASSecretAccessKey: ${MINIO_PASSWORD}
s3FilesAccessKeyID: admin
s3FilesSecretAccessKey: ${MINIO_PASSWORD}
s3FilesBucket: lagoon-files
s3FilesHost: https://minio-api.${DOMAIN}

harborURL: http://harbor.${DOMAIN}
harborAdminPassword: ${HARBOR_PASSWORD}

lagoonAPIURL: https://api.${DOMAIN}/graphql
keycloakFrontEndURL: https://keycloak.${DOMAIN}
lagoonUIURL: https://dashboard.${DOMAIN}
sshTokenEndpoint: https://ssh-token.${DOMAIN}

elasticsearchURL: http://opendistro-es-client-service.opendistro-es.svc.cluster.local:9200
kibanaURL: http://opendistro-es-kibana-svc.opendistro-es.svc.cluster.local:443

rabbitMQPassword: password

api:
  replicaCount: 1
  image:
    repository: uselagoon/api
  resources:
    requests:
      cpu: "10m"
  ingress:
    enabled: true
    hosts:
      - host: api.${DOMAIN}
        paths:
          - /
    tls:
      - hosts:
          - api.${DOMAIN}
        secretName: api-tls
    annotations:
      cert-manager.io/cluster-issuer: ${CLUSTER_ISSUER}
      kubernetes.io/tls-acme: "true"
      nginx.ingress.kubernetes.io/ssl-redirect: "false"

apiDB:
  image:
    repository: uselagoon/api-db
  storageSize: 16Gi
  resources:
    requests:
      cpu: "10m"

apiRedis:
  image:
    repository: uselagoon/api-redis
  resources:
    requests:
      cpu: "10m"

apiSidecarHandler:
  image:
    repository: uselagoon/api-sidecar-handler

actionsHandler:
  replicaCount: 1
  image:
    repository: uselagoon/actions-handler

keycloak:
  realmSettings:
    enabled: true
    options:
      resetPasswordAllowed: true
      rememberMe: true
  email:
    enabled: true
    settings:
      host: mailhog
      port: '1025'
      fromDisplayName: Lagoon
      from: lagoon@example.com
      replyToDisplayName: Lagoon No-Reply
      replyTo: lagoon@example.com
      envelopeFrom: lagoon@example.com
  image:
    repository: uselagoon/keycloak
  resources:
    requests:
      cpu: "10m"
  ingress:
    enabled: true
    hosts:
      - host: keycloak.${DOMAIN}
        paths:
          - /
    tls:
      - hosts:
          - keycloak.${DOMAIN}
        secretName: keycloak-tls
    annotations:
      cert-manager.io/cluster-issuer: ${CLUSTER_ISSUER}
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
  serviceMonitor:
    enabled: false

keycloakDB:
  image:
    repository: uselagoon/keycloak-db
  resources:
    requests:
      cpu: "10m"

broker:
  replicaCount: 1
  serviceMonitor:
    enabled: false
  image:
    repository: uselagoon/broker
  resources:
    requests:
      cpu: "10m"
  tls:
    enabled: false
    secretName: broker-tls
  ingress:
    enabled: true
    hosts:
      - host: broker.${DOMAIN}
        paths:
          - /
    tls:
      - hosts:
          - broker.${DOMAIN}
        secretName: broker-tls
    annotations:
      cert-manager.io/cluster-issuer: ${CLUSTER_ISSUER}
      kubernetes.io/tls-acme: "true"
      nginx.ingress.kubernetes.io/ssl-redirect: "false"

authServer:
  replicaCount: 1
  image:
    repository: uselagoon/auth-server
  resources:
    requests:
      cpu: "10m"

webhooks2tasks:
  replicaCount: 1
  image:
    repository: uselagoon/webhooks2tasks
  resources:
    requests:
      cpu: "10m"

webhookHandler:
  replicaCount: 1
  image:
    repository: uselagoon/webhook-handler
  resources:
    requests:
      cpu: "10m"

ui:
  replicaCount: 1
  image:
    repository: uselagoon/ui
  resources:
    requests:
      cpu: "10m"
  ingress:
    enabled: true
    hosts:
      - host: dashboard.${DOMAIN}
        paths:
          - /
    tls:
      - hosts:
          - dashboard.${DOMAIN}
        secretName: ui-tls
    annotations:
      cert-manager.io/cluster-issuer: ${CLUSTER_ISSUER}
      nginx.ingress.kubernetes.io/ssl-redirect: "true"

backupHandler:
  replicaCount: 1
  image:
    repository: uselagoon/backup-handler
  resources:
    requests:
      cpu: "10m"

insightsHandler:
  enabled: true
  image:
    repository: uselagoon/insights-handler

logs2notifications:
  replicaCount: 1
  image:
    repository: uselagoon/logs2notifications

drushAlias:
  replicaCount: 1
  image:
    repository: uselagoon/drush-alias

ssh:
  service:
    type: LoadBalancer
    port: 2020
  replicaCount: 1
  image:
    repository: uselagoon/ssh
  resources:
    requests:
      cpu: "10m"

sshPortalAPI:
  enabled: true
  replicaCount: 1
  debug: true
  insecureTLS: true
  serviceMonitor:
    enabled: false
  command:
    - /bin/sh
  args:
    - '-c'
    - >-
      i=0; while [ $i -le 5 ]; do /ssh-portal-api &&
      exit; sleep 10; let i=i+1; done

sshToken:
  enabled: true
  replicaCount: 1
  debug: true
  insecureTLS: true
  serviceMonitor:
    enabled: false
  service:
    type: LoadBalancer
    ports:
      sshserver: 2223
  command:
    - /bin/sh
  args:
    - '-c'
    - >-
      i=0; while [ $i -le 5 ]; do /ssh-token &&
      exit; sleep 10; let i=i+1; done

controllerhandler:
  replicaCount: 1
  image:
    repository: uselagoon/controllerhandler

imageTag: ""

nats:
  enabled: true
  tlsCA:
    enabled: false

natsService:
  type: ClusterIP

natsConfig:
  users:
    lagoonRemote:
      - user: ci-ssh-portal
        password: ci-password
  tls:
    enabled: true
  tlsCA:
    enabled: false
