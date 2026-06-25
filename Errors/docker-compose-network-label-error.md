mentee@mentees-ubuntu:~/Desktop/Git/portfolio$ docker compose up -d --build
WARN[0000] /home/mentee/Desktop/Git/portfolio/docker-compose.yml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion 
WARN[0000] Docker Compose is configured to build using Bake, but buildx isn't installed 
[+] Building 6.5s (45/45) FINISHED                                                                                                                                     docker:default
 => [experience_service internal] load build definition from Dockerfile                                                                                                          0.1s
 => => transferring dockerfile: 232B                                                                                                                                             0.0s
 => [contact_service internal] load build definition from Dockerfile                                                                                                             0.1s
 => => transferring dockerfile: 196B                                                                                                                                             0.0s
 => [projects_service internal] load build definition from Dockerfile                                                                                                            0.0s
 => => transferring dockerfile: 232B                                                                                                                                             0.0s
 => [blog_service internal] load build definition from Dockerfile                                                                                                                0.0s
 => => transferring dockerfile: 193B                                                                                                                                             0.0s
 => [portfolio_service internal] load metadata for docker.io/library/nginx:alpine                                                                                                0.0s
 => [blog_service internal] load .dockerignore                                                                                                                                   0.0s
 => => transferring context: 2B                                                                                                                                                  0.0s
 => [contact_service internal] load metadata for docker.io/library/node:18-alpine                                                                                                0.0s
 => [projects_service internal] load .dockerignore                                                                                                                               0.0s
 => => transferring context: 2B                                                                                                                                                  0.0s
 => [contact_service internal] load .dockerignore                                                                                                                                0.0s
 => => transferring context: 2B                                                                                                                                                  0.0s
 => [experience_service internal] load .dockerignore                                                                                                                             0.0s
 => => transferring context: 2B                                                                                                                                                  0.0s
 => [portfolio_service 1/4] FROM docker.io/library/nginx:alpine                                                                                                                  0.0s
 => [projects_service internal] load build context                                                                                                                               0.1s
 => => transferring context: 382B                                                                                                                                                0.0s
 => [blog_service internal] load build context                                                                                                                                   0.1s
 => => transferring context: 626B                                                                                                                                                0.1s
 => [experience_service internal] load build context                                                                                                                             0.0s
 => => transferring context: 384B                                                                                                                                                0.0s
 => [contact_service internal] load build context                                                                                                                                0.0s
 => => transferring context: 3.74kB                                                                                                                                              0.0s
 => [contact_service 1/5] FROM docker.io/library/node:18-alpine                                                                                                                  0.0s
 => CACHED [projects_service 2/4] COPY . /usr/share/nginx/html                                                                                                                   0.0s
 => CACHED [projects_service 3/4] COPY nginx-main.conf /etc/nginx/nginx.conf                                                                                                     0.0s
 => CACHED [projects_service 4/4] COPY nginx-server.conf /etc/nginx/conf.d/default.conf                                                                                          0.0s
 => [projects_service] exporting to image                                                                                                                                        0.0s
 => => exporting layers                                                                                                                                                          0.0s
 => => writing image sha256:4012237f92d7c0f7d45d4000abb2e7f5bf669f33094d1eab10dbb3536fb0adf2                                                                                     0.0s
 => => naming to docker.io/library/projects:latest                                                                                                                               0.0s
 => CACHED [blog_service 2/4] COPY . /usr/share/nginx/html                                                                                                                       0.0s
 => CACHED [blog_service 3/4] COPY nginx-main.conf /etc/nginx/nginx.conf                                                                                                         0.0s
 => CACHED [blog_service 4/4] COPY nginx-server.conf /etc/nginx/conf.d/default.conf                                                                                              0.0s
 => CACHED [experience_service 2/4] COPY . /usr/share/nginx/html                                                                                                                 0.0s
 => CACHED [experience_service 3/4] COPY nginx-main.conf /etc/nginx/nginx.conf                                                                                                   0.0s
 => CACHED [experience_service 4/4] COPY nginx-server.conf /etc/nginx/conf.d/default.conf                                                                                        0.0s
 => CACHED [contact_service 2/5] WORKDIR /app                                                                                                                                    0.0s
 => [contact_service 3/5] COPY package.json package-lock.json* ./                                                                                                                0.1s
 => [blog_service] exporting to image                                                                                                                                            0.0s
 => => exporting layers                                                                                                                                                          0.0s
 => => writing image sha256:b8f01829dda61a01b6cc25e89ecb0d50eb84955813f27e63f18f4b029c941adb                                                                                     0.0s
 => => naming to docker.io/library/blog:latest                                                                                                                                   0.0s
 => [experience_service] exporting to image                                                                                                                                      0.0s
 => => exporting layers                                                                                                                                                          0.0s
 => => writing image sha256:c81fb044f415174cd1651ad606ef2168d9c0e5f344c7404edc8878eeaa40e09e                                                                                     0.0s
 => => naming to docker.io/library/experience:latest                                                                                                                             0.0s
 => [contact_service 4/5] RUN npm install --production                                                                                                                           5.4s
 => [blog_service] resolving provenance for metadata file                                                                                                                        0.1s
 => [projects_service] resolving provenance for metadata file                                                                                                                    0.0s
 => [experience_service] resolving provenance for metadata file                                                                                                                  0.0s
 => [contact_service 5/5] COPY server.js .                                                                                                                                       0.0s
 => [contact_service] exporting to image                                                                                                                                         0.5s
 => => exporting layers                                                                                                                                                          0.5s
 => => writing image sha256:bc58a26d550e2c32de6b8b339b02d618ec0f2adb704fca49ba3fc1daed473b47                                                                                     0.0s
 => => naming to docker.io/library/contact-service:latest                                                                                                                        0.0s
 => [contact_service] resolving provenance for metadata file                                                                                                                     0.0s
 => [portfolio_service internal] load build definition from Dockerfile                                                                                                           0.0s
 => => transferring dockerfile: 193B                                                                                                                                             0.0s
 => [portfolio_service internal] load .dockerignore                                                                                                                              0.0s
 => => transferring context: 2B                                                                                                                                                  0.0s
 => [portfolio_service internal] load build context                                                                                                                              0.0s
 => => transferring context: 441B                                                                                                                                                0.0s
 => CACHED [portfolio_service 2/4] COPY . /usr/share/nginx/html                                                                                                                  0.0s
 => CACHED [portfolio_service 3/4] COPY nginx-main.conf /etc/nginx/nginx.conf                                                                                                    0.0s
 => CACHED [portfolio_service 4/4] COPY nginx-server.conf /etc/nginx/conf.d/default.conf                                                                                         0.0s
 => [portfolio_service] exporting to image                                                                                                                                       0.0s
 => => exporting layers                                                                                                                                                          0.0s
 => => writing image sha256:992ce4e74e4df9b59ea321beda5f8df3b03563c3ab4d7d25652ad12812839c61                                                                                     0.0s
 => => naming to docker.io/library/portfolio:latest                                                                                                                              0.0s
 => [portfolio_service] resolving provenance for metadata file                                                                                                                   0.0s
