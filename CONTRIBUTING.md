# Contributing

Pull requests are welcome. Run the same checks as CI before opening one:

```bash
bash scripts/download-lambdas.sh
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform init -backend=false
terraform -chdir=terraform validate
actionlint
```

Never commit `.tfvars`, state, plans, private keys, AWS credentials, or Lambda
release archives.
