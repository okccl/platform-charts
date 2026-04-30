{{- define "common-app.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.app.name }}
  labels:
    app.kubernetes.io/name: {{ .Values.app.name }}
    app.kubernetes.io/version: {{ .Values.app.version }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ .Values.app.name }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ .Values.app.name }}
        app.kubernetes.io/version: {{ .Values.app.version }}
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/name: {{ .Values.app.name }}
                topologyKey: kubernetes.io/hostname
      {{- if .Values.image.pullSecretName }}
      imagePullSecrets:
        - name: {{ .Values.image.pullSecretName }}
      {{- end }}
      containers:
        - name: {{ .Values.app.name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.containerPort }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          {{- if .Values.db.name }}
          env:
            - name: DB_HOST
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.db.name }}-app
                  key: host
            - name: DB_PORT
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.db.name }}-app
                  key: port
            - name: DB_NAME
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.db.name }}-app
                  key: dbname
            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.db.name }}-app
                  key: username
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.db.name }}-app
                  key: password
          {{- end }}
          {{- if .Values.env }}
          {{- toYaml .Values.env | nindent 12 }}
          {{- end }}
          lifecycle:
            preStop:
              exec:
                # Endpoints除外の伝搬を待ってからシャットダウン開始
                command: ["/bin/sh", "-c", "sleep 5"]
          livenessProbe:
            httpGet:
              path: {{ .Values.probes.liveness.path }}
              port: {{ .Values.containerPort }}
            initialDelaySeconds: {{ .Values.probes.liveness.initialDelaySeconds }}
            periodSeconds: {{ .Values.probes.liveness.periodSeconds }}
          readinessProbe:
            httpGet:
              path: {{ .Values.probes.readiness.path }}
              port: {{ .Values.containerPort }}
            initialDelaySeconds: {{ .Values.probes.readiness.initialDelaySeconds }}
            periodSeconds: {{ .Values.probes.readiness.periodSeconds }}
{{- end }}
{{- define "common-app.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.app.name }}
  labels:
    app.kubernetes.io/name: {{ .Values.app.name }}
spec:
  selector:
    app.kubernetes.io/name: {{ .Values.app.name }}
  ports:
    - protocol: TCP
      port: 80
      targetPort: {{ .Values.containerPort }}
{{- end }}
{{- define "common-app.ingress" -}}
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .Values.app.name }}
  annotations:
    cert-manager.io/cluster-issuer: selfsigned-issuer
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - {{ .Values.ingress.host }}
      secretName: {{ .Values.app.name }}-tls
  rules:
    - host: {{ .Values.ingress.host }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ .Values.app.name }}
                port:
                  number: 80
{{- end }}
{{- end }}
{{- define "common-app.hpa" -}}
{{- if .Values.hpa.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ .Values.app.name }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ .Values.app.name }}
  minReplicas: {{ .Values.hpa.minReplicas }}
  maxReplicas: {{ .Values.hpa.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.hpa.targetCPUUtilizationPercentage }}
{{- end }}
{{- end }}
{{- define "common-app.serviceMonitor" -}}
{{- if .Values.serviceMonitor.enabled }}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ .Values.app.name }}
  labels:
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ .Values.app.name }}
  endpoints:
    - port: http
      path: {{ .Values.serviceMonitor.path }}
      interval: {{ .Values.serviceMonitor.interval }}
{{- end }}
{{- end }}
{{- define "common-app.rollout" -}}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: {{ .Values.app.name }}
  labels:
    app.kubernetes.io/name: {{ .Values.app.name }}
    app.kubernetes.io/version: {{ .Values.app.version }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ .Values.app.name }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ .Values.app.name }}
        app.kubernetes.io/version: {{ .Values.app.version }}
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/name: {{ .Values.app.name }}
                topologyKey: kubernetes.io/hostname
      {{- if .Values.image.pullSecretName }}
      imagePullSecrets:
        - name: {{ .Values.image.pullSecretName }}
      {{- end }}
      containers:
        - name: {{ .Values.app.name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.containerPort }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          {{- if .Values.db.name }}
          env:
            - name: DB_HOST
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.db.name }}-app
                  key: host
            - name: DB_PORT
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.db.name }}-app
                  key: port
            - name: DB_NAME
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.db.name }}-app
                  key: dbname
            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.db.name }}-app
                  key: username
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.db.name }}-app
                  key: password
          {{- end }}
          {{- if .Values.env }}
          {{- toYaml .Values.env | nindent 12 }}
          {{- end }}
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh", "-c", "sleep 5"]
          livenessProbe:
            httpGet:
              path: {{ .Values.probes.liveness.path }}
              port: {{ .Values.containerPort }}
            initialDelaySeconds: {{ .Values.probes.liveness.initialDelaySeconds }}
            periodSeconds: {{ .Values.probes.liveness.periodSeconds }}
          readinessProbe:
            httpGet:
              path: {{ .Values.probes.readiness.path }}
              port: {{ .Values.containerPort }}
            initialDelaySeconds: {{ .Values.probes.readiness.initialDelaySeconds }}
            periodSeconds: {{ .Values.probes.readiness.periodSeconds }}
  strategy:
    canary:
      steps:
        {{- toYaml .Values.rollout.canary.steps | nindent 8 }}
{{- end }}
