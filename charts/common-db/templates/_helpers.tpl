{{- define "common-db.cluster" -}}
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
    initdb:
      database: {{ .Values.db.database }}
      owner: {{ .Values.db.owner }}

  storage:
    size: {{ .Values.db.storageSize }}

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
{{- end }}

{{- define "common-db.scheduledBackup" -}}
{{- if .Values.db.backup.enabled }}
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
