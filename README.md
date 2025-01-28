[![Generate Manifest](https://github.com/renderthat/gitlab-runner-helper/actions/workflows/manifest.yml/badge.svg)](https://github.com/renderthat/gitlab-runner-helper/actions/workflows/manifest.yml)

# Gitlab Runner Helper Multi-Arch

This repo has a scheduled action running to mirror the official gitlab.com Runner Helper Image with specific architecture variants into ghcr.io registry and generating a generic multi-arch manifest over it. In a mixed k8s cluster, let's say with amd4+arm64 nodes, using this image allows the runner to run on all nodes without further explicitely specifying architectures.

In your Gitlab Runner config define the alternate helper image. For example, if you're using the official helm chart, you can set:

```
runners:
  config: |
    [[runners]]
      [runners.kubernetes]
        [...]
        node_selector_overwrite_allowed = "kubernetes.io/arch=.*"
        helper_image = "ghcr.io/renderthat/gitlab-runner-helper:alpine-v{{ $.Chart.AppVersion }}"
```
