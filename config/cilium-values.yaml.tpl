        extensions: 
          helm: 
            repositories: 
            - name: metallb  
              url: https://metallb.github.io/metallb 
            - name: cilium 
              url: https://helm.cilium.io/ 
            charts: 
            - name: metallb 
              chartname: metallb/metallb 
              namespace: metallb
              version: METALLBVERS
            - name: cilium 
              chartname: cilium/cilium 
              version: CILIUMVERS
              values: |2 
                cluster: 
                  name: CLUSTERNAME 
                  id: CLUSTERID 
                rollOutCiliumPods: true 
                hubble: 
                  enabled: true 
                  metrics: 
                    enabled:  
                    - dns:query;ignoreAAAA 
                    - drop 
                    - tcp 
                    - flow 
                    - icmp 
                    - http    
                    port: 9965 
                    serviceAnnotations: {} 
                    serviceMonitor: 
                      enabled: false 
                      labels: {} 
                      annotations: {} 
                      metricRelabelings: ~ 
                  relay: 
                    enabled: true 
                    rollOutPods: true 
                    prometheus: 
                      enabled: true 
                      port: 9966 
                      serviceMonitor: 
                        enabled: false 
                        labels: {} 
                        annotations: {} 
                        interval: "10s" 
                        metricRelabelings: ~ 
                  ui: 
                    enabled: true 
                    standalone: 
                      enabled: false 
                      tls: 
                        certsVolume: {} 
                    rollOutPods: true 
                ipam: 
                  mode: "cluster-pool" 
                  operator: 
                    clusterPoolIPv4PodCIDR: "10.244.0.0/16" 
                    clusterPoolIPv4PodCIDRList: ["10.244.0.0/16"] 
                    clusterPoolIPv4MaskSize: 24 
                    clusterPoolIPv6PodCIDR: "fd00::/104" 
                    clusterPoolIPv6PodCIDRList: [] 
                    clusterPoolIPv6MaskSize: 120 
                prometheus: 
                  enabled: true 
                  port: 9962 
                  serviceMonitor: 
                    enabled: false 
                    labels: {} 
                    annotations: {} 
                    metricRelabelings: ~ 
                operator: 
                  enabled: true 
                  rollOutPods: true 
                  prometheus: 
                    enabled: true 
                    port: 9963 
                    serviceMonitor: 
                      enabled: false 
                      labels: {} 
                      annotations: {} 
                      metricRelabelings: ~ 
                  skipCRDCreation: false 
                  removeNodeTaints: true 
                  setNodeNetworkStatus: true 
                  unmanagedPodWatcher: 
                    restart: true 
                    intervalSeconds: 15 
                k8sServiceHost: CNODE
                k8sServicePort: 6443 
                kubeProxyReplacement: "strict" 
                kubeProxyReplacementHealthzBindAddr: "0.0.0.0:10256" 
              namespace: cilium
