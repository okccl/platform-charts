{{- define "common-db.cluster" -}}
{{- if .Values.db.enabled -}}
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: {{ .Values.db.name }}
  labels:
    app.kubernetes.io/name: {{ .Values.db.name }}
spec:
  instances: {{ .Values.db.instances }}
  imageName: ghcr.io/cloudnative-pg/postgresql:{{ .Values.db.postgresVersion }}

  postgresql:
    pg_hba:
      - host all all 0.0.0.0/0 scram-sha-256

  bootstrap:
{{- if and .Values.db.recovery .Values.db.recovery.enabled }}
    recovery:
      source: {{ .Values.db.recovery.source }}
{{- else }}
    initdb:
      database: {{ .Values.db.database }}
      owner: {{ .Values.db.owner }}
{{- end }}

{{- if and .Values.db.recovery .Values.db.recovery.enabled }}
  externalClusters:
    - name: {{ .Values.db.recovery.source }}
      barmanObjectStore:
        endpointURL: {{ .Values.db.recovery.endpointURL | quote }}
        destinationPath: s3://{{ .Values.db.recovery.bucketName }}/{{ .Values.db.name }}
        serverName: {{ .Values.db.name }}
        s3Credentials:
          accessKeyId:
            name: {{ .Values.db.recovery.secretName }}
            key: ACCESS_KEY_ID
          secretAccessKey:
            name: {{ .Values.db.recovery.secretName }}
            key: ACCESS_SECRET_KEY
        wal:
          compression: gzip
        data:
          compression: gzip
{{- end }}

  storage:
    size: {{ .Values.db.storageSize }}
    {{- if .Values.db.storageClassName }}
    storageClass: {{ .Values.db.storageClassName }}
    {{- end }}

  resources:
    {{- toYaml .Values.db.resources | nindent 4 }}

  {{- if .Values.db.backup.enabled }}
  backup:
    barmanObjectStore:
      endpointURL: {{ .Values.db.backup.endpointURL }}
      destinationPath: s3://{{ .Values.db.backup.bucketName }}/{{ .Values.db.name }}
      s3Credentials:
        accessKeyId:
          name: {{ .Values.db.backup.secretName }}
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: {{ .Values.db.backup.secretName }}
          key: ACCESS_SECRET_KEY
      wal:
        compression: gzip
      data:
        compression: gzip
    retentionPolicy: "7d"
  {{- end }}
  monitoring:
    enablePodMonitor: {{ .Values.db.monitoring.enablePodMonitor }}
{{- end }}
{{- end }}

{{- define "common-db.scheduledBackup" -}}
{{- if and .Values.db.enabled .Values.db.backup.enabled }}
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: {{ .Values.db.name }}-backup
spec:
  schedule: "0 2 * * *"
  backupOwnerReference: self
  cluster:
    name: {{ .Values.db.name }}
{{- end }}
{{- end }}
