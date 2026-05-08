## 平台支持说明

**当前状态**：
- ✅ **AMD64 构建**：已跟进上游 PyQt6 构建链路
- ⚠️ **ARM64 构建**：独立实验中（不影响 AMD64 发布）

**说明**：当前 CI 默认仅发布 `linux/amd64`。ARM64 支持将单独推进，避免影响现有 AMD64 稳定构建。

**临时方案**：ARM64 用户可先使用 AMD64 镜像通过 Docker emulation 运行（性能约 70-80%）。

**详细信息**：参见 [ARM64 构建问题调查报告](arm64-building-issue.md)

### PyQt6 标签策略

- 新增/默认标签统一使用 `-pyqt6` 后缀。
- 建议发布链路按以下顺序：`build-mdcx-base` -> `build-mdcx` -> `gui-base` -> `mdcx-builtin-gui-base`/`mdcx-builtin-webtop-base`。
- 在 `workflow_dispatch` 中，相关 workflow 的默认输入已切换到 `v2-latest-pyqt6` 或 `v2-latest-dev-pyqt6`。

### 运行问题记录

- 现象：`ImportError: libEGL.so.1: cannot open shared object file`。
- 原因：运行镜像缺少 EGL 运行库。
- 修复：在 `gui-base` 运行层安装 `libegl1`（见 `gui-base/Dockerfile.gui-base`）。

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
  -t stainless403/build-mdcx-base:v2-amd64-pyqt6 \
  -f build-mdcx/Dockerfile.build-mdcx-base .
```

### build-mdcx镜像

```bash
export BASE_IMAGE_TAG=v2-amd64-pyqt6
docker buildx build \
  --platform linux/amd64 \
  --build-arg BASE_IMAGE_TAG \
  --load \
  -t stainless403/build-mdcx:v2-hazard804-amd64-pyqt6 \
  -f build-mdcx/Dockerfile.build-mdcx .
```

### gui-base镜像

```bash
docker buildx build \
  --platform linux/amd64 \
  --load \
  -t stainless403/gui-base:v2-amd64-pyqt6 \
  -f gui-base/Dockerfile.gui-base .
```

> 说明：`gui-base` 需要补齐 PyQt6 运行时依赖（如 `libxkbcommon0`、`libdbus-1-3`、`libglib2.0-0`、`libx11-6`、`libfreetype6` 等），以保证可运行 `build-mdcx` 产出的 PyQt6 二进制。

### mdcx-builtin-gui-base镜像

```bash
export MDCX_BIN_IMAGE_TAG=v2-hazard804-amd64-pyqt6
export BASE_IMAGE_TAG=v2-amd64-pyqt6
docker buildx build \
  --platform linux/amd64 \
  --build-arg MDCX_BIN_IMAGE_TAG \
  --build-arg BASE_IMAGE_TAG \
  --load \
  -t stainless403/mdcx-builtin-gui-base:$MDCX_BIN_IMAGE_TAG \
  -f gui-base/Dockerfile.mdcx-builtin-gui-base .
```

### webtop-base镜像

> TODO: 暂时未测试构建。

```bash
export MDCX_BIN_IMAGE_TAG=v2-hazard804-amd64-pyqt6
docker buildx build \
  --platform linux/amd64 \
  --build-arg MDCX_BIN_IMAGE_TAG \
  --load \
  -t stainless403/mdcx-builtin-webtop-base:$MDCX_BIN_IMAGE_TAG \
  -f webtop-base/Dockerfile.mdcx-builtin-webtop-base .
```
