FROM runpod/stable-diffusion:comfy-ui-6.0.0 AS base

RUN apt-get update -y

ADD https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp16.safetensors /ComfyUI/models/diffusion_models/wan2.2_i2v_high_noise_14B_fp16.safetensors
ADD https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp16.safetensors /ComfyUI/models/diffusion_models/wan2.2_i2v_low_noise_14B_fp16.safetensors

ADD https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors /ComfyUI/models/vae/wan_2.1_vae.safetensors