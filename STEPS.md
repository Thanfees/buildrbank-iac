# The server, written down — the whole thing, step by step

**The repository:** <https://github.com/darshaka-weerasinghe/buildrbank-iac>

Eighteen steps. You do every one by hand: a browser, a terminal, and your
own typing. Nothing here needs an assistant, and nothing here is magic.

By the end you will have built a server, configured it, deployed to it, and
destroyed it — **without opening the AWS console once.** Then you will build
it all again in about four minutes, which is the part that matters.

> **Copy commands from [this file on GitHub](https://github.com/darshaka-weerasinghe/buildrbank-iac/blob/main/STEPS.md), not
> from the PDF handout.** The handout's font joins `--` and `//` into one
> character when you copy it, which breaks `--name` and `https://` in ways the
> error message disguises.

**What this costs.** A `t3.small` is about 2 US cents an hour. Follow step 17
and the whole session costs a few cents. Skip it and it is about **$15 a
month**. There is a checklist at the end.

-----

## Part A · On your laptop

### 1 · Fork it, and turn Actions on

Open the repository and press **Fork**, top right:

<https://github.com/darshaka-weerasinghe/buildrbank-iac>

Actions only runs in a repo you own, which is why you fork rather than clone
mine directly.

Then — and this one is easy to miss — open the **Actions** tab of *your fork*.
GitHub disables workflows on a new fork and shows a yellow banner:

> *Workflows aren't being run on this forked repository.*

Click **I understand my workflows, go ahead and enable them**. Until you do,
pushing does nothing at all: no run appears, no error appears, and you will
spend twenty minutes looking for a pipeline that was never allowed to start.

✓ The Actions tab shows **Test, build, deploy** in the left sidebar, with no
yellow banner.

### 2 · Clone your fork

```bash
git clone https://github.com/YOUR-NAME/buildrbank-iac.git
cd buildrbank-iac
```

Put it wherever you keep your work. This repo is self-contained — it does not
need to sit next to anything from a previous week.

✓ `ls` shows `app`, `infra` and `Dockerfile`.

### 3 · Bring your `.env` across

Everything in this repo is ready except one file: your keys. **That is the only
thing you need from a previous week**, because it was never in git.

```bash
cp /PATH/TO/YOUR/.env .env
```

Point that at whichever folder holds the `.env` you were using in Week 05 or 06.
Put quotes around the path if any folder name contains a space — without them the
shell splits at every space and you get `cp: .env: Not a directory`, which does
not mention spaces at all:

```bash
cp "/Users/you/My Documents/my old project/.env" .env
```

> **Cannot find it?** Open `.env.example` — it lists every value. Three of them
> are required and the app will not start without them:
> `OPENROUTER_API_KEY`, `SUPABASE_URL`, `SUPABASE_KEY`.

✓ `cat .env` shows your OpenRouter, Supabase and Langfuse keys.

**Now go and wake your Supabase project.** Open
[supabase.com/dashboard](https://supabase.com/dashboard) and look at the project
your `SUPABASE_URL` points at.

Free projects **pause after a week of no use**, and a paused project has to be
resumed by hand — there is a **Restore** or **Resume** button on its page. Click
it and wait for the dashboard to say the project is active. If the project is
gone entirely, make a new one, run `scripts/schema.sql` in the SQL editor, then
`python scripts/seed.py`, and put the new URL and key in `.env`.

> **Why this matters more than it looks.** A dead Supabase does not stop the
> app from *starting* — the container runs quite happily. What it stops is the
> app from *working*, and the first thing to notice is your deploy going red at
> **Is production actually up?**, with `/health` answering `"status":"degraded"`
> and a `supabase_detail` naming the real problem.
>
> That is deliberate. `/health` makes one real query to Supabase before it will
> say `ok`, so a paused project fails the deploy loudly instead of waiting to
> surprise you on your first message with
> `ConnectError: [Errno -2] Name or service not known` — an error that never
> mentions Supabase at all.

✓ The Supabase dashboard shows your project as **active**, not paused.

### 4 · Prove it still works before you change anything

**Arch / BlackArch Linux**

Use Python **3.12**, the same version as the Dockerfile and GitHub Actions.
Arch's system Python can be newer; use `uv` to install 3.12 separately and
create the project's virtual environment:

```bash
sudo pacman -Syu --needed uv
uv python install 3.12
uv venv --python 3.12 --seed .venv
source .venv/bin/activate
```

`--seed` puts pip in the virtual environment for the next commands. This
keeps the app's dependencies separate from Arch's system Python. See
[uv's Python installation guide](https://docs.astral.sh/uv/guides/install-python/).

**macOS / Ubuntu / WSL**

```bash
python3 -m venv .venv
source .venv/bin/activate
```

Windows: `.venv\Scripts\activate`, and use `python`, not `python3`.

**Then, on every platform**, from the repository root:

```bash
python --version   # 3.12.x on the Arch setup above
python -m pip install -r requirements.txt -r requirements-dev.txt
python scripts/check.py
```

✓ Six green ticks.

### 5 · Install the tools

You need **Terraform**, **Ansible** and the **AWS CLI**. All three are new this
week — in Week 06 you only ever used the AWS *console*, in a browser, so you do
not have the CLI either.

There is also a fourth, **the GitHub CLI (`gh`)**, which is **optional**. Every
step in this sheet can be done in the browser instead, and where that is true
it says so. It is worth installing anyway for one line in step 12 — it removes
the single most error-prone moment of Week 06.

Find your row and do only that one.

**Arch / BlackArch Linux**

```bash
sudo pacman -Syu --needed terraform ansible aws-cli-v2 openssh
sudo pacman -S --needed github-cli    # optional; provides gh
```

[Terraform](https://archlinux.org/packages/extra/x86_64/terraform/) and
[AWS CLI v2](https://archlinux.org/packages/extra/any/aws-cli-v2/) are in
Arch's official repositories; no AUR helper or Ubuntu package repositories
are needed. `--needed` skips packages already up to date, and `-Syu` updates
the system along with the installation.

Run Ansible directly on this Linux machine. The playbook installs Docker
on the **Ubuntu EC2 server**, so its `apt` task is correct even though your
laptop uses pacman. Continue with the version checks below, then step 6;
the remaining AWS and GitHub steps are the same on Arch.

**macOS**

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
brew install ansible
brew install awscli
brew install gh        # optional
```

**Ubuntu, or Windows with WSL**

If you are on Windows and have no WSL yet, open **PowerShell as
Administrator**, run `wsl --install`, restart, then open the **Ubuntu** app.
Everything below is typed in that Ubuntu window, not PowerShell.

```bash
sudo apt update
sudo apt install -y ansible
```

```bash
sudo apt install -y gnupg software-properties-common curl
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
```

And the AWS CLI, which is not in apt — you download it from AWS:

```bash
sudo apt install -y unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -q awscliv2.zip
sudo ./aws/install
```

Optionally the GitHub CLI, which has its own list like Terraform's:

```bash
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install -y gh
```

> **There is no Windows version of Ansible.** It has to run from Linux. WSL
> is that Linux. If WSL fought you in Week 01, use **AWS CloudShell** instead
> — the `>_` icon in the AWS console, then `sudo dnf install -y ansible` and
> the HashiCorp repo for Terraform. CloudShell already has the AWS CLI, and it
> is already signed in as you, so you can skip steps 6 and 7 entirely.

> **Git Bash is not a substitute for WSL.** Terraform, the AWS CLI, `git` and
> `gh` all work there, so you can do most of this week in it — but Ansible
> cannot. It needs Python modules that only exist on Linux, so `pip install
> ansible` appears to succeed and then `ansible --version` fails with
> `ModuleNotFoundError: No module named 'pwd'`. For step 10, use WSL or
> CloudShell.

✓ All three of these print a version number:

```bash
terraform -version
ansible --version
aws --version
```

**If you installed `gh`**, sign it in once:

```bash
gh auth login
```

Choose GitHub.com, HTTPS, and let it authenticate Git operations too.

> **It has to be the account that owns your fork.** If you have a work GitHub
> and a personal one, this is the single easiest thing to get wrong. `gh` is
> also what Git uses to push over HTTPS, so the wrong account here breaks both
> `gh secret set` *and* `git push`, with two different-looking errors:
> `HTTP 403: You must have repository read permissions` and
> `remote: Permission to ... denied`.
>
> ```bash
> gh auth status
> ```
>
> ✓ It names the same account that owns your fork.

---

## Part B · One server, from two files

This is the part that replaces Week 06's Part B, where you clicked through the
EC2 wizard and then SSH'd in twice.

Steps 6 and 7 are **one-off setup** — an access key, because the AWS API cannot
use the password you log into the console with. You do them once and never
again. After that, building and preparing a server is **two commands**, and it
is the same two commands every time.

### 6 · Make an AWS access key

Terraform talks to AWS over the API, as you. Up to now you have only signed in
to the **console**, with an email and a password. The API cannot use those — it
needs an **access key**, and you do not have one yet.

Make one now. It takes about a minute.

1. AWS Console → search for **IAM** → **Users** → **Create user**
2. Call it `buildrbank-iac`. Leave console access **off** — this user is only
   for the command line. **Next**.
3. **Attach policies directly** → tick **`AmazonEC2FullAccess`** → **Next** →
   **Create user**
4. Click the user you just made → the **Security credentials** tab →
   **Create access key**
5. Choose **Command Line Interface (CLI)**, tick the confirmation box →
   **Next** → **Create access key**

You are now shown two values: an **Access key ID** that starts `AKIA`, and a
**Secret access key**.

**Copy both before you leave that page.** The secret is shown once and never
again. If you lose it, delete the key and create another — that is normal, and
it costs nothing.

> **Treat the secret like a password.** It never goes near this folder —
> `aws configure` stores it under `~/.aws/`. Do not paste it into a file in the
> repo, and do not put it on a screen you are sharing.

> **Why `AmazonEC2FullAccess`?** Terraform has to create an instance, a key
> pair and a security group, and delete all three again. A narrower policy is
> better practice for a real system, but a missing permission here shows up as
> `UnauthorizedOperation` halfway through an apply — a miserable way to spend
> your first afternoon.

✓ You have two strings, one of them starting `AKIA`.

### 7 · Point the AWS CLI at your account

```bash
aws configure
```

It asks four things:

| It asks | You give it |
| --- | --- |
| AWS Access Key ID | the `AKIA…` value from step 6 |
| AWS Secret Access Key | the secret from step 6 |
| Default region name | `us-east-1` — the same value as `region` in `infra/main.tf` |
| Default output format | `json` |

✓ `aws sts get-caller-identity` prints your account number.

> **`Unable to locate credentials`?** Nothing saved. Run `aws configure` again
> and check you pasted both values.
>
> **`UnauthorizedOperation` later on?** The user from step 6 is missing
> `AmazonEC2FullAccess`. **IAM → Users → `buildrbank-iac` → Add permissions →
> Attach policies directly.** The long `Encoded authorization failure message`
> in that error is not something you need to read — the action name just before
> it is the whole answer.

### 8 · Build the server

```bash
cd infra
terraform init
terraform apply
```

Read what it is about to do, then type **`yes`**.

```
aws_key_pair.bank: Creation complete after 1s [id=buildrbank-key]
aws_security_group.bank: Creation complete after 6s [id=sg-...]
aws_instance.bank: Creation complete after 16s [id=i-...]

Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs:

dev_url  = "http://.....:8001"
ip       = "....."
prod_url = "http://.....:8000"
```

Five things: a key, the public half of that key in AWS, a security group, the
server, and `buildrbank-key.pem` written next to `main.tf`.

✓ The EC2 console shows an instance named `buildrbank` — and nobody filled in
a form to put it there.

> **`Failed to obtain provider schema … timeout while waiting for plugin to
> start`?** The AWS plugin is large and sometimes times out the first time it
> is started. Nothing is wrong and nothing was created. Run `terraform apply`
> again.

> **Change the region** by editing the one `default` line at the top of
> `main.tf`. There is no AMI id to look up: `data "aws_ami"` asks AWS at run
> time for the newest Ubuntu 24.04 in whatever region you chose.

### 9 · Look at what Terraform already wrote

You do not have to type the address anywhere. Terraform knew it the moment the
server existed, so it wrote Ansible's inventory for you:

```bash
cat inventory.ini
```

```ini
# Written by Terraform on every apply. Do not edit by hand.
[bank]
34.201.103.207

[bank:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=./buildrbank-key.pem
```

That is the handover between the two tools, and it is worth a second of your
attention: **Terraform's output is Ansible's input**, and no human retyped it.

The file is in `.gitignore`, for two reasons. It is rebuilt by every `apply`, so
committing it would mean a pointless commit every time you rebuild. And a
cloned repo carrying someone else's dead address is exactly how you end up
deploying to a server that no longer exists.

✓ `cat inventory.ini` shows the same number as `terraform output -raw ip`.

### 10 · Make the server ready

```bash
ansible-playbook playbook.yml
```

About a minute and a half. Read the task names as they go past — it is Week
06's steps 7, 8 and 9 in order, and you are not typing any of them.

```
TASK [Install Docker] **********************************
changed: [34.201.103.207]

TASK [Let the ubuntu user run docker without sudo] ******
changed: [34.201.103.207]

TASK [Put your .env on the server] **********************
changed: [34.201.103.207]

TASK [Report] *******************************************
ok: [34.201.103.207] => {
    "msg": "Ready. Docker version 29.1.3, build 29.1.3-0ubuntu3~24.04.2,
            and ~/.env is in place. The pipeline can deploy here now."
}

PLAY RECAP **********************************************
34.201.103.207  : ok=8  changed=3  unreachable=0  failed=0
```

Now run the **exact same command again**:

```bash
ansible-playbook playbook.yml
```

```
34.201.103.207  : ok=8  changed=0  unreachable=0  failed=0
```

**`changed=0`.** It checked all three things, found them already correct, and
did nothing. It did not install Docker twice. Run it a hundred times — same
answer. That property is called *idempotent*, and it is why this is safe to
run from a pipeline.

> **`UNREACHABLE … Connection timed out`?** The server is still booting. Wait
> thirty seconds and run it again.
>
> **`Could not find or access '../.env'`?** Step 3. The file has to be at the
> top of the repo, not in `infra/`.

✓ There is a server, it has Docker, and it has your keys. There is no
application on it yet — that is the pipeline's job, and it starts now.

---

## Part C · Tell GitHub who you are

### 11 · A Docker Hub token

Docker Hub → **Account settings** → **Personal access tokens** → **Generate
new token**. Permissions: **Read & Write**.

Copy it now. You cannot read it again.

> A read-only token still *logs in* successfully and only fails at the push,
> so the error arrives late and blames the wrong step.

### 12 · Three secrets — two of them written by Terraform

If you have the GitHub CLI, this is three lines from the repo root:

```bash
cd ..
gh secret set DOCKERHUB_TOKEN
gh secret set EC2_HOST    --body "$(cd infra && terraform output -raw ip)"
gh secret set EC2_SSH_KEY < infra/buildrbank-key.pem
```

**Look at the last two.** Terraform made that key ninety seconds ago, and it
is now the credential your pipeline logs in with. Nobody downloaded a `.pem`
from a console. Nobody pasted one into a browser.

That matters more than it looks. In Week 06, pasting the key by hand had
three classic ways to fail — a stray `%`, a missing final newline, and
stopping one line short of `-----END`. All three produced errors that named
something else. **Reading the file straight into the secret removes all
three.**

If you would rather click: your fork → **Settings** → **Secrets and
variables** → **Actions** → **New repository secret**, three times:

| Name | Value |
|---|---|
| `DOCKERHUB_TOKEN` | the token from step 11 |
| `EC2_HOST` | the number from `terraform output -raw ip` — no `http://`, no `:8000` |
| `EC2_SSH_KEY` | the whole of `infra/buildrbank-key.pem`, `-----BEGIN` and `-----END` included, and press Enter once after pasting |

### 13 · One variable

Same page, the **Variables** tab next door → **New repository variable**:

| Name | Value |
|---|---|
| `DOCKERHUB_USER` | your Docker Hub username |

A username is not a secret — it is printed on every image you have ever
pushed. A token is. GitHub built the distinction into the furniture.

> Until `DOCKERHUB_USER` is set, build and deploy say **skipped** rather than
> failing. A freshly forked repo shows a green tick and greyed-out boxes, not
> a red cross.

---

## Part D · The pipeline

### 14 · Push, and watch it run

The pipeline is already complete in this repo — you wrote it last week, so
there is nothing to fill in. Give it something to do:

```bash
git commit --allow-empty -m "first deploy to the new server"
git push
```

Open the **Actions** tab, or:

```bash
gh run watch
```

Three jobs in order: **Tests**, **Build and push**, **Deploy to production**
— with **Deploy to dev** greyed out, because you pushed to `main`.

The deploy job walks into the server Terraform built, using the key Terraform
generated, pulls the image it just pushed, and starts the container. Its last
step curls `/health` and refuses to go green until the app answers.

✓ `http://YOUR-IP:8000` shows the **BuildrBank Support Console**.

That page is being served by a container, on a server, that you have never
logged into.

> **No run at all?** Actions are not enabled on your fork — step 1.
>
> **Run green, but Build and push says `skipped` in 0s?** `DOCKERHUB_USER` is
> not set — step 13. It is a *variable*, not a secret, on the tab next door. A
> green run is not the same as a deployed run.
>
> **First run red?** Open it and read the log. Two likely causes: `invalid
> format` at the SSH step means `EC2_SSH_KEY` is wrong — set it from the file
> as in step 12. `pull access denied` means `DOCKERHUB_USER` does not match
> your account.

### When the page loads but the agent will not answer

Two shapes, same cause.

**The deploy job goes red** at *Is production actually up?*. Curl `/health`
yourself and read it:

```bash
curl -s http://YOUR-IP:8000/health
```

```json
{"status":"degraded","supabase_reachable":false,
 "supabase_detail":"ConnectError: [Errno -2] Name or service not known", ...}
```

**Or the page loads and a message fails** with that same `ConnectError` — which
happens if the database died *after* a deploy that was green at the time.

Either way the app itself is fine. Something in your `.env` points at a
hostname that does not exist — nine times out of ten a Supabase project that is
paused or deleted. Wake it as in step 3, then put the corrected file on the
server:

```bash
cd infra
ansible-playbook playbook.yml
```

That copies the new `.env` across and should say `changed=1`. Then **deploy
again** — push an empty commit, or re-run the last job:

```bash
cd ..
git commit --allow-empty -m "pick up the new .env" && git push
```

> **Do not reach for `docker restart`.** `--env-file` is read once, when the
> container is *created*, and the values are baked into it. Restarting reuses
> them, so an edited `.env` changes nothing and you will think the fix failed.
> The container has to be **recreated** — which is exactly what the deploy job
> does: `docker rm -f bank` and then `docker run … --env-file ~/.env`. That is
> why the fix is "push again", not "restart it".

---

## Part E · Make it yours

### 15 · Change something, on dev

```bash
git switch -c dev
```

Open `app/index.html` and change the heading text. Then:

```bash
git add app/index.html
git commit -m "change the heading"
git push -u origin dev
```

This time **Deploy to dev** runs and **Deploy to production** is greyed out.

✓ `http://YOUR-IP:8001` shows your change. `http://YOUR-IP:8000` still shows
the old one. Two containers, one server, same `~/.env`.

### 16 · Ship it

```bash
git switch main
git merge dev
git push
```

✓ `http://YOUR-IP:8000` now shows your change too.

---

## Part F · Put it away

### 17 · Destroy it — this is not optional

```bash
cd infra
terraform destroy
```

Type **`yes`**.

```
aws_instance.bank: Destruction complete after 22s
aws_key_pair.bank: Destruction complete after 1s
aws_security_group.bank: Destruction complete after 2s

Destroy complete! Resources: 5 destroyed.
```

Server gone, key gone, firewall rule gone, local `.pem` gone.

**Checklist — do not close your laptop until all four are true:**

- [ ] `terraform destroy` said **`Destroy complete!`**
- [ ] The EC2 console shows the instance as **terminated**
- [ ] No *other* instances are running that you forgot about
- [ ] `git status` does not list `.env` or any `.pem`

```bash
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].InstanceId' --output text
```

Empty output means nothing is running.

### 18 · Now build it again

```bash
terraform apply
ansible-playbook playbook.yml
cd ..
gh secret set EC2_HOST    --body "$(cd infra && terraform output -raw ip)"
gh secret set EC2_SSH_KEY < infra/buildrbank-key.pem
git commit --allow-empty -m "rebuild" && git push
```

No `gh`? Only the two secret lines need it. Run
`cd infra && terraform output -raw ip` for the address, open
`infra/buildrbank-key.pem` for the key, and update both under
**Settings → Secrets and variables → Actions**. Then push.

> **Both secrets go stale, not just the address.** Terraform rewrites
> `inventory.ini` for you, but GitHub only knows what you last told it — and a
> rebuild generates a **brand new SSH key**, because `aws_key_pair` was
> destroyed along with everything else. The old `EC2_SSH_KEY` is now a key AWS
> has never heard of.
>
> Forget `EC2_HOST` and the pipeline deploys to a server that is no longer
> there. Forget `EC2_SSH_KEY` and the deploy job stops at the SSH step with
> `Permission denied (publickey)`. Re-set both, every rebuild.

About four minutes, and the app is live again at a new address.

In Week 06, losing that server would have cost you an afternoon and a real
chance of misremembering a step. Now it is routine.

**That change — not the tools — is what this week was about.** Nothing about
how your server is built lives only in your head any more. It is in
`infra/main.tf`, `infra/playbook.yml` and `.github/workflows/pipeline.yml`,
in the repository, where the next person can read it.

---

## What we left out

So you know these exist, and that not seeing them was a choice:

- **Remote state** — `terraform.tfstate` is a file on your laptop. On a team
  it lives in S3 with a lock, so two people cannot apply at once.
- **Variables files** — we used two variables. Real projects parameterise far
  more, in `terraform.tfvars`.
- **Modules and roles** — reusable bundles, for Terraform and Ansible.
- **Ansible Vault** — keeping secrets in the repo, encrypted, instead of
  copying a `.env` across.
- **A narrower security group** — ours is open to the world so that it works
  from any café wifi. Real systems restrict SSH to known addresses.

None of it changes what you did today. `plan`, `apply`, `changed=0`,
`destroy`, and a push that deploys itself — that is the whole story.
