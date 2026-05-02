config:
  baseURL: "headlamp.${DOMAIN}"

ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: headlamp.${DOMAIN}
      paths:
      - path: /
        type: ImplementationSpecific
