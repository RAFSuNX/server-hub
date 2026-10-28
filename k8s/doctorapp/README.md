# DoctorAPP (test deploy)

Self-contained **test** deployment of the DoctorAPP backend, which serves the whole
site (public pages, patient account/booking, and the admin panel) server-rendered.

**No secrets.** This is a test, so everything is in plain manifests:
- In-cluster Postgres (`01-postgres.yaml`) with test credentials in the manifest.
- Plain `ConfigMap` (`02-configmap.yaml`) for config. Third-party integrations
  (SMS, payment, WhatsApp, S3) are all mocked, so no keys are needed.

When this graduates to real staging/prod, swap the in-cluster DB for a managed one
and move `DATABASE_URL` + `SECRET_KEY` into a Doppler `ExternalSecret` like the
`expertsschool` app does.

## Image

Built by CI from the app repo: `.github/workflows/docker-build.yml` builds a
multi-arch image (`linux/amd64,linux/arm64`) and pushes to
`ghcr.io/ai-avatar-bangladesh-ltd/doctorapp` tagged `sha-<commit>` and `latest`.

- Push to `main` (or run the workflow manually) → image is built for **arm64**.
- Make the GHCR package **public** (Package settings → Change visibility) so the
  cluster can pull it without a pull secret. Otherwise add an `imagePullSecrets`
  (ghcr-secret) to `03-deployment.yaml` like the other apps.
- Bump `newTag` in `kustomization.yaml` to the `sha-<commit>` you want, or leave
  `latest` for the test.

### Building arm64 locally (optional)
Needs arm64 emulation. On NixOS add `boot.binfmt.emulatedSystems = [ "aarch64-linux" ];`
then:
```
docker buildx build --platform linux/arm64 \
  -t ghcr.io/ai-avatar-bangladesh-ltd/doctorapp:test --push ./backend
```

## Deploy

```
kubectl apply -k /home/rafsunx/repos/server-hub/k8s/doctorapp
```

The app Deployment has an init container that runs `alembic upgrade head` then seeds
demo data (both idempotent), so the DB is ready before the app serves traffic.

## Access

```
kubectl -n doctorapp port-forward svc/doctorapp 8000:80
```
Then open http://localhost:8000.

- **Patient login:** phone `01700000000`. SMS is mocked and `ENVIRONMENT=development`,
  so the OTP is shown on the verify page. The demo patient has confirmed + pending +
  completed bookings and 200 BDT credit.
- **Admin panel:** http://localhost:8000/admin — `admin@doctorapp.test` / `admin123`.

Note: `ENVIRONMENT=development` keeps the on-screen OTP (needed since SMS is mocked)
but also enables SQL echo logging (noisy pod logs). Flip to `production` to silence
logs, but then you lose the on-screen OTP.

## Health

- `/api/live` — liveness (no dependencies).
- `/api/health` — readiness (pings the DB).
