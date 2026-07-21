# GitHub App setup

Create the App under the organization that will own the runners.

1. Open **Organization settings → Developer settings → GitHub Apps → New
   GitHub App**.
2. Choose any homepage URL. Enable the webhook and temporarily use
   `https://example.com/github-runner-webhook`; CI replaces it after Terraform
   creates the real endpoint.
3. Generate a long random webhook secret and keep the same value for the
   `GH_APP_WEBHOOK_SECRET` repository secret.
4. Under repository permissions select:
   - **Actions: Read-only**
   - **Checks: Read-only**
   - **Metadata: Read-only** (mandatory)
5. Under organization permissions select:
   - **Self-hosted runners: Read and write**
6. Subscribe only to the **Workflow job** event for runner scaling.
7. Create the App, note its numeric App ID, generate a private key, and install
   it on the target organization. Prefer **Only select repositories**.
8. Add the App ID and encoded key as repository secrets:

   ```bash
   # GNU/Linux
   base64 -w 0 app.private-key.pem

   # macOS
   base64 < app.private-key.pem | tr -d '\n'
   ```

The deployment workflow validates that the App has an installation whose
account login exactly matches `TARGET_GITHUB_ORG`. After apply, it authenticates
as the App and updates the webhook endpoint, content type, and secret.

The GitHub App installation determines which repository webhook events the App
can see. The GitHub runner group is a second access boundary. Restrict both to
the intended trusted repositories.
