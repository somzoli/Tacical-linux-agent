# Tacical-linux-agent

# Usage
Download the script; fill variables and run. 

```bash
./agent-linux.sh
./agent-linux_update.sh
./agent_mac.sh
./agent_mac_update.sh
```
# Variables
**DEBUG=0** - Debug log level<br />
**INSECURE=0** - Insecure for testing only<br />
**NOMESH=0** - No mesh install (for update)<br />
**UPDATE=0** - Update off (install)<br />
**meshDL** - The url given by mesh for installing new agent. Go to mesh.example.com > Add agent > Installation Executable Linux / BSD / macOS > Select the good system type (Apple OSX universal/Linux) Copy ONLY the URL with the quote<br />
**apiURL** - Your api URL (https://api.example.com)<br />
**token** - Follow the manual Windows installation instructions (copy api token) <br />
**clientID** - Follow the manual Windows installation instructions (copy client id) <br />
**siteID** - Follow the manual Windows installation instructions (copy site id) <br />
**agentType** - workstation or server<br />

# Uninstall
./agent-linux.sh uninstall

# Thanks for some code blocks
https://github.com/netvolt/LinuxRMM-Script/
