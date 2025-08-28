# Use multi-stage build with caching optimizations
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04 AS base

# Consolidated environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=8 \
    UV_CACHE_DIR=/opt/uv-cache \
    UV_LINK_MODE=copy

# Install system dependencies and uv in separate cached layers
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.12 python3.12-venv python3.12-dev python3-pip \
        curl ffmpeg ninja-build git aria2 git-lfs wget vim \
        libgl1 libglib2.0-0 build-essential gcc

# Install uv in separate layer for better caching
RUN --mount=type=cache,target=/root/.cache \
    curl -LsSf https://astral.sh/uv/install.sh | sh

# Setup Python environment
RUN ln -sf /usr/bin/python3.12 /usr/bin/python && \
    /root/.local/bin/uv venv /opt/venv --python python3.12

# Use the virtual environment and add uv to PATH
ENV PATH="/opt/venv/bin:/root/.local/bin:$PATH"

# Create requirements files for better layer caching
RUN echo "torch" > /tmp/pytorch-requirements.txt && \
    echo "torchvision" >> /tmp/pytorch-requirements.txt && \
    echo "torchaudio" >> /tmp/pytorch-requirements.txt

# Install PyTorch in separate layer (most stable, changes infrequently)
RUN --mount=type=cache,target=/opt/uv-cache \
    uv pip install --pre -r /tmp/pytorch-requirements.txt \
        --index-url https://download.pytorch.org/whl/nightly/cu128

# Create base dependencies requirements file
RUN echo "packaging" > /tmp/base-requirements.txt && \
    echo "setuptools" >> /tmp/base-requirements.txt && \
    echo "wheel" >> /tmp/base-requirements.txt && \
    echo "pip" >> /tmp/base-requirements.txt && \
    echo "pyyaml" >> /tmp/base-requirements.txt && \
    echo "gdown" >> /tmp/base-requirements.txt && \
    echo "triton" >> /tmp/base-requirements.txt && \
    echo "comfy-cli" >> /tmp/base-requirements.txt && \
    echo "opencv-python" >> /tmp/base-requirements.txt

# Install base dependencies in separate layer
RUN --mount=type=cache,target=/opt/uv-cache \
    uv pip install -r /tmp/base-requirements.txt

# ------------------------------------------------------------
# SageAttention build (cached layer - changes infrequently)  
# Supporting RTX 4090 (8.9) and RTX 5090 (9.0)
# ------------------------------------------------------------
ENV TORCH_CUDA_ARCH_LIST="8.9;9.0"

WORKDIR /tmp/sage-build-cache
RUN --mount=type=cache,target=/tmp/sage-build-cache \
    git clone https://github.com/thu-ml/SageAttention.git SageAttention || \
    (cd SageAttention && git pull)

WORKDIR /tmp
RUN cp -r /tmp/sage-build-cache/SageAttention .

WORKDIR /tmp/SageAttention
RUN sed -i "/compute_capabilities = set()/a compute_capabilities = {\"8.9\", \"9.0\"}" setup.py && \
    uv pip install . --no-build-isolation

WORKDIR /
RUN rm -rf /tmp/SageAttention

# ------------------------------------------------------------
# ComfyUI install (cached layer)
# ------------------------------------------------------------
RUN /usr/bin/yes | comfy --workspace /ComfyUI install --nvidia

