# BuildrBank · the server, written down

Last week you stopped typing the deploy. A file in `.github/workflows/`
builds the image, pushes it, walks into the server and swaps the
container, every time you push. That still works, and it is still here.

But look at how that week started. Before the pipeline could do anything,
you opened the AWS console and did this by hand:

- launched an EC2 instance through a wizard with seven fields
- downloaded a `.pem` key and hoped you would not lose it
- edited a security group to open the ports
- SSH'd in and installed Docker, then logged out and back in
- SSH'd in again and pasted your API keys into `~/.env`
- copied the address and the key into three GitHub secrets

Six steps, none of them in the repository. If that server died tonight,
nobody could rebuild it from this code — including you. The pipeline you
were so pleased with would be deploying into thin air.

This repo adds two files that take those six steps away.

```
infra/main.tf        the server exists         ──▶  Terraform
infra/playbook.yml   the server is ready       ──▶  Ansible
.github/workflows/   every change ships itself ──▶  GitHub Actions
```

Nothing about the application changes. Same code, same Dockerfile, same
image, same pipeline. What changes is that the *server* is now code too.

```
terraform apply                  there is now a server
ansible-playbook playbook.yml    it now has Docker and your keys
git push                         your change is live
```

Three commands, one of which you were already running.

## One server, two slots

Unchanged from Week 06:

```
push to any branch ──▶ test                                     stops here
push to dev        ──▶ test ──▶ build & push ──▶ deploy to :8001
push to main       ──▶ test ──▶ build & push ──▶ deploy to :8000
```

`dev` lands in a sandbox container on port 8001. `main` replaces the real
one on 8000. Both read the same `~/.env`, so both talk to the same
Supabase — `dev` is a separate container, not a separate world.

`infra/main.tf` opens all three doors: 22 for Ansible and for the
pipeline's SSH step, 8000 for production, 8001 for the sandbox. Forget
8001 and your dev deploys go green and are unreachable.

## The part worth noticing

In `infra/main.tf`, Terraform generates its own SSH key and writes the
private half to `infra/buildrbank-key.pem`. That exact file becomes your
`EC2_SSH_KEY` secret:

```bash
gh secret set EC2_SSH_KEY < infra/buildrbank-key.pem
```

Nobody downloads a key from a console. Nobody emails one around. The
thing that creates the server hands GitHub the way in.

## Start here

**[STEPS.md](STEPS.md)** — the whole thing, step by step, from a fork to
a live page and back to an empty account.

## What this is not

This is a teaching repository, and two things in it are deliberately
simpler than production:

- **The security group is open to the world** (`0.0.0.0/0`). Real systems
  restrict SSH to known addresses and put the app behind a load balancer.
- **The Terraform state is a file on your laptop.** On a team it lives in
  S3 with a lock, so two people cannot apply at once. Lose
  `terraform.tfstate` and Terraform forgets your server exists.
