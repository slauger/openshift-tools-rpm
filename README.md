# openshift-tools-rpm

RPM repository for OpenShift and Kubernetes CLI tools, hosted on GitHub Pages.

## Usage

```bash
# dnf4 (RHEL 8/9/10, Fedora < 41)
sudo dnf config-manager --add-repo https://slauger.github.io/openshift-tools-rpm/openshift-tools.repo

# dnf5 (Fedora 41+)
sudo dnf config-manager addrepo --from-repofile=https://slauger.github.io/openshift-tools-rpm/openshift-tools.repo
```

Or manually create `/etc/yum.repos.d/openshift-tools.repo`:

```ini
[openshift-tools]
name=OpenShift Tools
baseurl=https://slauger.github.io/openshift-tools-rpm/
enabled=1
gpgcheck=0
```

Then install tools:

```bash
sudo dnf install helm kubectl argocd-cli k9s
```

## Available Packages

| RPM Package | Binary | Upstream |
|---|---|---|
| helm | `helm` | [helm/helm](https://github.com/helm/helm) |
| openshift-clients | `oc` | [openshift/oc](https://github.com/openshift/oc) |
| kubectl | `kubectl` | [kubernetes/kubernetes](https://github.com/kubernetes/kubernetes) |
| yq | `yq` | [mikefarah/yq](https://github.com/mikefarah/yq) |
| kubectx | `kubectx`, `kubens` | [ahmetb/kubectx](https://github.com/ahmetb/kubectx) |
| argocd-cli | `argocd` | [argoproj/argo-cd](https://github.com/argoproj/argo-cd) |
| tekton-cli | `tkn` | [tektoncd/cli](https://github.com/tektoncd/cli) |
| virtctl | `virtctl` | [kubevirt/kubevirt](https://github.com/kubevirt/kubevirt) |
| trivy | `trivy` | [aquasecurity/trivy](https://github.com/aquasecurity/trivy) |
| conftest | `conftest` | [open-policy-agent/conftest](https://github.com/open-policy-agent/conftest) |
| velero | `velero` | [vmware-tanzu/velero](https://github.com/vmware-tanzu/velero) |
| stern | `stern` | [stern/stern](https://github.com/stern/stern) |
| k9s | `k9s` | [derailed/k9s](https://github.com/derailed/k9s) |
| kustomize | `kustomize` | [kubernetes-sigs/kustomize](https://github.com/kubernetes-sigs/kustomize) |
| knative-client | `kn` | [knative/client](https://github.com/knative/client) |
| cosign | `cosign` | [sigstore/cosign](https://github.com/sigstore/cosign) |
| kubeseal | `kubeseal` | [bitnami-labs/sealed-secrets](https://github.com/bitnami-labs/sealed-secrets) |

## How it works

- Packages are built using [nfpm](https://github.com/goreleaser/nfpm) (no spec files needed)
- Versions are defined in `versions.yaml`
- [Renovate](https://github.com/renovatebot/renovate) creates PRs for new upstream releases after a minimum release age of 3 days and automerges minor/patch updates once the PR build is green
- OpenShift client (`oc`) is tracked daily by `.github/workflows/update-oc.yaml`: it picks the newest release of the latest `stable-4.x` channel from the [Cincinnati API](https://github.com/openshift/cincinnati-graph-data), verifies the tarball on mirror.openshift.com and commits the bump to `main`
- Every PR runs ShellCheck and a full download, RPM build and `createrepo_c` run
- On every push to `main`, GitHub Actions builds all RPMs and deploys the repository to GitHub Pages

## Local build

```bash
# Prerequisites: nfpm, yq (mikefarah), createrepo_c, curl
make download  # download all binaries
make build     # build RPMs
make repo      # create repository metadata

# Single package
make pkg PKG=helm
```

## Architecture

Only `x86_64` is supported at this time.