WARN[0007] a network with name gateway_default exists but was not created for project "portfolio".
Set `external: true` to use an existing network 
[+] Running 5/5
 ✔ blog_service        Built                                                                                                                                                     0.0s 
 ✔ contact_service     Built                                                                                                                                                     0.0s 
 ✔ experience_service  Built                                                                                                                                                     0.0s 
 ✔ portfolio_service   Built                                                                                                                                                     0.0s 
 ✔ projects_service    Built                                                                                                                                                     0.0s 
network gateway_default was found but has incorrect label com.docker.compose.network set to "default" (expected: "gateway_default")
mentee@mentees-ubuntu:~/Desktop/Git/portfolio$ docker ps
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
mentee@mentees-ubuntu:~/Desktop/Git/portfolio$ docker compose up
WARN[0000] /home/mentee/Desktop/Git/portfolio/docker-compose.yml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion 
WARN[0000] a network with name gateway_default exists but was not created for project "portfolio".
Set `external: true` to use an existing network 
network gateway_default was found but has incorrect label com.docker.compose.network set to "default" (expected: "gateway_default")
mentee@mentees-ubuntu:~/Desktop/Git/portfolio$ ^C
mentee@mentees-ubuntu:~/Desktop/Git/portfolio$ ^C
mentee@mentees-ubuntu:~/Desktop/Git/portfolio$ ^C
mentee@mentees-ubuntu:~/Desktop/Git/portfolio$ 

## Solution

### Root Cause

The Docker images built successfully. The actual failure happened after build, when Docker Compose tried to attach containers to the existing Docker network named `gateway_default`.

The existing network had this Compose network label:

```text
com.docker.compose.network=default
```

But the previous `docker-compose.yml` expected:

```text
com.docker.compose.network=gateway_default
```

That label mismatch caused Docker Compose to stop with:

```text
network gateway_default was found but has incorrect label com.docker.compose.network set to "default" (expected: "gateway_default")
```

The warning about `version` being obsolete was not the main failure, but it was cleaned up too.

The warning about `buildx` not being installed was also not fatal. Docker still built all images successfully.

### Repo Fix Applied

Updated both compose files:

- Removed obsolete top-level `version`.
- Changed the Compose network key from `gateway_default` to `default`.
- Kept the actual Docker network name as `gateway_default`.

The network section now uses this pattern:

```yaml
networks:
  default:
    name: gateway_default
    driver: bridge
```

This matches the existing network label shown in the error and avoids the startup failure.

### Commands To Run On Linux

From the project root:

```bash
docker compose down
docker compose up -d --build
docker compose ps
```

If Docker still reports a network label mismatch, remove the stale network and start again:

```bash
docker compose down
docker network rm gateway_default
docker compose up -d --build
docker compose ps
```

Only remove the network when no other containers are using it. You can check first with:

```bash
docker network inspect gateway_default
```

### Expected Result

After the fix, `docker compose ps` should show containers similar to:

```text
npm
db
portfolio_service
experience_service
projects_service
blog_service
contact_service
```

Then check the contact service:

```bash
docker compose exec contact_service wget -qO- http://localhost:3000/health
```

Expected response:

```json
{"status":"ok"}
```
