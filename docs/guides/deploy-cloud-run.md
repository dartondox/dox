---
icon: lucide/cloud
---

# Deploy to Google Cloud Run

Run the blog API on [Cloud Run](https://cloud.google.com/run) from the `Dockerfile` of your project, with Postgres on Cloud SQL and secrets in Secret Manager.

Cloud Run is a good fit when you want Google to run and scale the containers for you. You give it an image, and it gives you an HTTPS URL.

## What you need

- A Google Cloud project with billing, and the `gcloud` CLI (`gcloud auth login`, `gcloud config set project PROJECT_ID`).
- The blog API from the [tutorial](../tutorial/01-create-project.md), or any Dox app, with the `Dockerfile` of a new Dox app. See [Docker](docker.md) for how that file works.
- A Cloud SQL for PostgreSQL instance with a database and a user. See step 3.

## Choosing the port

Cloud Run tells the container which port to use with the `PORT` env variable. It is `8080` by default, or the `--port` value.
Dox listens on `APP_PORT`, or on `PORT` when `APP_PORT` is not set. So do not set `APP_PORT` on Cloud Run. If you do set it, pass the same port with `--port`.

## 1. Turn on the APIs

Cloud Run, Cloud Build, Artifact Registry, Secret Manager and Cloud SQL are all off in a new project. Turn them on once:

```bash
gcloud services enable run.googleapis.com cloudbuild.googleapis.com \
  artifactregistry.googleapis.com secretmanager.googleapis.com sqladmin.googleapis.com
```

## 2. Save the secrets in Secret Manager

You should keep `APP_KEY` and the database password out of the plain env variables, because anyone who can see the service can read those. Save them in Secret Manager:

```bash
openssl rand -hex 16 | tr -d '\n' | gcloud secrets create blog-app-key --data-file=-
printf '%s' '<the database password>' | gcloud secrets create blog-db-password --data-file=-
```

Let the Cloud Run service account read them. By default this is the Compute Engine service account, `PROJECT_NUMBER-compute@developer.gserviceaccount.com`:

```bash
for s in blog-app-key blog-db-password; do
  gcloud secrets add-iam-policy-binding "$s" \
    --member="serviceAccount:PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
done
```

## 3. Reach Cloud SQL

Cloud Run can reach Cloud SQL by a Unix socket or by a private IP. Dox can use both. This guide uses the socket, because it needs no VPC:

1. Find the connection name of the instance: `gcloud sql instances describe INSTANCE --format='value(connectionName)'`. It looks like `PROJECT_ID:europe-west1:INSTANCE`.
2. Deploy with `--add-cloudsql-instances <connection name>` (step 4). Cloud Run then makes the socket in `/cloudsql/<connection name>`.
3. Give the service account the `roles/cloudsql.client` role.
4. Set `DB_HOST=/cloudsql/<connection name>`. A host that starts with `/` is a Unix socket. See [Unix socket](../database/index.md#unix-socket).

The same with one url: `DATABASE_URL=postgres://blog:<password>@/blog?host=/cloudsql/<connection name>`.

For **Cloud SQL for MySQL**, use the same `DB_HOST` with `DB_CONNECTION=mysql`. Leave out `DB_PORT`. Or use one url: `DATABASE_URL=mysql://blog:<password>@/blog?socket=/cloudsql/<connection name>`.

To use the **private IP** instead: give the instance a private IP on your VPC network, deploy with Direct VPC egress (`--network default --subnet default --vpc-egress private-ranges-only`), and use the private IP as `DB_HOST`.

Do not use SQLite on Cloud Run. Each instance has its own file system in memory, so the data is lost when the instance stops.

## 4. Deploy from source

The easiest way to deploy is from source. `--source .` uploads the folder, and Cloud Build builds the image with your `Dockerfile`. The image is saved in Artifact Registry, in the repository `cloud-run-source-deploy`.

```bash
gcloud run deploy blog \
  --source . \
  --region europe-west1 \
  --port 3000 \
  --allow-unauthenticated \
  --cpu 1 --memory 512Mi \
  --min-instances 1 \
  --add-cloudsql-instances PROJECT_ID:europe-west1:INSTANCE \
  --set-env-vars APP_ENV=production,APP_TOTAL_ISOLATE=1,DB_CONNECTION=postgres,DB_HOST=/cloudsql/PROJECT_ID:europe-west1:INSTANCE,DB_PORT=5432,DB_NAME=blog,DB_USERNAME=blog \
  --set-secrets APP_KEY=blog-app-key:1,DB_PASSWORD=blog-db-password:1
```

| Flag | Why |
| --- | --- |
| `--port 3000` | the port Cloud Run sends requests to. It also sets `PORT=3000`, and Dox listens on `PORT`. See [Choosing the port](#choosing-the-port) |
| `--min-instances 1` | keeps one instance warm, so the first request does not wait for a cold start. The default is `0`. An idle instance still costs money |
| `--add-cloudsql-instances` | makes the Cloud SQL Unix socket in `/cloudsql/...` |
| `--set-env-vars` | config that is not secret |
| `--set-secrets` | `ENV_NAME=SECRET:VERSION`. Cloud Run reads the secret when an instance starts. Pin a version number, not `latest` |
| `APP_TOTAL_ISOLATE=1` | one isolate per CPU. Set it to the `--cpu` value |

If you want to build the image yourself, push it to Artifact Registry and deploy it with `--image`:

```bash
docker build --platform linux/amd64 -t europe-west1-docker.pkg.dev/PROJECT_ID/blog/api:1 .
docker push europe-west1-docker.pkg.dev/PROJECT_ID/blog/api:1
gcloud run deploy blog --image europe-west1-docker.pkg.dev/PROJECT_ID/blog/api:1 --region europe-west1 --port 3000 ...
```

Use the same other flags as above.

## Check it

`gcloud run deploy` prints the service URL at the end.

```bash
curl https://blog-xxxxxxxx-ew.a.run.app/api/ping
```

```text
pong
```

```bash
gcloud run services logs read blog --region europe-west1 --limit 20
gcloud beta run services logs tail blog --region europe-west1   # live, needs the log-streaming component
```

The first log lines after the first start:

```text
Migrating: 2023_07_16_131937700_create_users_table
Migrated: 2023_07_16_131937700_create_users_table
Migrating: 2026_10_22_205345_create_posts_table
Migrated: 2026_10_22_205345_create_posts_table
{"timestamp":"...","status":"info","source":"server","message":"Server started at http://[::]:3000 with 1 isolate (native)","logger":{"name":"dox"}}
```

If the deploy fails with "the container did not listen on the port", the app listens on a different port than `--port`. Check `APP_PORT` and `--port`.

## HTTPS and the client IP

Cloud Run handles HTTPS and sends plain HTTP to the container. You want `req.ip()` and `req.scheme()` to show the real client, so set `trustedProxies`. Only the Cloud Run front end can reach the container port, so `['*']` is safe here:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  // ...
  trustedProxies: <String>['*'],
);
```

See [Deployment: HTTPS](../digging-deeper/deployment.md#https-put-a-proxy-in-front).

## Updating the app

To ship a new version, deploy again:

```bash
gcloud run deploy blog --source . --region europe-west1
```

- Cloud Run keeps the flags of the last revision. You only pass what changes.
- A new revision starts, runs new migrations, and takes the traffic when it listens on the port. The old one then stops.
- If many instances start at the same time, each one runs the migrations. So keep migrations safe to run twice, or run one instance during a deploy with a migration.
- A new secret version: create it with `gcloud secrets versions add`, then deploy with the new number in `--update-secrets APP_KEY=blog-app-key:2`.

## See also

- [Deployment](../digging-deeper/deployment.md) for the bundle and the `Dockerfile`
- [Environments](environments.md) for all env keys and `APP_KEY`
- [Docker](docker.md) for a health check binary and Docker Compose
- Cloud Run docs: [container contract](https://cloud.google.com/run/docs/container-contract), [deploy from source](https://cloud.google.com/run/docs/deploying-source-code), [secrets](https://cloud.google.com/run/docs/configuring/services/secrets), [minimum instances](https://cloud.google.com/run/docs/configuring/min-instances), [Cloud SQL](https://cloud.google.com/sql/docs/postgres/connect-run)
