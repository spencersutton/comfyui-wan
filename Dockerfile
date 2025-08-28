# Use multi-stage build with caching optimizations
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04 AS base

# Consolidated environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=8 \
    UV_CACHE_DIR=/opt/uv-cache \
    UV_LINK_MODE=copy

# Install system dependencies and uv in a single layer
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.12 python3.12-venv python3.12-dev python3-pip \
        curl ffmpeg ninja-build git aria2 git-lfs wget vim \
        libgl1 libglib2.0-0 build-essential gcc && \
    \
    # Install uv for faster Python package management
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    \
    # make Python3.12 the default python
    ln -sf /usr/bin/python3.12 /usr/bin/python && \
    \
    # Create virtual environment with uv
    $HOME/.local/bin/uv venv /opt/venv --python python3.12

# Use the virtual environment and add uv to PATH
ENV PATH="/opt/venv/bin:$PATH"

# Install PyTorch with uv (faster resolution and installation)
RUN --mount=type=cache,target=/opt/uv-cache \
    $HOME/.local/bin/uv pip install --pre torch torchvision torchaudio \
        --index-url https://download.pytorch.org/whl/nightly/cu128

# Install all Python dependencies in one layer for better caching
RUN --mount=type=cache,target=/opt/uv-cache \
    $HOME/.local/bin/uv pip install \
        packaging setuptools wheel pip \
        pyyaml gdown triton comfy-cli \
        opencv-python

# ------------------------------------------------------------
# SageAttention build (moved from startup script for faster container starts)
# ------------------------------------------------------------
RUN --mount=type=cache,target=/opt/uv-cache \
    git clone https://github.com/thu-ml/SageAttention.git /tmp/SageAttention && \
    cd /tmp/SageAttention && \
    # Set CUDA architectures for RTX 4090 (Ada Lovelace) and RTX 5090 (Blackwell)
    # 89 = RTX 4090, 90 = RTX 5090 (future-proofing)
    TORCH_CUDA_ARCH_LIST="8.9;9.0" CUDA_VISIBLE_DEVICES="" python setup.py install && \
    cd / && \
    $HOME/.local/bin/uv pip install --no-cache-dir triton && \
    rm -rf /tmp/SageAttention

# ------------------------------------------------------------
# ComfyUI install
# ------------------------------------------------------------
RUN --mount=type=cache,target=/opt/uv-cache \
    /usr/bin/yes | comfy --workspace /ComfyUI install --nvidia

# ------------------------------------------------------------
# Custom nodes installation (optimized)
# ------------------------------------------------------------
RUN --mount=type=cache,target=/opt/uv-cache \
    cd /ComfyUI/custom_nodes && \
    \
    # Define repositories
    repos="ssitu/ComfyUI_UltimateSDUpscale.git \
           kijai/ComfyUI-KJNodes.git \
           rgthree/rgthree-comfy.git \
           JPS-GER/ComfyUI_JPS-Nodes.git \
           Suzie1/ComfyUI_Comfyroll_CustomNodes.git \
           Jordach/comfy-plasma.git \
           Kosinkadink/ComfyUI-VideoHelperSuite.git \
           bash-j/mikey_nodes.git \
           ltdrdata/ComfyUI-Impact-Pack.git \
           Fannovel16/comfyui_controlnet_aux.git \
           yolain/ComfyUI-Easy-Use.git \
           kijai/ComfyUI-Florence2.git \
           ShmuelRonen/ComfyUI-LatentSyncWrapper.git \
           WASasquatch/was-node-suite-comfyui.git \
           theUpsider/ComfyUI-Logic.git \
           cubiq/ComfyUI_essentials.git \
           chrisgoringe/cg-image-picker.git \
           chflame163/ComfyUI_LayerStyle.git \
           chrisgoringe/cg-use-everywhere.git \
           ClownsharkBatwing/RES4LYF \
           welltop-cn/ComfyUI-TeaCache.git \
           Fannovel16/ComfyUI-Frame-Interpolation.git \
           Jonseed/ComfyUI-Detail-Daemon.git \
           kijai/ComfyUI-WanVideoWrapper.git \
           chflame163/ComfyUI_LayerStyle_Advance.git \
           BadCafeCode/masquerade-nodes-comfyui.git \
           1038lab/ComfyUI-RMBG.git \
           M1kep/ComfyLiterals.git"; \
    \
    # Clone repositories in parallel (background processes)
    for repo in $repos; do \
        repo_url="https://github.com/${repo}"; \
        repo_dir=$(basename "$repo" .git); \
        if [ "$repo" = "ssitu/ComfyUI_UltimateSDUpscale.git" ]; then \
            git clone --recursive --depth 1 "$repo_url" & \
        else \
            git clone --depth 1 "$repo_url" & \
        fi; \
    done && \
    \
    # Wait for all clones to complete
    wait && \
    \
    # Collect and install all requirements with better error handling
    find . -name "requirements.txt" -print0 | while IFS= read -r -d '' file; do \
        echo "# From: $file" >> /tmp/all-requirements.txt; \
        cat "$file" >> /tmp/all-requirements.txt; \
        echo "" >> /tmp/all-requirements.txt; \
    done && \
    # Clean up the requirements file and remove duplicates/invalid lines
    grep -v '^#' /tmp/all-requirements.txt | grep -v '^$' | sort -u | \
    sed 's/[[:space:]]*$//' | grep -E '^[a-zA-Z0-9_.-]+.*' > /tmp/clean-requirements.txt && \
    if [ -s /tmp/clean-requirements.txt ]; then \
        echo "Installing requirements from all custom nodes:" && \
        cat /tmp/clean-requirements.txt && \
        $HOME/.local/bin/uv pip install -r /tmp/clean-requirements.txt; \
    fi && \
    \
    # Run install scripts
    for repo in $repos; do \
        repo_dir=$(basename "$repo" .git); \
        if [ -f "$repo_dir/install.py" ]; then \
            python "$repo_dir/install.py"; \
        fi; \
    done && \
    rm -f /tmp/all-requirements.txt /tmp/clean-requirements.txt

COPY src/start_script.sh /start_script.sh
RUN chmod +x /start_script.sh

CMD ["/start_script.sh"]