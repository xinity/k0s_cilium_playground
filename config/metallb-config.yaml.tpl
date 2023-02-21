apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb
spec:
  addresses:
  - METALLBIPRANGE
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: cilium-metallb
  namespace: metallb