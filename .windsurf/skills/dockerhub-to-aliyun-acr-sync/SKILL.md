---
name: dockerhub-to-aliyun-acr-sync
description: Sync a Docker Hub image tag into Aliyun ACR Personal with the same repository basename and tag. Use when user gives an image like ubuntu/apache2:2.4-21.10_beta.
license: MIT
compatibility: Requires docker CLI and access to Aliyun ACR Personal.
---

Sync one Docker image tag from Docker Hub to Aliyun ACR Personal.

**Input**: A full Docker image reference with tag (for example `ubuntu/apache2:2.4-21.10_beta`).

**Required environment variables**

- `ALIYUN_ACR_REGISTRY`: ACR Personal registry + namespace prefix, for example `crpi-2zi07c2eorm55mbp.cn-shanghai.personal.cr.aliyuncs.com/hugopub`
- `ALIYUN_ACR_USERNAME`: Aliyun ACR username
- `ALIYUN_ACR_PASSWORD`: Aliyun ACR login password (must come from env var, never hardcode)

**Steps**

1. Validate input image has a tag (`name:tag`). If no tag is provided, stop and ask user to provide one.

2. Derive target repo name from the input image basename (the last path segment before `:`):
   - `ubuntu/apache2:2.4-21.10_beta` -> repo basename `apache2`
   - `library/nginx:1.27.3` -> repo basename `nginx`

3. Build target image:
   - `<ALIYUN_ACR_REGISTRY>/<repo_basename>:<same_tag>`

4. Set `SOURCE_IMAGE` to the exact user-provided input image (do not alter tag/repository path).

5. Run sync commands in order:

```bash
set -euo pipefail

: "${ALIYUN_ACR_REGISTRY:?Missing ALIYUN_ACR_REGISTRY}"
: "${ALIYUN_ACR_USERNAME:?Missing ALIYUN_ACR_USERNAME}"
: "${ALIYUN_ACR_PASSWORD:?Missing ALIYUN_ACR_PASSWORD}"

SOURCE_IMAGE="<input-image-with-tag-from-user>"
SOURCE_REPO="${SOURCE_IMAGE%%:*}"
SOURCE_TAG="${SOURCE_IMAGE##*:}"
TARGET_REPO_BASENAME="${SOURCE_REPO##*/}"
TARGET_IMAGE="${ALIYUN_ACR_REGISTRY}/${TARGET_REPO_BASENAME}:${SOURCE_TAG}"

printf '%s' "$ALIYUN_ACR_PASSWORD" | docker login "${ALIYUN_ACR_REGISTRY%%/*}" -u "$ALIYUN_ACR_USERNAME" --password-stdin
docker pull "$SOURCE_IMAGE"
docker tag "$SOURCE_IMAGE" "$TARGET_IMAGE"
docker push "$TARGET_IMAGE"

echo "Synced: $SOURCE_IMAGE -> $TARGET_IMAGE"
```

6. Return the final pushed image URL and remind user that destination repo must already exist in ACR if auto-create is disabled.

**Output format**

```text
Sync complete.
Source: <source-image>
Target: <acr-image>
```

**Guardrails**

- Never print or hardcode `ALIYUN_ACR_PASSWORD`.
- Always use `docker login --password-stdin`.
- Preserve the input tag exactly.
- Use the repository basename for target naming to match expected format like `.../hugopub/apache2:<tag>`.
