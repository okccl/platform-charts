# platform-charts

Platform Engineering portfolio — Helm Library Chart リポジトリ

## 概要

アプリ開発者が Kubernetes を意識せずにサービスをデプロイできるよう、  
共通の Helm テンプレートを **Library Chart** として提供するリポジトリ。

「何を渡せばデプロイできるか」を `values.yaml` だけに集約することで、  
チームごとの Deployment / Ingress のばらつきをなくし、プラットフォームとしての一貫性を保つ。

## このリポジトリが示すもの

| Phase | 内容 |
|-------|------|
| Phase 5 | Library Chart（`common-app`）による Helm テンプレートの共通化。アプリ Chart は `values.yaml` のみを管理すればよい |
| Phase 8 | Library Chart（`common-db`）によるステートフルな PostgreSQL（CloudNativePG）のプロビジョニング抽象化 |

## ディレクトリ構成

```
platform-charts/
└── charts/
    ├── common-app/               # Library Chart（アプリ共通）
    │   ├── Chart.yaml
    │   ├── values.yaml           # デフォルト値
    │   └── templates/
    │       └── _helpers.tpl      # Deployment / Service / Ingress / HPA / ServiceMonitor を生成
    ├── common-db/                # Library Chart（PostgreSQL 共通）
    │   ├── Chart.yaml
    │   ├── values.yaml           # デフォルト値
    │   └── templates/
    │       └── _helpers.tpl      # CNPG Cluster / Backup Schedule を生成
    ├── sample-backend/           # common-app + common-db を使うアプリ Chart の例
    │   ├── Chart.yaml            # dependencies に common-app / common-db を宣言
    │   ├── Chart.lock
    │   ├── values.yaml
    │   └── templates/
    │       └── all.yaml          # Library Chart のヘルパーを呼び出すだけ
    └── sample-frontend/          # common-app を使うアプリ Chart の例
```

## common-app：アプリデプロイの抽象化

### 生成されるリソース

`_helpers.tpl` が `values.yaml` の内容に応じて以下を自動生成する。

| リソース | 生成条件 |
|---|---|
| `Deployment` | 常に生成 |
| `Service` | 常に生成 |
| `Ingress` | `ingress.enabled: true` |
| `HorizontalPodAutoscaler` | `hpa.enabled: true` |
| `ServiceMonitor` | `serviceMonitor.enabled: true`（Prometheus 自動収集） |

### アプリ側の values.yaml（sample-backend の例）

```yaml
app:
  name: sample-backend
image:
  repository: ghcr.io/okccl/sample-backend
  tag: latest
replicaCount: 2
containerPort: 8000
resources:
  requests: { cpu: 100m, memory: 128Mi }
  limits:   { cpu: 500m, memory: 256Mi }
probes:
  liveness:  { path: /health }
  readiness: { path: /health }
ingress:
  enabled: true
  host: sample-backend.localhost
serviceMonitor:
  enabled: true
  path: /metrics
  interval: 30s
```

この `values.yaml` だけで Deployment / Service / Ingress / ServiceMonitor が揃う。  
アプリ開発者が Kubernetes マニフェストを直接書く必要はない。

## common-db：PostgreSQL プロビジョニングの抽象化

CloudNativePG（CNPG）Operator を使った PostgreSQL クラスタを、  
`values.yaml` の数行で宣言できるようにする Library Chart。

### 生成されるリソース

| リソース | 生成条件 |
|---|---|
| `CNPG Cluster` | 常に生成（`instances` 数に応じてシングル / HA） |
| `Backup Schedule` | `backup.enabled: true`（MinIO へのバックアップ） |

### アプリ側の values.yaml（sample-backend の例）

```yaml
db:
  name: sample-backend-db
  instances: 2          # 2以上でHA構成
  postgresVersion: 17
  storageSize: 1Gi
  database: app
  owner: app
  backup:
    enabled: false
```

## 設計上の決定事項

- **Library Chart を選んだ理由**：`helm install` 単体では使えないため、テンプレートの「直接実行」を防げる。アプリ Chart を経由することで、アプリごとの設定上書きが明確になる。
- **`_helpers.tpl` に全テンプレートを集約した理由**：アプリ Chart 側の `all.yaml` が `{{ include "common-app.all" . }}` の1行になり、テンプレートのメンテナンス箇所が Library Chart に一元化される。
- **ServiceMonitor をデフォルト `false` にした理由**：Prometheus の `ServiceMonitor` CRD がない環境でも Chart が動作するように。

## 関連リポジトリ

| リポジトリ | 役割 |
|---|---|
| [`platform-gitops`](https://github.com/okccl/platform-gitops) | この Chart を OCI レジストリから参照して ArgoCD でデプロイ |
| [`sample-backend`](https://github.com/okccl/sample-backend) | `common-app` + `common-db` の利用例（API + PostgreSQL） |
| [`sample-frontend`](https://github.com/okccl/sample-frontend) | `common-app` の利用例（静的フロントエンド） |
