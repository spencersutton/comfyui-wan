
echo "Building SageAttention in the background"
(
	pip install torch
	git clone https://github.com/thu-ml/SageAttention.git
	cd SageAttention || exit 1
	python3 setup.py install
	cd /
	pip install --no-cache-dir triton
) &>/var/log/sage_build.log & # run in background, log output

wget -O /workspace/ComfyUI/models/diffusion_models/wan2.2_i2v_high_noise_14B_fp16.safetensors https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp16.safetensors
wget -O /workspace/ComfyUI/models/diffusion_models/wan2.2_i2v_low_noise_14B_fp16.safetensors https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp16.safetensors

wget -O /workspace/ComfyUI/models/vae/wan_2.1_vae.safetensors https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors
wget -O /workspace/ComfyUI/models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors
