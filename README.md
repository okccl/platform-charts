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
| Phase 11 | `common-app` v0.2.0 で Argo Rollouts の `Rollout` リソースに対応。`rollout.enabled: true` でカナリア戦略に切り替え可能 |

## ディレクトリ構成

```
platform-charts/
└── charts/
    ├── common-app/               # Library Chart（アプリ共通）
    │   ├── Chart.yaml            # v0.3.0
    │   ├── values.yaml           # デフォルト値
    │   └── templates/
    │       └── _helpers.tpl      # Deployment / Rollout / Service / Ingress / HPA / ServiceMonitor を生成
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
    │       └── all.yaml          # rollout.enabled フラグで Deployment / Rollout を切り替え
    └── sample-frontend/          # common-app を使うアプリ Chart の例
```

## common-app：アプリデプロイの抽象化

### 生成されるリソース

`_helpers.tpl` が `values.yaml` の内容に応じて以下を自動生成する。

| リソース | 生成条件 |
|---|---|
| `Deployment` | `rollout.enabled: false`（デフォルト） |
| `Rollout`（Argo Rollouts） | `rollout.enabled: true` |
| `Service` | 常に生成（`name: http` ポート名付き） |
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
serviceMonitor:
  enabled: true
  path: /metrics
  interval: 30s
rollout:
  enabled: true
  canary:
    steps:
      - setWeight: 20
      - pause: {}
      - setWeight: 100
```

`rollout.enabled: true` にするだけで Deployment から Argo Rollouts のカナリア戦略に切り替わる。

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

## バージョン履歴（common-app）

| バージョン | 変更内容 |
|---|---|
| v0.1.0 | 初期リリース。Deployment / Service / Ingress / HPA / ServiceMonitor |
| v0.2.0 | `Rollout` テンプレート追加（Argo Rollouts カナリア対応） |
| v0.3.0 | Service の port に `name: http` を追加（ServiceMonitor の port 解決に必要） |

## 設計上の決定事項

- **Library Chart を選んだ理由**：`helm install` 単体では使えないため、テンプレートの「直接実行」を防げる。アプリ Chart を経由することで、アプリごとの設定上書きが明確になる。
- **`_helpers.tpl` に全テンプレートを集約した理由**：アプリ Chart 側の `all.yaml` が `{{ include "common-app.all" . }}` の1行になり、テンプレートのメンテナンス箇所が Library Chart に一元化される。
- **ServiceMonitor をデフォルト `false` にした理由**：Prometheus の `ServiceMonitor` CRD がない環境でも Chart が動作するように。
- **Rollout / Deployment をフラグで切り替える理由**：既存の Deployment 環境に対して values の変更だけでカナリア戦略を導入できる。Argo Rollouts がない環境でも同じ Chart が動作する。
- **Service に `name: http` を付与した理由**：ServiceMonitor の `port: http` 指定と一致させ、Prometheus が scrape ターゲットを正しく解決できるようにする。

## 関連リポジトリ

| リポジトリ | 役割 |
|---|---|
| [`platform-gitops`](https://github.com/okccl/platform-gitops) | この Chart を OCI レジストリから参照して ArgoCD でデプロイ |
| [`sample-backend`](https://github.com/okccl/sample-backend) | `common-app` + `common-db` の利用例（API + PostgreSQL） |
| [`sample-frontend`](https://github.com/okccl/sample-frontend) | `common-app` の利用例（静的フロントエンド） |
