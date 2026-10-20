<!-- Loaded on demand by skills/argo-knowledge/SKILL.md. Each pattern is a validated
     starting point — adapt to the user's specifics rather than pasting verbatim. -->

# Canonical YAML Patterns

Ten validated starting points covering the four Argo projects. Every manifest uses
`apiVersion: argoproj.io/v1alpha1` and real field names from the Argo CRD schemas.

| # | Pattern | Project |
|---|---------|---------|
| 1 | Application with Helm source | Argo CD |
| 2 | Application with Kustomize source | Argo CD |
| 3 | ApplicationSet with git directory generator | Argo CD |
| 4 | ApplicationSet with cluster generator + matrix | Argo CD |
| 5 | Rollout with canary strategy + AnalysisTemplate | Rollouts |
| 6 | Rollout with blue-green strategy | Rollouts |
| 7 | Workflow DAG pattern | Workflows |
| 8 | EventSource + Sensor triggering a Workflow | Events |
| 9 | Notifications config (`argocd-notifications-cm`) | Argo CD |
| 10 | Image updater annotations | Argo CD |

## Pattern 1: Application with Helm Source

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://charts.example.com
    chart: my-app
    targetRevision: 1.2.3
    helm:
      releaseName: my-app
      valuesObject:
        replicaCount: 3
        image:
          repository: registry.example.com/my-app
          tag: latest
        ingress:
          enabled: true
          hosts:
            - my-app.example.com
      parameters:
        - name: service.type
          value: ClusterIP
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