# ------------------------------------------------------------
# Custom nodes repositories list (separate layer for better caching)
# ------------------------------------------------------------
RUN echo "ssitu/ComfyUI_UltimateSDUpscale.git" > /tmp/repos.txt && \
    echo "kijai/ComfyUI-KJNodes.git" >> /tmp/repos.txt && \
    echo "rgthree/rgthree-comfy.git" >> /tmp/repos.txt && \
    echo "JPS-GER/ComfyUI_JPS-Nodes.git" >> /tmp/repos.txt && \
    echo "Suzie1/ComfyUI_Comfyroll_CustomNodes.git" >> /tmp/repos.txt && \
    echo "Jordach/comfy-plasma.git" >> /tmp/repos.txt && \
    echo "Kosinkadink/ComfyUI-VideoHelperSuite.git" >> /tmp/repos.txt && \
    echo "bash-j/mikey_nodes.git" >> /tmp/repos.txt && \
    echo "ltdrdata/ComfyUI-Impact-Pack.git" >> /tmp/repos.txt && \
    echo "Fannovel16/comfyui_controlnet_aux.git" >> /tmp/repos.txt && \
    echo "yolain/ComfyUI-Easy-Use.git" >> /tmp/repos.txt && \
    echo "kijai/ComfyUI-Florence2.git" >> /tmp/repos.txt && \
    echo "ShmuelRonen/ComfyUI-LatentSyncWrapper.git" >> /tmp/repos.txt && \
    echo "WASasquatch/was-node-suite-comfyui.git" >> /tmp/repos.txt && \
    echo "theUpsider/ComfyUI-Logic.git" >> /tmp/repos.txt && \
    echo "cubiq/ComfyUI_essentials.git" >> /tmp/repos.txt && \
    echo "chrisgoringe/cg-image-picker.git" >> /tmp/repos.txt && \
    echo "chflame163/ComfyUI_LayerStyle.git" >> /tmp/repos.txt && \
    echo "chrisgoringe/cg-use-everywhere.git" >> /tmp/repos.txt && \
    echo "ClownsharkBatwing/RES4LYF" >> /tmp/repos.txt && \
    echo "welltop-cn/ComfyUI-TeaCache.git" >> /tmp/repos.txt && \
    echo "Fannovel16/ComfyUI-Frame-Interpolation.git" >> /tmp/repos.txt && \
    echo "Jonseed/ComfyUI-Detail-Daemon.git" >> /tmp/repos.txt && \
    echo "kijai/ComfyUI-WanVideoWrapper.git" >> /tmp/repos.txt && \
    echo "chflame163/ComfyUI_LayerStyle_Advance.git" >> /tmp/repos.txt && \
    echo "BadCafeCode/masquerade-nodes-comfyui.git" >> /tmp/repos.txt && \
    echo "1038lab/ComfyUI-RMBG.git" >> /tmp/repos.txt && \
    echo "M1kep/ComfyLiterals.git" >> /tmp/repos.txt

# ------------------------------------------------------------
# Custom nodes installation (optimized with better caching)
# ------------------------------------------------------------
WORKDIR /ComfyUI/custom_nodes

RUN --mount=type=cache,target=/opt/uv-cache \
    --mount=type=cache,target=/tmp/git-cache \
    # Clone repositories in parallel with persistent cache
    while IFS= read -r repo; do \
        repo_url="https://github.com/${repo}"; \
        repo_dir=$(basename "$repo" .git); \
        cache_dir="/tmp/git-cache/$repo_dir"; \
        \
        # Use cached clone if available, otherwise clone fresh
        if [ -d "$cache_dir/.git" ]; then \
            echo "Using cached repository for $repo_dir"; \
            cp -r "$cache_dir" "$repo_dir" && \
            cd "$repo_dir" && git pull --depth 1 && cd ..; \
        else \
            echo "Fresh clone for $repo_dir"; \
            mkdir -p "$(dirname "$cache_dir")"; \
            if [ "$repo" = "ssitu/ComfyUI_UltimateSDUpscale.git" ]; then \
                git clone --recursive --depth 1 "$repo_url" "$repo_dir" && \
                cp -r "$repo_dir" "$cache_dir"; \
            else \
                git clone --depth 1 "$repo_url" "$repo_dir" && \
                cp -r "$repo_dir" "$cache_dir"; \
            fi; \
        fi & \
    done < /tmp/repos.txt && \
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
        uv pip install -r /tmp/clean-requirements.txt; \
    fi && \
    \
    # Run install scripts
    while IFS= read -r repo; do \
        repo_dir=$(basename "$repo" .git); \
        if [ -f "$repo_dir/install.py" ]; then \
            python "$repo_dir/install.py"; \
        fi; \
    done < /tmp/repos.txt && \
    rm -f /tmp/all-requirements.txt /tmp/clean-requirements.txt /tmp/repos.txt

WORKDIR /

COPY src/start_script.sh /start_script.sh
RUN chmod +x /start_script.sh

CMD ["/start_script.sh"]