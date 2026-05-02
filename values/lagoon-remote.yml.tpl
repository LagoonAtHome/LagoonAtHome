global:
  rabbitMQUsername: lagoon
  rabbitMQPassword: password
  rabbitMQHostname: lagoon-core-broker.lagoon-core.svc:5672
  broker:
    tls:
      enabled: false
    tlsCA:
      enabled: false
      secretName: lagoon-remote-broker-tls

lagoon-build-deploy:
  enabled: true
  lagoonTargetName: ${ORG_NAME}
  lagoonFeatureFlagForceRWX2RWO: enabled
  rabbitMQUsername: lagoon
  rabbitMQPassword: password
  rabbitMQHostname: lagoon-core-broker.lagoon-core.svc:5672
  sshPortalHost: lagoon-remote-ssh-portal.lagoon.svc
  sshPortalPort: 22
  lagoonTokenHost: lagoon-core-token.lagoon-core.svc
  lagoonTokenPort: 2223
  lagoonAPIHost: http://lagoon-core-api.lagoon-core.svc:80
  extraArgs:
    - "--skip-tls-verify=true"
  harbor:
    enabled: ${INSTALL_HARBOR}
    host: https://harbor.${DOMAIN}
    adminUser: admin
    adminPassword: ${HARBOR_PASSWORD}
  broker:
    tls:
      enabled: false
    tlsCA:
      enabled: false
      secretName: lagoon-remote-broker-tls

dockerHost:
  name: docker-host
  image:
    repository: uselagoon/docker-host
  storage:
    size: 50Gi

imageTag: ""

dbaas-operator:
  enabled: true
  enablePostreSQLProviders: true
  postgresqlProviders:
    production:
      environment: production
      hostname: postgresql.postgresql.svc.cluster.local
      password: ${POSTGRES_PASSWORD}
      port: 5432
      user: postgres
    development:
      environment: development
      hostname: postgresql.postgresql.svc.cluster.local
      password: ${POSTGRES_PASSWORD}
      port: 5432
      user: postgres
  enableMariaDBProviders: true
  mariadbProviders:
    production:
      environment: production
      hostname: mariadb.mariadb.svc.cluster.local
      password: ${MARIADB_PASSWORD}
      port: 3306
      user: root
    development:
      environment: development
      hostname: mariadb.mariadb.svc.cluster.local
      password: ${MARIADB_PASSWORD}
      port: 3306
      user: root

insightsRemote:
  enabled: true

mxoutHost: mxout1.example.com

nats:
  enabled: true
  config:
    cluster:
      name: lagoon-remote-ci-example

natsConfig:
  coreURL: "tls://ci-ssh-portal:ci-password@lagoon-core-nats-concentrator.lagoon-core.svc:7422"
  tls:
    caOnly: true

sshPortal:
  enabled: true
  replicaCount: 1
  debug: true
  serviceMonitor:
    enabled: false
  service:
    type: NodePort
    ports:
      sshserver: 2222
  logAccessEnabled: true

storageCalculator:
  enabled: true
  serviceMonitor:
    enabled: false