## Pattern 2: Application with Kustomize Source

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/k8s-configs.git
    targetRevision: main
    path: apps/my-app/overlays/production
    kustomize:
      namePrefix: prod-
      commonLabels:
        environment: production
      images:
        - registry.example.com/my-app:v2.1.0
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Pattern 3: ApplicationSet with Git Directory Generator

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-addons
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions:
    - missingkey=error
  generators:
    - git:
        repoURL: https://github.com/org/cluster-addons.git
        revision: main
        directories:
          - path: addons/*
          - path: addons/experimental-*
            exclude: true
  preserveResourcesOnDeletion: true
  template:
    metadata:
      name: 'addon-{{.path.basename}}'
      labels:
        envLabel: staging
    spec:
      project: cluster-addons
      source:
        repoURL: https://github.com/org/cluster-addons.git
        targetRevision: main
        path: '{{.path.path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{.path.basename}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
  strategy:
    type: RollingSync
    rollingSync:
      steps:
        - matchExpressions:
            - key: envLabel
              operator: In
              values:
                - staging
          maxUpdate: 100%
        - matchExpressions:
            - key: envLabel
              operator: In
              values:
                - production
          maxUpdate: 25%
```

## Pattern 4: ApplicationSet with Cluster Generator + Matrix

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: platform-services
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions:
    - missingkey=error
  preserveResourcesOnDeletion: true
  generators:
    - matrix:
        generators:
          - clusters:
              selector:
                matchLabels:
                  tier: production
              values:
                revision: main
          - list:
              elements:
                - app: ingress-nginx
                  namespace: ingress-nginx
                  path: platform/ingress-nginx
                - app: cert-manager
                  namespace: cert-manager
                  path: platform/cert-manager
                - app: monitoring
                  namespace: monitoring
                  path: platform/monitoring
  template:
    metadata:
      name: '{{.name}}-{{.app}}'
    spec:
      project: platform
      source:
        repoURL: https://github.com/org/platform-config.git
        targetRevision: '{{.values.revision}}'
        path: '{{.path}}'
      destination:
        server: '{{.server}}'
        namespace: '{{.namespace}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
          - ServerSideApply=true
```

## Pattern 5: Rollout with Canary Strategy + AnalysisTemplate

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-app
  namespace: my-app
spec:
  replicas: 5
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: my-app
          image: registry.example.com/my-app:v2.0.0
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
  strategy:
    canary:
      maxSurge: 1
      maxUnavailable: 0
      steps:
        - setWeight: 10
        - pause: { duration: 2m }
        - setWeight: 30
        - analysis:
            templates:
              - templateName: success-rate
            args:
              - name: service-name
                value: my-app
        - setWeight: 60
        - pause: { duration: 5m }
        - setWeight: 100
      canaryService: my-app-canary
      stableService: my-app-stable
      trafficRouting:
        istio:
          virtualServices:
            - name: my-app-vsvc
              routes:
                - primary
---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
  namespace: my-app
spec:
  args:
    - name: service-name
  metrics:
    - name: success-rate
      interval: 60s
      count: 5
      successCondition: result[0] >= 0.95
      failureLimit: 2
      provider:
        prometheus:
          address: http://prometheus.monitoring:9090
          query: |
            sum(rate(http_requests_total{service="{{args.service-name}}", status=~"2.."}[5m]))
            /
            sum(rate(http_requests_total{service="{{args.service-name}}"}[5m]))
```

## Pattern 6: Rollout with Blue-Green Strategy

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-app
  namespace: my-app
spec:
  replicas: 3
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: my-app
          image: registry.example.com/my-app:v2.0.0
          ports:
            - containerPort: 8080
  strategy:
    blueGreen:
      activeService: my-app-active
      previewService: my-app-preview
      autoPromotionEnabled: false
      scaleDownDelaySeconds: 30
      prePromotionAnalysis:
        templates:
          - templateName: smoke-test
        args:
          - name: preview-url
            value: http://my-app-preview.my-app.svc.cluster.local
      postPromotionAnalysis:
        templates:
          - templateName: success-rate
        args:
          - name: service-name
            value: my-app
```

## Pattern 7: Workflow DAG Pattern

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: ci-pipeline-
  namespace: argo
spec:
  entrypoint: ci-pipeline
  serviceAccountName: argo-workflow
  arguments:
    parameters:
      - name: repo-url
        value: https://github.com/org/my-app.git
      - name: revision
        value: main
      - name: image
        value: registry.example.com/my-app
  templates:
    - name: ci-pipeline
      dag:
        tasks:
          - name: checkout
            template: git-clone
            arguments:
              parameters:
                - name: repo-url
                  value: '{{workflow.parameters.repo-url}}'
                - name: revision
                  value: '{{workflow.parameters.revision}}'
          - name: unit-test
            template: run-tests
            dependencies:
              - checkout
          - name: lint
            template: run-lint
            dependencies:
              - checkout
          - name: build-image
            template: build-push
            dependencies:
              - unit-test
              - lint
            arguments:
              parameters:
                - name: image
                  value: '{{workflow.parameters.image}}'
    - name: git-clone
      inputs:
        parameters:
          - name: repo-url
          - name: revision
      container:
        image: alpine/git:latest
        command: [sh, -c]
        args:
          - git clone --branch {{inputs.parameters.revision}} {{inputs.parameters.repo-url}} /work
        volumeMounts:
          - name: work
            mountPath: /work
    - name: run-tests
      container:
        image: golang:1.22
        command: [sh, -c]
        args:
          - cd /work && go test ./...
        volumeMounts:
          - name: work
            mountPath: /work
    - name: run-lint
      container:
        image: golangci/golangci-lint:latest
        command: [sh, -c]
        args:
          - cd /work && golangci-lint run
        volumeMounts:
          - name: work
            mountPath: /work
    - name: build-push
      inputs:
        parameters:
          - name: image
      container:
        image: gcr.io/kaniko-project/executor:latest
        args:
          - --context=/work
          - --destination={{inputs.parameters.image}}:{{workflow.uid}}
        volumeMounts:
          - name: work
            mountPath: /work
  volumeClaimTemplates:
    - metadata:
        name: work
      spec:
        accessModes: [ReadWriteOnce]
        resources:
          requests:
            storage: 1Gi
```

## Pattern 8: EventSource + Sensor Triggering a Workflow

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: github-webhook
  namespace: argo-events
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  github:
    push-events:
      repositories:
        - owner: my-org
          names:
            - my-app
      webhook:
        endpoint: /push
        port: "12000"
        method: POST
      events:
        - push
      apiToken:
        name: github-token
        key: token
      webhookSecret:
        name: github-token
        key: webhook-secret
      contentType: json
      active: true
---
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: default
  namespace: argo-events
spec:
  jetstream:
    version: latest
    replicas: 3
    persistence:
      storageClassName: standard
      accessMode: ReadWriteOnce
      volumeSize: 20Gi
---
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: github-sensor
  namespace: argo-events
spec:
  dependencies:
    - name: github-push
      eventSourceName: github-webhook
      eventName: push-events
      filters:
        data:
          - path: body.ref
            type: string
            value:
              - refs/heads/main
  triggers:
    - template:
        name: trigger-ci
        argoWorkflow:
          operation: submit
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: ci-triggered-
                namespace: argo
              spec:
                entrypoint: build
                arguments:
                  parameters:
                    - name: repo-url
                    - name: revision
                templates:
                  - name: build
                    container:
                      image: golang:1.22
                      command: [sh, -c]
                      args:
                        - |
                          echo "Building {{workflow.parameters.repo-url}} at {{workflow.parameters.revision}}"
          parameters:
            - src:
                dependencyName: github-push
                dataKey: body.repository.clone_url
              dest: spec.arguments.parameters.0.value
            - src:
                dependencyName: github-push
                dataKey: body.after
              dest: spec.arguments.parameters.1.value
```

## Pattern 9: Notifications Config (argocd-notifications-cm)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: $slack-token
    signingSecret: $slack-signing-secret
  template.app-sync-succeeded: |
    message: |
      Application {{.app.metadata.name}} has been successfully synced.
      Revision: {{.app.status.sync.revision}}
      Project: {{.app.spec.project}}
    slack:
      attachments: |
        [{
          "color": "#18be52",
          "title": "{{.app.metadata.name}} synced",
          "title_link": "{{.context.argocdUrl}}/applications/{{.app.metadata.name}}",
          "fields": [
            {"title": "Project", "value": "{{.app.spec.project}}", "short": true},
            {"title": "Revision", "value": "{{.app.status.sync.revision | trunc 7}}", "short": true}
          ]
        }]
  template.app-sync-failed: |
    message: |
      Application {{.app.metadata.name}} sync failed.
      Error: {{.app.status.operationState.message}}
    slack:
      attachments: |
        [{
          "color": "#E96D76",
          "title": "{{.app.metadata.name}} sync failed",
          "title_link": "{{.context.argocdUrl}}/applications/{{.app.metadata.name}}",
          "fields": [
            {"title": "Project", "value": "{{.app.spec.project}}", "short": true},
            {"title": "Error", "value": "{{.app.status.operationState.message}}", "short": false}
          ]
        }]
  template.app-health-degraded: |
    message: |
      Application {{.app.metadata.name}} is degraded.
    slack:
      attachments: |
        [{
          "color": "#f4c030",
          "title": "{{.app.metadata.name}} degraded",
          "title_link": "{{.context.argocdUrl}}/applications/{{.app.metadata.name}}"
        }]
  trigger.on-sync-succeeded: |
    - when: app.status.operationState.phase in ['Succeeded']
      send: [app-sync-succeeded]
  trigger.on-sync-failed: |
    - when: app.status.operationState.phase in ['Error', 'Failed']
      send: [app-sync-failed]
  trigger.on-health-degraded: |
    - when: app.status.health.status == 'Degraded'
      send: [app-health-degraded]
---
apiVersion: v1
kind: Secret
metadata:
  name: argocd-notifications-secret
  namespace: argocd
type: Opaque
stringData:
  slack-token: xoxb-XXXXXXXXX
  slack-signing-secret: XXXXXXXXX
```

**Application annotation to subscribe:**

```yaml
metadata:
  annotations:
    notifications.argoproj.io/subscribe.on-sync-failed.slack: my-channel
    notifications.argoproj.io/subscribe.on-health-degraded.slack: my-channel
    notifications.argoproj.io/subscribe.on-sync-succeeded.slack: deployments
```

## Pattern 10: Image Updater Annotations

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
  annotations:
    argocd-image-updater.argoproj.io/image-list: myapp=registry.example.com/my-app
    argocd-image-updater.argoproj.io/myapp.update-strategy: semver
    argocd-image-updater.argoproj.io/myapp.allow-tags: "regexp:^v[0-9]+\\.[0-9]+\\.[0-9]+$"
    argocd-image-updater.argoproj.io/myapp.ignore-tags: "latest,dev-*"
    argocd-image-updater.argoproj.io/myapp.pull-secret: pullsecret:argocd/registry-creds
    argocd-image-updater.argoproj.io/write-back-method: git
    argocd-image-updater.argoproj.io/write-back-target: kustomization
    argocd-image-updater.argoproj.io/git-branch: main
spec:
  project: default
  source:
    repoURL: https://github.com/org/k8s-configs.git
    targetRevision: main
    path: apps/my-app/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Match the write-back target to the source type.** The example above is a Kustomize
overlay, so it uses `write-back-target: kustomization`. For a **Helm** source, drop that
annotation and point the updater at the chart's value keys instead:

```yaml
    argocd-image-updater.argoproj.io/myapp.helm.image-name: image.repository
    argocd-image-updater.argoproj.io/myapp.helm.image-tag: image.tag
    argocd-image-updater.argoproj.io/write-back-method: git
    argocd-image-updater.argoproj.io/write-back-target: helmvalues:./values.yaml
```

The `helm.image-name`/`helm.image-tag` annotations are silently ignored on a Kustomize
source, and `write-back-target: kustomization` is ignored on a Helm source — mixing them
produces an updater that appears configured but never writes anything back.
