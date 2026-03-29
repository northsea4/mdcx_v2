## 平台支持说明

**当前状态**：
- ✅ **AMD64 构建**：完全支持
- ❌ **ARM64 构建**：暂不支持

**原因**：PyQt5 在 Linux ARM64 平台缺少预编译 wheel 包，源码编译耗时过长（30-60分钟）不适合 Docker 构建流程。

**临时解决方案**：ARM64 用户可使用 AMD64 镜像通过 Docker emulation 运行（性能约 70-80%）。

**详细信息**：参见 [ARM64 构建问题调查报告](arm64-building-issue.md)

---

## 镜像构建流程

### 准备源码

```bash
bash prepare-src.sh --context build-mdcx --repo Hazard804/mdcx --tag latest
```

### build-mdcx-base镜像

```bash
docker buildx build \
  --platform linux/amd64 \
  --load \
  -t stainless403/build-mdcx-base:v2-amd64 \
  -f build-mdcx/Dockerfile.build-mdcx-base .
```

### build-mdcx镜像

```bash
export BASE_IMAGE_TAG=v2-amd64
docker buildx build \
  --platform linux/amd64 \
  --build-arg BASE_IMAGE_TAG \
  --load \
  -t stainless403/build-mdcx:v2-hazard804-amd64 \
  -f build-mdcx/Dockerfile.build-mdcx .
```

### gui-base镜像

```bash
docker buildx build \
  --platform linux/amd64 \
  --load \
  -t stainless403/gui-base:v2-amd64 \
  -f gui-base/Dockerfile.gui-base .
```

### mdcx-builtin-gui-base镜像

```bash
export MDCX_BIN_IMAGE_TAG=v2-hazard804-amd64
export BASE_IMAGE_TAG=v2-amd64
docker buildx build \
  --platform linux/amd64 \
  --build-arg MDCX_BIN_IMAGE_TAG \
  --build-arg BASE_IMAGE_TAG \
  --load \
  -t stainless403/mdcx-builtin-gui-base:$MDCX_BIN_IMAGE_TAG \
  -f gui-base/Dockerfile.mdcx-builtin-gui-base .
```

### webtop-base镜像

```bash
export MDCX_BIN_IMAGE_TAG=v2-hazard804-amd64
docker buildx build \
  --platform linux/amd64 \
  --build-arg MDCX_BIN_IMAGE_TAG \
  --load \
  -t stainless403/mdcx-builtin-webtop-base:$MDCX_BIN_IMAGE_TAG \
  -f webtop-base/Dockerfile.mdcx-builtin-webtop-base .
```
