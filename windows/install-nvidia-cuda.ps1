# Install NVIDIA CUDA Toolkit (Windows)
# Downloads and installs the NVIDIA CUDA toolkit
$cudaVersion = if ($env:CUDA_VERSION) { $env:CUDA_VERSION } else { "12.6" }
$cudaMajor = $cudaVersion.Split('.')[0]
$cudaMinor = $cudaVersion.Split('.')[1]
Write-Host "Downloading NVIDIA CUDA Toolkit $cudaVersion..."
$installerUrl = "https://developer.download.nvidia.com/compute/cuda/${cudaVersion}.0/local_installers/cuda_${cudaVersion}.0_560.76_windows.exe"
$installerPath = "$env:TEMP\cuda_installer.exe"
try {
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
} catch {
    Write-Host "Direct download failed, trying network installer..."
    $installerUrl = "https://developer.download.nvidia.com/compute/cuda/${cudaVersion}.0/network_installers/cuda_${cudaVersion}.0_windows_network.exe"
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
}
Write-Host "Installing NVIDIA CUDA Toolkit $cudaVersion..."
Start-Process -FilePath $installerPath -ArgumentList "-s" -Wait -NoNewWindow
Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
Write-Host "NVIDIA CUDA Toolkit $cudaVersion installed successfully."
Write-Host "A reboot may be required."
