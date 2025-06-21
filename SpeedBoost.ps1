# Speed-Boost Network Optimization Utility
# Advanced PowerShell script for optimizing network performance
# Author: ereezyy
# Version: 2.0.0

param(
    [switch]$Analyze,
    [switch]$Optimize,
    [switch]$Reset,
    [switch]$Monitor,
    [switch]$Report,
    [switch]$Silent,
    [string]$LogPath = "$env:TEMP\SpeedBoost.log",
    [string]$ConfigPath = "$PSScriptRoot\config.json"
)

# Requires Administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script requires Administrator privileges. Please run as Administrator."
    exit 1
}

# Configuration
$Config = @{
    DNSServers = @{
        Primary = @("1.1.1.1", "1.0.0.1")      # Cloudflare
        Secondary = @("8.8.8.8", "8.8.4.4")    # Google
        Backup = @("208.67.222.222", "208.67.220.220")  # OpenDNS
    }
    TCPSettings = @{
        TcpWindowSize = 65536
        TcpChimney = "enabled"
        TcpRSS = "enabled"
        TcpAutoTuning = "normal"
        TcpTimestamps = "disabled"
    }
    NetworkOptimizations = @{
        DisableNagle = $true
        EnableLargeSendOffload = $true
        EnableReceiveSideScaling = $true
        OptimizeForThroughput = $true
    }
    QoSSettings = @{
        EnableQoS = $true
        ReservedBandwidth = 0
        PriorityBoost = $true
    }
}

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    if (-not $Silent) {
        switch ($Level) {
            "ERROR" { Write-Host $logEntry -ForegroundColor Red }
            "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
            "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
            default { Write-Host $logEntry -ForegroundColor White }
        }
    }
    
    Add-Content -Path $LogPath -Value $logEntry
}

# Network analysis function
function Invoke-NetworkAnalysis {
    Write-Log "Starting comprehensive network analysis..." "INFO"
    
    $analysis = @{
        Timestamp = Get-Date
        NetworkAdapters = @()
        DNSConfiguration = @()
        TCPSettings = @{}
        PerformanceMetrics = @{}
        Recommendations = @()
    }
    
    # Analyze network adapters
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    foreach ($adapter in $adapters) {
        $adapterInfo = @{
            Name = $adapter.Name
            InterfaceDescription = $adapter.InterfaceDescription
            LinkSpeed = $adapter.LinkSpeed
            FullDuplex = $adapter.FullDuplex
            MediaType = $adapter.MediaType
            PhysicalMediaType = $adapter.PhysicalMediaType
        }
        
        # Get IP configuration
        $ipConfig = Get-NetIPConfiguration -InterfaceAlias $adapter.Name -ErrorAction SilentlyContinue
        if ($ipConfig) {
            $adapterInfo.IPAddress = $ipConfig.IPv4Address.IPAddress
            $adapterInfo.SubnetMask = $ipConfig.IPv4Address.PrefixLength
            $adapterInfo.Gateway = $ipConfig.IPv4DefaultGateway.NextHop
            $adapterInfo.DNSServers = $ipConfig.DNSServer.ServerAddresses
        }
        
        $analysis.NetworkAdapters += $adapterInfo
    }
    
    # Analyze DNS configuration
    $dnsServers = Get-DnsClientServerAddress | Where-Object { $_.AddressFamily -eq 2 }
    foreach ($dns in $dnsServers) {
        $analysis.DNSConfiguration += @{
            InterfaceAlias = $dns.InterfaceAlias
            ServerAddresses = $dns.ServerAddresses
        }
    }
    
    # Analyze TCP settings
    $tcpSettings = Get-NetTCPSetting -SettingName "*"
    $analysis.TCPSettings = @{
        AutoTuningLevel = (Get-NetTCPSetting -SettingName "Internet").AutoTuningLevelLocal
        ChimneyOffloadState = (Get-NetOffloadGlobalSetting).Chimney
        ReceiveSideScalingState = (Get-NetOffloadGlobalSetting).ReceiveSideScaling
        TaskOffloadState = (Get-NetOffloadGlobalSetting).TaskOffload
    }
    
    # Performance metrics
    $networkStats = Get-Counter "\Network Interface(*)\Bytes Total/sec" -SampleInterval 1 -MaxSamples 3
    $analysis.PerformanceMetrics.NetworkThroughput = ($networkStats.CounterSamples | Measure-Object CookedValue -Average).Average
    
    # Speed test simulation
    Write-Log "Performing network speed test..." "INFO"
    $speedTest = Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -InformationLevel Detailed
    $analysis.PerformanceMetrics.Latency = $speedTest.PingReplyDetails.RoundtripTime
    $analysis.PerformanceMetrics.PacketLoss = if ($speedTest.PingSucceeded) { 0 } else { 100 }
    
    # Generate recommendations
    if ($analysis.PerformanceMetrics.Latency -gt 100) {
        $analysis.Recommendations += "High latency detected. Consider optimizing DNS settings."
    }
    
    if ($analysis.TCPSettings.AutoTuningLevel -ne "Normal") {
        $analysis.Recommendations += "TCP Auto-Tuning is not optimized. Consider enabling normal auto-tuning."
    }
    
    Write-Log "Network analysis completed successfully." "SUCCESS"
    return $analysis
}

# DNS optimization function
function Optimize-DNSSettings {
    Write-Log "Optimizing DNS settings..." "INFO"
    
    try {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        
        foreach ($adapter in $adapters) {
            # Set primary DNS servers (Cloudflare)
            Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses $Config.DNSServers.Primary
            Write-Log "Set DNS servers for $($adapter.Name): $($Config.DNSServers.Primary -join ', ')" "SUCCESS"
        }
        
        # Flush DNS cache
        Clear-DnsClientCache
        Write-Log "DNS cache cleared successfully." "SUCCESS"
        
        # Register DNS
        Register-DnsClient
        Write-Log "DNS client registered successfully." "SUCCESS"
        
    } catch {
        Write-Log "Error optimizing DNS settings: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# TCP optimization function
function Optimize-TCPSettings {
    Write-Log "Optimizing TCP settings..." "INFO"
    
    try {
        # Enable TCP Auto-Tuning
        netsh int tcp set global autotuninglevel=normal
        Write-Log "TCP Auto-Tuning set to normal." "SUCCESS"
        
        # Enable TCP Chimney Offload
        netsh int tcp set global chimney=enabled
        Write-Log "TCP Chimney Offload enabled." "SUCCESS"
        
        # Enable Receive Side Scaling
        netsh int tcp set global rss=enabled
        Write-Log "Receive Side Scaling enabled." "SUCCESS"
        
        # Disable TCP timestamps for better performance
        netsh int tcp set global timestamps=disabled
        Write-Log "TCP timestamps disabled." "SUCCESS"
        
        # Optimize TCP window size
        netsh int tcp set global initialRto=2000
        Write-Log "TCP initial RTO optimized." "SUCCESS"
        
        # Enable ECN (Explicit Congestion Notification)
        netsh int tcp set global ecncapability=enabled
        Write-Log "ECN capability enabled." "SUCCESS"
        
    } catch {
        Write-Log "Error optimizing TCP settings: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Network adapter optimization function
function Optimize-NetworkAdapters {
    Write-Log "Optimizing network adapter settings..." "INFO"
    
    try {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        
        foreach ($adapter in $adapters) {
            # Enable Large Send Offload
            Set-NetAdapterLso -Name $adapter.Name -V1IPv4Enabled $true -IPv4Enabled $true -IPv6Enabled $true -ErrorAction SilentlyContinue
            
            # Enable Receive Side Scaling
            Set-NetAdapterRss -Name $adapter.Name -Enabled $true -ErrorAction SilentlyContinue
            
            # Optimize interrupt moderation
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Interrupt Moderation" -DisplayValue "Enabled" -ErrorAction SilentlyContinue
            
            # Set receive buffers
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Receive Buffers" -DisplayValue "2048" -ErrorAction SilentlyContinue
            
            # Set transmit buffers
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Transmit Buffers" -DisplayValue "2048" -ErrorAction SilentlyContinue
            
            Write-Log "Optimized adapter: $($adapter.Name)" "SUCCESS"
        }
        
    } catch {
        Write-Log "Error optimizing network adapters: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# QoS optimization function
function Optimize-QoSSettings {
    Write-Log "Optimizing Quality of Service settings..." "INFO"
    
    try {
        # Remove QoS packet scheduler reserved bandwidth
        $qosKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
        if (-not (Test-Path $qosKey)) {
            New-Item -Path $qosKey -Force | Out-Null
        }
        Set-ItemProperty -Path $qosKey -Name "NonBestEffortLimit" -Value 0 -Type DWord
        Write-Log "QoS reserved bandwidth set to 0%." "SUCCESS"
        
        # Enable QoS for applications
        $qosAppKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS"
        if (-not (Test-Path $qosAppKey)) {
            New-Item -Path $qosAppKey -Force | Out-Null
        }
        
    } catch {
        Write-Log "Error optimizing QoS settings: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Windows optimization function
function Optimize-WindowsSettings {
    Write-Log "Optimizing Windows network settings..." "INFO"
    
    try {
        # Disable Windows Update delivery optimization
        $doKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config"
        if (Test-Path $doKey) {
            Set-ItemProperty -Path $doKey -Name "DODownloadMode" -Value 0 -Type DWord
            Write-Log "Windows Update delivery optimization disabled." "SUCCESS"
        }
        
        # Optimize network throttling
        $throttleKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        Set-ItemProperty -Path $throttleKey -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord
        Write-Log "Network throttling optimized." "SUCCESS"
        
        # Disable Nagle's algorithm for better real-time performance
        $tcpKey = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
        $interfaces = Get-ChildItem $tcpKey
        foreach ($interface in $interfaces) {
            $interfacePath = "$tcpKey\$($interface.PSChildName)"
            Set-ItemProperty -Path $interfacePath -Name "TcpAckFrequency" -Value 1 -Type DWord -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $interfacePath -Name "TCPNoDelay" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        }
        Write-Log "Nagle's algorithm optimizations applied." "SUCCESS"
        
    } catch {
        Write-Log "Error optimizing Windows settings: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Performance monitoring function
function Start-PerformanceMonitoring {
    param([int]$Duration = 60)
    
    Write-Log "Starting performance monitoring for $Duration seconds..." "INFO"
    
    $counters = @(
        "\Network Interface(*)\Bytes Total/sec",
        "\Network Interface(*)\Packets/sec",
        "\Network Interface(*)\Current Bandwidth",
        "\TCPv4\Connections Established",
        "\TCPv4\Connection Failures"
    )
    
    $samples = Get-Counter -Counter $counters -SampleInterval 5 -MaxSamples ($Duration / 5)
    
    $report = @{
        Timestamp = Get-Date
        Duration = $Duration
        AverageNetworkUtilization = 0
        PeakNetworkUtilization = 0
        AveragePacketsPerSecond = 0
        TCPConnections = 0
        ConnectionFailures = 0
    }
    
    # Process samples
    $networkSamples = $samples | Where-Object { $_.CounterSamples.Path -like "*Bytes Total/sec*" }
    if ($networkSamples) {
        $report.AverageNetworkUtilization = ($networkSamples.CounterSamples | Measure-Object CookedValue -Average).Average
        $report.PeakNetworkUtilization = ($networkSamples.CounterSamples | Measure-Object CookedValue -Maximum).Maximum
    }
    
    Write-Log "Performance monitoring completed." "SUCCESS"
    return $report
}

# Reset network settings function
function Reset-NetworkSettings {
    Write-Log "Resetting network settings to defaults..." "WARNING"
    
    try {
        # Reset TCP settings
        netsh int tcp reset
        Write-Log "TCP settings reset to defaults." "SUCCESS"
        
        # Reset IP settings
        netsh int ip reset
        Write-Log "IP settings reset to defaults." "SUCCESS"
        
        # Reset Winsock
        netsh winsock reset
        Write-Log "Winsock reset to defaults." "SUCCESS"
        
        # Flush DNS
        ipconfig /flushdns
        Write-Log "DNS cache flushed." "SUCCESS"
        
        # Release and renew IP
        ipconfig /release
        ipconfig /renew
        Write-Log "IP configuration renewed." "SUCCESS"
        
        Write-Log "Network reset completed. Restart required for full effect." "WARNING"
        
    } catch {
        Write-Log "Error resetting network settings: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Generate HTML report function
function New-HTMLReport {
    param($AnalysisData, $OutputPath = "$env:TEMP\SpeedBoost_Report.html")
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Speed-Boost Network Analysis Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .header { background: linear-gradient(135deg, #0ea5e9, #1e40af); color: white; padding: 20px; border-radius: 10px; margin-bottom: 20px; }
        .section { background: white; padding: 20px; margin: 10px 0; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .metric { display: inline-block; margin: 10px; padding: 15px; background: #e0f2fe; border-radius: 5px; min-width: 150px; }
        .good { color: #10b981; font-weight: bold; }
        .warning { color: #f59e0b; font-weight: bold; }
        .error { color: #ef4444; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f8f9fa; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 Speed-Boost Network Analysis Report</h1>
        <p>Generated on: $($AnalysisData.Timestamp)</p>
    </div>
    
    <div class="section">
        <h2>📊 Performance Metrics</h2>
        <div class="metric">
            <strong>Latency:</strong><br>
            <span class="$(if($AnalysisData.PerformanceMetrics.Latency -lt 50){'good'}elseif($AnalysisData.PerformanceMetrics.Latency -lt 100){'warning'}else{'error'})">
                $($AnalysisData.PerformanceMetrics.Latency) ms
            </span>
        </div>
        <div class="metric">
            <strong>Packet Loss:</strong><br>
            <span class="$(if($AnalysisData.PerformanceMetrics.PacketLoss -eq 0){'good'}else{'error'})">
                $($AnalysisData.PerformanceMetrics.PacketLoss)%
            </span>
        </div>
    </div>
    
    <div class="section">
        <h2>🌐 Network Adapters</h2>
        <table>
            <tr><th>Name</th><th>Type</th><th>Speed</th><th>Status</th></tr>
"@
    
    foreach ($adapter in $AnalysisData.NetworkAdapters) {
        $html += "<tr><td>$($adapter.Name)</td><td>$($adapter.MediaType)</td><td>$($adapter.LinkSpeed)</td><td>Active</td></tr>"
    }
    
    $html += @"
        </table>
    </div>
    
    <div class="section">
        <h2>💡 Recommendations</h2>
        <ul>
"@
    
    foreach ($recommendation in $AnalysisData.Recommendations) {
        $html += "<li>$recommendation</li>"
    }
    
    if ($AnalysisData.Recommendations.Count -eq 0) {
        $html += "<li class='good'>Your network configuration appears to be optimized!</li>"
    }
    
    $html += @"
        </ul>
    </div>
    
    <div class="section">
        <h2>🔧 Applied Optimizations</h2>
        <p>This report was generated by Speed-Boost v2.0.0</p>
        <p><strong>Made by ereezyy</strong> - Advanced Network Optimization Utility</p>
    </div>
</body>
</html>
"@
    
    $html | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Log "HTML report generated: $OutputPath" "SUCCESS"
    return $OutputPath
}

# Main execution logic
function Main {
    Write-Log "Speed-Boost Network Optimization Utility v2.0.0" "INFO"
    Write-Log "Made by ereezyy - Advanced Network Performance Enhancement" "INFO"
    Write-Log "========================================================" "INFO"
    
    try {
        if ($Analyze) {
            $analysisResult = Invoke-NetworkAnalysis
            if ($Report) {
                $reportPath = New-HTMLReport -AnalysisData $analysisResult
                Write-Log "Analysis complete. Report saved to: $reportPath" "SUCCESS"
                if (-not $Silent) {
                    Start-Process $reportPath
                }
            }
            return $analysisResult
        }
        
        if ($Optimize) {
            Write-Log "Starting comprehensive network optimization..." "INFO"
            
            # Create system restore point
            Checkpoint-Computer -Description "Speed-Boost Network Optimization" -RestorePointType "MODIFY_SETTINGS"
            Write-Log "System restore point created." "SUCCESS"
            
            # Perform optimizations
            Optimize-DNSSettings
            Optimize-TCPSettings
            Optimize-NetworkAdapters
            Optimize-QoSSettings
            Optimize-WindowsSettings
            
            Write-Log "Network optimization completed successfully!" "SUCCESS"
            Write-Log "Restart your computer to apply all changes." "WARNING"
        }
        
        if ($Reset) {
            $confirmation = Read-Host "This will reset all network settings to defaults. Continue? (y/N)"
            if ($confirmation -eq 'y' -or $confirmation -eq 'Y') {
                Reset-NetworkSettings
            } else {
                Write-Log "Reset operation cancelled." "INFO"
            }
        }
        
        if ($Monitor) {
            $duration = Read-Host "Enter monitoring duration in seconds (default: 60)"
            if (-not $duration) { $duration = 60 }
            $monitorResult = Start-PerformanceMonitoring -Duration $duration
            Write-Log "Monitoring completed. Average utilization: $($monitorResult.AverageNetworkUtilization) bytes/sec" "INFO"
        }
        
        if (-not ($Analyze -or $Optimize -or $Reset -or $Monitor)) {
            Write-Host @"
Speed-Boost Network Optimization Utility v2.0.0
Made by ereezyy

Usage:
  .\SpeedBoost.ps1 -Analyze [-Report] [-Silent]     # Analyze current network configuration
  .\SpeedBoost.ps1 -Optimize [-Silent]              # Apply network optimizations
  .\SpeedBoost.ps1 -Reset [-Silent]                 # Reset network settings to defaults
  .\SpeedBoost.ps1 -Monitor [-Silent]               # Monitor network performance
  
Parameters:
  -Analyze    : Perform comprehensive network analysis
  -Optimize   : Apply network performance optimizations
  -Reset      : Reset all network settings to Windows defaults
  -Monitor    : Monitor network performance in real-time
  -Report     : Generate HTML report (use with -Analyze)
  -Silent     : Run without console output
  -LogPath    : Specify custom log file path
  -ConfigPath : Specify custom configuration file path

Examples:
  .\SpeedBoost.ps1 -Analyze -Report
  .\SpeedBoost.ps1 -Optimize
  .\SpeedBoost.ps1 -Monitor
"@
        }
        
    } catch {
        Write-Log "Critical error: $($_.Exception.Message)" "ERROR"
        Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
        exit 1
    }
}

# Execute main function
Main

