# Security policy

Do not report vulnerabilities in a public issue. Contact the repository owner
privately through the security advisory feature on GitHub.

This project provisions machines that execute repository-controlled code. Only
grant its runner group to repositories and workflows you trust. GitHub advises
against attaching self-hosted runners to public repositories because a forked
pull request can be used to run hostile code on the runner.

The deployment workflow intentionally runs only on GitHub-hosted runners. It is
not triggered by pull requests and never sends deployment secrets to the
self-hosted fleet.

Rotate the GitHub App private key, webhook secret, and AWS credentials if any of
them may have been exposed. Terraform state contains sensitive GitHub App data;
keep its S3 bucket private and tightly permissioned.
