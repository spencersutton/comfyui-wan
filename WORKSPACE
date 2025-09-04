load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")
load("@io_bazel_rules_docker//container:container.bzl", "container_pull")

container_pull(
    name = "runpod_stable_diffusion_comfy_ui_6_0_0",
    registry = "docker.io",
    repository = "runpod/stable-diffusion",
    tag = "comfy-ui-6.0.0",
)

http_file(
    name = "wan2_2_i2v_high_noise_14B_fp16",
    urls = ["https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp16.safetensors"],
    downloaded_file_path = "wan2.2_i2v_high_noise_14B_fp16.safetensors",
)

http_file(
    name = "wan2_2_i2v_low_noise_14B_fp16",
    urls = ["https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp16.safetensors"],
    downloaded_file_path = "wan2.2_i2v_low_noise_14B_fp16.safetensors",
)

http_file(
    name = "wan_2_1_vae",
    urls = ["https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"],
    downloaded_file_path = "wan_2.1_vae.safetensors",
)
