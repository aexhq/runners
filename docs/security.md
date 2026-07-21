# Security model

## Trust boundaries

- Deployment runs on GitHub-hosted runners and only from `main` or manual
  dispatch. Pull-request validation receives no deployment secrets.
- Each EC2 runner handles one job and is then terminated.
- Runner instances receive narrowly scoped runtime permissions from the
  upstream module. Do not attach deployment or production administrator
  policies to the runner role.
- No inbound network access is required. Outbound access remains broad because
  builds commonly need GitHub, action archives, package registries, container
  registries, and application endpoints.

## Required controls

1. Protect `main` and limit who can dispatch workflows or change Actions
   secrets.
2. In **Organization settings → Actions → Runner groups**, make the configured
   group available only to selected private repositories. Do not enable public
   repository access.
3. Install the GitHub App only on the repositories intended to use the fleet,
   or set `REPOSITORY_ALLOW_LIST` as an additional webhook filter.
4. Give jobs the smallest possible `GITHUB_TOKEN` permissions and expose only
   the secrets each job needs.
5. Pin third-party actions to immutable commits in sensitive workflows.
6. Encrypt application artifacts separately and assume arbitrary job code can
   become root through Docker access on its ephemeral VM.

Ephemeral VMs reduce persistence and cross-job contamination; they do not make
untrusted workflow code safe. A hostile job can exfiltrate every credential and
network resource made available to that job while it is running.
